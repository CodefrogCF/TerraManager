#!/usr/bin/env node
'use strict';
// Repeat the shortlisted overview workloads using browser_benchmark.cjs.
// --plan prints the schedule without reading credentials or starting browsers.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawn} = require('node:child_process');

function makePlan({clients = 5, seconds = 120, repetitions = 3} = {}) {
  if (!Number.isInteger(clients) || clients < 1 || clients > 10 ||
      !Number.isInteger(seconds) || seconds < 40 || seconds > 600 ||
      !Number.isInteger(repetitions) || repetitions < 1 || repetitions > 10) {
    throw Error('Invalid comparison dimensions');
  }
  const trials = [];
  for (let repetition = 1; repetition <= repetitions; repetition++) {
    // Alternate workload and mode order. This is counterbalanced, not random.
    const order = repetition % 2 ?
      [['idle', 'polling'], ['idle', 'sse'], ['writes', 'sse'], ['writes', 'polling']] :
      [['writes', 'polling'], ['writes', 'sse'], ['idle', 'sse'], ['idle', 'polling']];
    for (const [phase, mode] of order) trials.push({number: trials.length + 1, repetition, phase, mode});
  }
  return {clients, seconds, repetitions, view: 'overview', pollMs: 15000,
    changeMs: 20000, measuredSeconds: trials.length * seconds, trials};
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index++) {
    if (argv[index] === '--plan') { args.plan = true; continue; }
    if (!['--credentials', '--output-dir', '--clients', '--seconds', '--repetitions', '--channel', '--head'].includes(argv[index]) ||
        !argv[index + 1] || argv[index + 1].startsWith('--')) throw Error('Expected known --name value options');
    args[argv[index].slice(2)] = argv[++index];
  }
  return args;
}

function validateResult(report, trial, plan) {
  const result = report.results?.[0];
  if (report.kind !== 'disposable-api-and-lab-dom-workload' || report.results.length !== 1 ||
      result.serverMetadata?.kind !== 'disposable-transport-lab' ||
      result.clients !== plan.clients || result.seconds !== plan.seconds || result.view !== 'overview' ||
      result.mode !== trial.mode || result.errors !== 0 || result.missingObservations !== 0 ||
      !Number.isInteger(result.writes) || result.writes < 0 ||
      !Array.isArray(result.clientsDetail) || result.clientsDetail.length !== plan.clients) {
    throw Error('Incomplete or unexpected benchmark result');
  }
  const expected = result.writes * plan.clients;
  const observed = result.clientsDetail.reduce((sum, client) => sum + client.observedChanges, 0);
  const expectedByClients = result.clientsDetail.reduce((sum, client) => sum + client.expectedChanges, 0);
  if ((trial.phase === 'idle' && result.writes !== 0) ||
      (trial.phase === 'writes' && result.writes < 1) || observed !== expected || expectedByClients !== expected) {
    throw Error('Unexpected change observation counts');
  }
  return result;
}

function classifyBenchmarkFailure(message) {
  const value = String(message);
  const streams = value.match(/lab_streams_not_idle(?: count=\d+)?/);
  if (streams) return streams[0];
  for (const label of ['lab_health_login_failed', 'lab_health_not_lab', 'lab_health_metrics_failed']) {
    if (value.includes(label)) return label;
  }
  if (value.includes('SSE connection failed')) return 'sse_start_failed';
  return null;
}

async function assertLabIdle(credentials, options = {}) {
  const requestApi = options.requestApi || require('playwright').request;
  const context = await requestApi.newContext({timeout: 5000});
  try {
    const login = await context.post(credentials.origin + '/api/v1/auth/login', {
      data: {username: credentials.username, password: credentials.password}, headers: {Origin: credentials.origin}});
    if (login.status() !== 200) throw Error('lab_health_login_failed');
    const state = await context.get(credentials.origin + '/evaluation/state');
    if (state.status() !== 200 || (await state.json()).kind !== 'disposable-transport-lab') throw Error('lab_health_not_lab');
    const deadline = Date.now() + (options.maxWaitMs ?? 5000);
    let streams;
    do {
      const metrics = await context.get(credentials.origin + '/evaluation/metrics');
      if (metrics.status() !== 200) throw Error('lab_health_metrics_failed');
      streams = (await metrics.json()).streams;
      if (!Number.isInteger(streams) || streams < 0) throw Error('lab_health_metrics_failed');
      if (streams === 0) return;
      if (Date.now() >= deadline) break;
      await new Promise(resolve => setTimeout(resolve, options.pollMs ?? 250));
    } while (Date.now() <= deadline);
    throw Error('lab_streams_not_idle count=' + streams);
  } catch (error) {
    // Preserve allowlisted categories, never arbitrary APIRequestContext logs.
    throw Error(classifyBenchmarkFailure(error.message) || 'lab_health_unavailable');
  } finally { await context.dispose(); }
}

async function main(argv) {
  const args = parseArgs(argv);
  const plan = makePlan({clients: Number(args.clients || 5), seconds: Number(args.seconds || 120),
    repetitions: Number(args.repetitions || 3)});
  if (args.plan) { console.log(JSON.stringify(plan, null, 2)); return; }
  if (!args.credentials || !args['output-dir']) throw Error('--credentials and --output-dir are required');
  const credentialsFile = path.resolve(args.credentials);
  const credentials = JSON.parse(fs.readFileSync(credentialsFile, 'utf8'));
  const origin = new URL(credentials.origin);
  if (origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash ||
      !(origin.protocol === 'https:' || (origin.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(origin.hostname)))) {
    throw Error('Invalid evaluation origin');
  }
  const directory = path.resolve(args['output-dir']);
  fs.mkdirSync(directory, {recursive: false}); // Never overwrite an earlier run.
  const manifest = {schema: 1, kind: 'repeated-overview-polling-sse-comparison',
    createdAt: new Date().toISOString(), status: 'running', plan, sourceHead: args.head || null,
    scriptsSha256: Object.fromEntries(['run_sse_comparison.cjs', 'browser_benchmark.cjs'].map(name =>
      [name, crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname, name))).digest('hex')])),
    completed: [], limits: [
      'Logical contexts on one controller; lab DOM is not Flutter frame/rebuild timing.',
      'Counterbalanced workload order, one warm lab, no randomization or database resets.',
      'Each child deletes its created Feedings; sessions and audit history remain.',
      'Independent Pi resource recording is required; align actual UTC trial windows.',
      'Transport prototypes do not establish production reconnect/fallback correctness.',
    ]};
  const save = () => fs.writeFileSync(path.join(directory, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  save();
  try {
    await assertLabIdle(credentials);
    for (const trial of plan.trials) {
      const filename = String(trial.number).padStart(2, '0') + '-r' + trial.repetition + '-' + trial.phase + '-' + trial.mode + '.json';
      console.log('START ' + trial.number + '/' + plan.trials.length + ' ' + trial.phase + ' ' + trial.mode + ' ' + new Date().toISOString());
      const started = Date.now();
      const progress = setInterval(() => console.log('RUNNING trial=' + trial.number + ' elapsed=' + Math.round((Date.now() - started) / 1000) + 's'), 45000);
      try {
        await new Promise((resolve, reject) => {
          const child = spawn(process.execPath, [path.join(__dirname, 'browser_benchmark.cjs'),
            '--credentials', credentialsFile, '--output', path.join(directory, filename),
            '--clients', String(plan.clients), '--seconds', String(plan.seconds), '--mode', trial.mode,
            '--view', 'overview', '--poll-ms', String(plan.pollMs),
            '--change-ms', String(trial.phase === 'writes' ? plan.changeMs : 0),
            '--channel', args.channel || 'chrome', '--head', args.head || 'unrecorded'],
          {env: process.env, stdio: ['ignore', 'ignore', 'pipe'], windowsHide: true});
          // Do not forward Playwright logs: request diagnostics can contain secrets.
          let httpStatus = null, failureKind = null;
          child.stderr.on('data', chunk => {
            const match = String(chunk).match(/\bHTTP (\d{3})\b/);
            if (match) httpStatus = match[1];
            failureKind = classifyBenchmarkFailure(chunk) || failureKind;
          });
          child.on('error', () => reject(Error('Could not start benchmark process')));
          child.on('close', code => code === 0 ? resolve() : reject(Error('Benchmark failed, exit=' + code + (httpStatus ? ', HTTP ' + httpStatus : '') + (failureKind ? ', ' + failureKind : ''))));
        });
        const report = JSON.parse(fs.readFileSync(path.join(directory, filename), 'utf8'));
        const result = validateResult(report, trial, plan);
        await assertLabIdle(credentials);
        manifest.completed.push({...trial, file: filename, browser: report.browserVersion, result});
        save();
        console.log('DONE trial=' + trial.number + ' requests=' + result.requests + ' writes=' + result.writes + ' p95ms=' + result.writeStartToLabDomP95Ms);
      } finally { clearInterval(progress); }
    }
    manifest.status = 'complete';
    manifest.finishedAt = new Date().toISOString();
    save();
  } catch (error) {
    manifest.status = 'failed';
    manifest.failedAfterCompletedTrials = manifest.completed.length;
    manifest.failureKind = classifyBenchmarkFailure(error.message) || 'comparison_failed';
    save();
    throw error;
  }
  console.log('REPORT_DIRECTORY ' + directory);
}

module.exports = {makePlan, parseArgs, validateResult, assertLabIdle, classifyBenchmarkFailure};
if (require.main === module) main(process.argv.slice(2)).catch(error => {
  console.error(String(error.message).split('\n')[0]); process.exitCode = 1;
});
