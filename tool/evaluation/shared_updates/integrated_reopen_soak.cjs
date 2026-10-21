#!/usr/bin/env node
'use strict';
// Explicit tab-reopen stress for server resource bounds, not outage recovery.
const fs = require('node:fs');
const crypto = require('node:crypto');
const {assertFixture, renamePayload} = require('./integrated_benchmark.cjs');
const pause = ms => new Promise(resolve => setTimeout(resolve, Math.max(0, ms)));

function parseArgs(argv) {
  const args = {seconds: '1800', warmup: '120', channel: 'chrome'};
  const allowed = new Set(['credentials', 'output', ...Object.keys(args)]);
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i]?.replace(/^--/, '');
    if (!argv[i]?.startsWith('--') || !allowed.has(key) || !argv[i + 1] || argv[i + 1].startsWith('--')) throw Error('Invalid arguments');
    args[key] = argv[i + 1];
  }
  args.seconds = Number(args.seconds); args.warmup = Number(args.warmup);
  if (!args.credentials || !args.output || !['chrome', 'msedge'].includes(args.channel) ||
      !Number.isInteger(args.seconds) || args.seconds < 30 || args.seconds > 3600 ||
      !Number.isInteger(args.warmup) || args.warmup < 0 || args.warmup > 600) throw Error('Arguments outside supported bounds');
  return args;
}
function workloadThresholds(windowMs, reconnects) {
  return {minimumDurationMet: windowMs >= 1800000, minimumActualReopensMet: reconnects >= 100,
    reconnectWorkloadThresholdMet: windowMs >= 1800000 && reconnects >= 100};
}
async function until(check, label, timeout = 25000) {
  const deadline = Date.now() + timeout;
  do { if (await check()) return; await pause(100); } while (Date.now() < deadline);
  throw Error(label + ' timed out');
}
async function nameLocator(page, name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const item = page.getByRole('button', {name: new RegExp('^' + escaped + '(?:\\s|$)')}).first();
  await item.waitFor(); return item;
}
async function openOverview(subject, origin, name) {
  const previous = subject.confirmedConnections;
  await subject.page.goto(origin, {timeout: 45000});
  const placeholder = subject.page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({state: 'attached'}); await placeholder.dispatchEvent('click');
  await subject.page.getByRole('tab', {name: /Tiere|Animals/}).click();
  await nameLocator(subject.page, name);
  await until(() => subject.confirmedConnections > previous, 'Actual SSE HTTP 200 and changes frame');
}
async function watch(page, client) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Network.enable');
  const subject = {page, client, live: new Set(), confirmedConnections: 0,
    sseRequests: 0, dataGets: 0, changeGets: 0, pageErrors: 0};
  const streams = new Map();
  page.on('pageerror', () => subject.pageErrors++);
  cdp.on('Network.requestWillBeSent', e => {
    const route = new URL(e.request.url).pathname;
    if (route === '/api/v1/changes/events') {
      streams.set(e.requestId, {ok: false, frame: false}); subject.sseRequests++;
    } else if (e.request.method === 'GET' && route.startsWith('/api/v1/')) {
      if (route.startsWith('/api/v1/changes')) subject.changeGets++;
      else if (!route.startsWith('/api/v1/auth/')) subject.dataGets++;
    }
  });
  const confirm = id => {
    const stream = streams.get(id);
    if (stream?.ok && stream.frame && !stream.confirmed) {
      stream.confirmed = true; subject.confirmedConnections++;
    }
  };
  cdp.on('Network.responseReceived', e => {
    const stream = streams.get(e.requestId);
    if (stream && e.response.status === 200) {stream.ok = true; subject.live.add(e.requestId); confirm(e.requestId);}
  });
  cdp.on('Network.eventSourceMessageReceived', e => {
    const stream = streams.get(e.requestId);
    if (stream && e.eventName === 'changes') {stream.frame = true; confirm(e.requestId);}
  });
  const closed = e => {subject.live.delete(e.requestId); streams.delete(e.requestId);};
  cdp.on('Network.loadingFailed', closed); cdp.on('Network.loadingFinished', closed);
  subject.retireNavigationStreams = () => {
    // Document navigation can omit the old EventSource's CDP terminal event.
    // Call only after the server has actually released one of the five streams.
    const count = subject.live.size;
    subject.live.clear(); streams.clear();
    return count;
  };
  return subject;
}
async function clocks(context, origin) {
  const samples = [];
  for (let i = 0; i < 3; i++) {
    const start = Date.now(), response = await context.request.get(origin + '/evaluation/state');
    const state = await response.json(), finish = Date.now(), server = Date.parse(state.timeUtc);
    if (response.status() !== 200 || !Number.isFinite(server)) throw Error('Clock probe failed');
    samples.push({roundTripMs: finish - start, offsetLowerMs: server - finish, offsetUpperMs: server - start});
  }
  return {observedAt: new Date().toISOString(), samples};
}
async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (fs.existsSync(options.output)) throw Error('Output already exists');
  const credentials = JSON.parse(fs.readFileSync(options.credentials, 'utf8'));
  const url = new URL(credentials.origin), origin = url.origin;
  if (url.protocol !== 'https:' || url.pathname !== '/' || url.username || url.password || url.search || url.hash ||
      credentials.kind !== 'disposable-integrated-shared-care' || credentials.clients?.length !== 3 ||
      typeof credentials.fixtureId !== 'string' || credentials.fixtureId.length < 24) throw Error('Invalid fixture credentials');
  const {chromium} = require('playwright');
  const browser = await chromium.launch({channel: options.channel, headless: true});
  const contexts = [], subjects = [];
  const report = {schema: 1, kind: 'integrated-flutter-tab-reopen-soak', status: 'starting',
    createdAt: new Date().toISOString(), browser: browser.version(), channel: options.channel,
    method: 'explicit-about-blank-and-return-with-existing-session',
    plan: {clients: 5, warmupSeconds: options.warmup, fixedWorkloadSeconds: options.seconds,
      reopenSlotSeconds: 15, writeSlotSeconds: 60, finalReopenReserveSeconds: 30},
    toolSha256: {soak: crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),
      fixtureAndCommandHelpers: crypto.createHash('sha256').update(fs.readFileSync(require.resolve('./integrated_benchmark.cjs'))).digest('hex')},
    controller: {node: process.version, platform: process.platform, architecture: process.arch},
    reopens: [], writes: [], streamSamples: [],
    limits: [
      'Deliberate tab navigation stress measures server connection cleanup and memory under repeated app startup.',
      'These are real new SSE requests with HTTP 200 and an actual changes frame, not simulated events.',
      'Tab reopen stress is not evidence for the client outage/backoff/foreground policy or normal invalidation.',
      'Existing signed-in contexts retain cookies; only initial login/setup and warmup are excluded.',
      'Each reopen includes Flutter page startup and authoritative route reads; it is not a pure transport microbenchmark.',
      'UI writes are observed through actual semantics without reloading the other tabs; no physical paint timestamp is claimed.',
      'The workload threshold is separate from Pi RSS medians, growth, process identity, queue bounds and resource acceptance.',
      'Stream samples are point observations. The server writer queue bound requires its separate source/tests evidence.',
      'No credentials, cookies, response bodies, cursors, screenshots or original HAR are persisted.',
    ]};
  const save = () => fs.writeFileSync(options.output, JSON.stringify(report, null, 2) + '\n', {mode: 0o600});
  fs.writeFileSync(options.output, '', {flag: 'wx', mode: 0o600});
  let controller, csrf, name;
  async function metrics(label) {
    const response = await controller.request.get(origin + '/evaluation/metrics');
    if (response.status() !== 200) throw Error('Metrics unavailable');
    const body = await response.json();
    const sample = {at: new Date().toISOString(), label, streams: body.streams,
      maximumConnections: body.maximumConnections, maximumPerAccount: body.maximumPerAccount};
    report.streamSamples.push(sample);
    return sample;
  }
  async function write() {
    const current = await controller.request.get(origin + '/api/v1/animals/1');
    if (current.status() !== 200) throw Error('Animal read failed');
    const animal = (await current.json()).animal;
    const next = 'Evaluation Animal 1 [' + crypto.randomBytes(5).toString('hex') + ']';
    const started = Date.now();
    const observations = Promise.allSettled(subjects.map(async subject => {
      await nameLocator(subject.page, next); return {client: subject.client, semanticsMs: Date.now() - started};
    }));
    const response = await controller.request.put(origin + '/api/v1/animals/1', {
      data: renamePayload(animal, next), headers: {Origin: origin, 'X-CSRF-Token': csrf}});
    const outcomes = await observations;
    if (response.status() !== 200 || outcomes.some(row => row.status !== 'fulfilled')) throw Error('Soak write/UI outcome failed');
    name = next;
    report.writes.push({startedAt: new Date(started).toISOString(), completedAt: new Date().toISOString(),
      status: response.status(), observations: outcomes.map(row => row.value)});
  }
  try {
    controller = await browser.newContext(); contexts.push(controller);
    const login = await controller.request.post(origin + '/api/v1/auth/login', {
      data: {username: credentials.username, password: credentials.password}, headers: {Origin: origin}});
    if (login.status() !== 200) throw Error('Controller login failed');
    csrf = (await login.json()).csrfToken;
    const state = await controller.request.get(origin + '/evaluation/state');
    if (state.status() !== 200) throw Error('Fixture identity unavailable');
    assertFixture(credentials, await state.json());
    if ((await metrics('before-setup')).streams !== 0) throw Error('Other test streams are still active');
    name = (await (await controller.request.get(origin + '/api/v1/animals/1')).json()).animal.commonName;
    for (let i = 0; i < 5; i++) {
      const context = await browser.newContext({viewport: {width: 1100, height: 900}, locale: 'de-DE'});
      contexts.push(context);
      const response = await context.request.post(origin + '/api/v1/auth/login', {
        data: credentials.clients[i % 3], headers: {Origin: origin}});
      if (response.status() !== 200) throw Error('Client login failed');
      const page = await context.newPage(); page.setDefaultTimeout(25000);
      const subject = await watch(page, i + 1); subjects.push(subject);
      await openOverview(subject, origin, name);
    }
    report.warmupStartedAt = new Date().toISOString();
    await pause(options.warmup * 1000);
    report.clockBefore = await clocks(controller, origin);
    report.startedAt = new Date().toISOString(); report.status = 'running'; save();
    console.log('SOAK START ' + report.startedAt);
    const started = Date.now(), deadline = started + options.seconds * 1000;
    report.plannedFinishedAt = new Date(deadline).toISOString();
    let slot = 0, nextWrite = started + 60000;
    while (Date.now() < deadline - 30000) {
      await pause(started + slot * 15000 - Date.now());
      if (Date.now() >= deadline - 30000) break;
      if (Date.now() >= nextWrite) {
        await write(); nextWrite += 60000;
      }
      const subject = subjects[slot % subjects.length], before = subject.confirmedConnections;
      const event = {client: subject.client, slot, startedAt: new Date().toISOString()};
      report.reopens.push(event);
      if ((await metrics('before-tab-close')).streams !== 5) throw Error('Expected five live server streams before tab close');
      await subject.page.goto('about:blank');
      await until(async () => (await metrics('after-close')).streams === 4, 'Old server stream release', 5000);
      event.serverStreamsAfterClose = 4;
      event.browserIdsRetiredWithoutTerminalEvent = subject.retireNavigationStreams();
      await openOverview(subject, origin, name);
      event.completedAt = new Date().toISOString();
      event.newConfirmedConnections = subject.confirmedConnections - before;
      event.completedInsideWindow = Date.now() <= deadline;
      const active = await metrics('after-reopen');
      if (active.streams !== 5) throw Error('Expected five server streams after tab reopen');
      event.serverStreamsAfterReopen = active.streams;
      slot++;
      if (Date.now() > started + slot * 15000) {
        const nextSlot = Math.ceil((Date.now() - started) / 15000);
        report.skippedSlots = (report.skippedSlots || 0) + nextSlot - slot; slot = nextSlot;
      }
      save(); console.log('SOAK REOPEN ' + report.reopens.length);
    }
    await pause(deadline - Date.now());
    report.finishedAt = new Date().toISOString(); report.wallMs = Date.now() - started;
    report.fixedWindowOverrunMs = Math.max(0, Date.now() - deadline);
    report.actualReopensInsideWindow = report.reopens.filter(row => row.completedInsideWindow)
      .reduce((sum, row) => sum + row.newConfirmedConnections, 0);
    Object.assign(report, workloadThresholds(report.wallMs, report.actualReopensInsideWindow));
    report.clockAfter = await clocks(controller, origin);
    report.status = 'complete';
  } catch (error) {
    report.status = 'incomplete'; report.error = 'Capture failed; inspect local console'; throw error;
  } finally {
    report.drainStartedAt = new Date().toISOString();
    for (const context of contexts.slice(1).reverse()) await context.close();
    if (controller) {
      try {await until(async () => (await metrics('final-drain')).streams === 0, 'Final stream drain', 5000);}
      catch {report.drainFailed = true; report.status = 'incomplete';}
      report.clients = subjects.map(({page, live, retireNavigationStreams, ...metadata}) => ({...metadata,
        lastBrowserTrackedStreamCountAtContextClose: live.size}));
      report.drainFinishedAt = new Date().toISOString();
      await controller.close();
    }
    await browser.close(); save();
  }
  if (report.status !== 'complete') throw Error('Incomplete soak');
}
module.exports = {parseArgs, workloadThresholds};
if (require.main === module) main().catch(error => {console.error(String(error.message).split('\n')[0]); process.exitCode = 1;});
