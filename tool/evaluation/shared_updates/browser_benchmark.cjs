#!/usr/bin/env node
'use strict';
// Playwright is an optional evaluation dependency, not an app dependency.
// Install in a private tools directory and expose it through NODE_PATH.
const {chromium, firefox, webkit} = require('playwright');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

function options(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i += 2) {
    if (!argv[i].startsWith('--') || argv[i + 1] === undefined) throw Error('Expected --name value');
    result[argv[i].slice(2)] = argv[i + 1];
  }
  return result;
}
function percentile(values, p) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.ceil(sorted.length * p) - 1];
}
async function main() {
  const args = options(process.argv.slice(2));
  if (!args.credentials || !args.output) throw Error('--credentials FILE and --output FILE are required');
  if (fs.existsSync(args.output)) throw Error('Output already exists; choose a new report path');
  const credentials = JSON.parse(fs.readFileSync(args.credentials, 'utf8'));
  const url = new URL(credentials.origin);
  if (url.username || url.password || url.search || url.hash || url.pathname !== '/' ||
      !(url.protocol === 'https:' || (url.protocol === 'http:' &&
        ['localhost', '127.0.0.1'].includes(url.hostname)))) throw Error('Invalid lab origin');
  const clients = Number(args.clients || 3), seconds = Number(args.seconds || 120);
  const pollMs = Number(args['poll-ms'] || 15000), changeMs = Number(args['change-ms'] || 20000);
  if (!Number.isInteger(clients) || clients < 1 || clients > 10 ||
      !Number.isFinite(seconds) || !Number.isFinite(pollMs) || !Number.isFinite(changeMs) ||
      seconds < 5 || seconds > 3600 || pollMs < 250 ||
      (changeMs !== 0 && changeMs < 500))
    throw Error('Invalid benchmark dimensions');
  const modes = args.mode && args.mode !== 'all' ? [args.mode] :
    ['polling', 'version-polling', 'long-polling', 'sse', 'websocket'];
  const browserName = args.browser || 'chromium';
  const engine = {chromium, firefox, webkit}[browserName];
  if (!engine) throw Error('Unknown browser');
  const browser = await engine.launch({
    headless: true,
    ...(browserName === 'chromium' ? {channel: args.channel || 'chrome'} : {}),
  });
  const results = [];
  try {
    for (const mode of modes) {
      const contexts = [], pages = [], wire = [];
      let control, serverMetadata;
      const createdFeedings = [];
      try {
        for (let i = 0; i <= clients; i++) {
          const context = await browser.newContext();
          contexts.push(context);
          const login = await context.request.post(url.origin + '/api/v1/auth/login', {
            data: {username: credentials.username, password: credentials.password},
            headers: {Origin: url.origin},
          });
          if (login.status() !== 200) throw Error('Lab sign-in failed: HTTP ' + login.status());
          const session = await login.json();
          if (i === clients) {
            control = {context, csrf: session.csrfToken};
            const state = await context.request.get(url.origin + '/evaluation/state');
            const metadata = await state.json();
            if (metadata.kind !== 'disposable-transport-lab') throw Error('Refusing to write outside the disposable lab');
            serverMetadata = metadata;
            continue;
          }
          const page = await context.newPage();
          pages.push(page);
          const totals = {encodedResponseBodyBytes: 0, decodedResponseBodyBytes: 0,
            websocketReceivedPayloadBytes: 0};
          wire.push(totals);
          if (browserName === 'chromium') {
            const session = await context.newCDPSession(page);
            await session.send('Network.enable');
            session.on('Network.dataReceived', event => {
              totals.encodedResponseBodyBytes += event.encodedDataLength;
              totals.decodedResponseBodyBytes += event.dataLength;
            });
            session.on('Network.webSocketFrameReceived', event => {
              totals.websocketReceivedPayloadBytes += Buffer.byteLength(event.response.payloadData);
            });
          }
          await page.goto(url.origin);
          await page.evaluate(config => window.evaluation.start(config),
            {mode, view: args.view || 'overview', pollMs});
          for (const key of Object.keys(totals)) totals[key] = 0;
        }
        await Promise.all(pages.map(page => page.evaluate(() => window.evaluation.beginMeasurement())));
        for (const totals of wire) for (const key of Object.keys(totals)) totals[key] = 0;
        const started = Date.now();
        const changeUntil = started + seconds * 1000 - pollMs - 1500;
        let sequence = 0, nextChange = started + 2000;
        while (Date.now() < started + seconds * 1000) {
          if (changeMs > 0 && Date.now() >= nextChange && Date.now() < changeUntil) {
            // Drift's SQLite DateTime columns retain whole seconds.
            const timestamp = Math.floor((Date.now() - 1000) / 1000) * 1000;
            const writeStartedAt = Date.now();
            await Promise.all(pages.map(page => page.evaluate(
              ({timestamp, writeStartedAt}) => window.evaluation.expect(timestamp, writeStartedAt),
              {timestamp, writeStartedAt})));
            const response = await control.context.request.post(url.origin + '/api/v1/feedings', {
              data: {animalIds: [1], fedAt: new Date(timestamp).toISOString(),
                notes: 'Synthetic update evaluation ' + (++sequence)},
              headers: {Origin: url.origin, 'X-CSRF-Token': control.csrf,
                'Idempotency-Key': crypto.randomUUID()},
            });
            if (response.status() !== 201) throw Error('Evaluation write failed: HTTP ' + response.status());
            for (const feeding of (await response.json()).feedings) createdFeedings.push(feeding.id);
            nextChange += changeMs;
          }
          await new Promise(resolve => setTimeout(resolve, 50));
        }
        const data = await Promise.all(pages.map(page => page.evaluate(() => window.evaluation.stop())));
        const latency = data.flatMap(item => item.writeStartToLabDomMs);
        results.push({
          mode, view: args.view || 'overview', clients, seconds, pollMs, changeMs, serverMetadata,
          startedAt: new Date(started).toISOString(), finishedAt: new Date().toISOString(),
          measuredDurationMs: Date.now() - started, writes: sequence,
          requests: data.reduce((sum, item) => sum + item.requests, 0),
          completedResponseBodyBytes: data.reduce((sum, item) => sum + item.completedBodyBytes, 0),
          labDomUpdates: data.reduce((sum, item) => sum + item.domUpdates, 0),
          errors: data.reduce((sum, item) => sum + item.errors, 0),
          missingObservations: data.reduce((sum, item) => sum + item.missingMarkers.length, 0),
          writeStartToLabDomP50Ms: percentile(latency, 0.5),
          writeStartToLabDomP95Ms: percentile(latency, 0.95),
          wire: browserName === 'chromium' ? wire : null,
          clientsDetail: data,
        });
        console.log(mode + ': ' + results.at(-1).requests + ' requests, ' +
          results.at(-1).missingObservations + ' missing observations');
      } finally {
        let cleanupFailures = 0;
        if (control) for (const id of createdFeedings) {
          const cleanup = await control.context.request.delete(url.origin + '/api/v1/feedings/' + id, {
            headers: {Origin: url.origin, 'X-CSRF-Token': control.csrf},
          });
          if (cleanup.status() !== 200) cleanupFailures++;
        }
        for (const context of contexts.reverse()) await context.close();
        if (cleanupFailures) throw Error('Disposable fixture cleanup failed; restart the lab before comparing modes');
      }
    }
  } finally { await browser.close(); }
  const report = {
    schema: 1, generatedAt: new Date().toISOString(), baselineHead: args.head || null,
    browser: browserName, browserVersion: browser.version(),
    controllerPlatform: os.platform(), controllerArch: os.arch(),
    kind: 'disposable-api-and-lab-dom-workload', results,
    limits: [
      'Logical clients are isolated browser contexts on one controller, not separate physical devices.',
      'The lab DOM is not the Flutter UI. Rebuild counts are not Flutter frame measurements.',
      'Latency starts before the write request and includes acknowledgement/transport/refresh/DOM.',
      'Completed body bytes exclude pending streams; Chromium CDP counters also record streaming data.',
      'CDP body/payload counters exclude HTTP headers, TLS/TCP framing and outgoing bytes.',
      'Pi CPU/RAM and real Flutter HAR/frame measurements must be collected separately.',
      'No production reconnect/fallback/conflict protocol is implemented by these prototypes.',
    ],
  };
  fs.mkdirSync(path.dirname(path.resolve(args.output)), {recursive: true});
  fs.writeFileSync(args.output, JSON.stringify(report, null, 2) + '\n', {flag: 'wx'});
  if (results.some(item => item.errors || item.missingObservations)) process.exitCode = 1;
}
main().catch(error => { console.error('Evaluation failed: ' + error.message); process.exitCode = 1; });

