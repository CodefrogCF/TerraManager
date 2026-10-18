#!/usr/bin/env node
'use strict';
// Real Flutter acceptance capture. No production dependency; requires Playwright.
const fs = require('node:fs');
const crypto = require('node:crypto');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const routeOf = url => new URL(url).pathname.replace(/\/\d+(?=\/|$)/g, '/:id');
function percentile(values, p) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil(sorted.length * p) - 1)];
}
function summarize(values) { return {n: values.length, p50: percentile(values, .5), p95: percentile(values, .95)}; }
function renamePayload(record, name) {
  const keys = ['boxId', 'latinName', 'category', 'subcategory', 'sex', 'birthDate', 'birthDateAccuracy',
    'tempMin', 'tempMax', 'nighttimeTemperatureMin', 'nighttimeTemperatureMax', 'humidityMin', 'humidityMax',
    'originHabitat', 'restOrDormancyPeriods', 'notes', 'pictureMediaId', 'feedingReminderIntervalDays',
    'feedingReminderBaseline', 'feedingReminderWeekdays', 'feedingReminderMinuteOfDay', 'feedingReminderTimeZone',
    'showWeightOnDetail', 'showSheddingOnDetail'];
  return {...Object.fromEntries(keys.filter(key => Object.hasOwn(record, key)).map(key => [key, record[key]])),
    commonName: name, expectedRevision: record.revision};
}
function parseArgs(argv) {
  const args = {clients: '1', repetitions: '1', seconds: '120', writes: '3', channel: 'chrome', mode: 'sse', contexts: null};
  const allowed = new Set(['credentials', 'output', ...Object.keys(args)]);
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i]?.replace(/^--/, '');
    if (!argv[i]?.startsWith('--') || !allowed.has(key) || !argv[i + 1] || argv[i + 1].startsWith('--')) throw Error('Invalid arguments');
    args[key] = argv[i + 1];
  }
  for (const key of ['repetitions', 'seconds', 'writes']) args[key] = Number(args[key]);
  args.clients = args.clients.split(',').map(Number);
  if (!args.credentials || !args.output || !['sse', 'polling'].includes(args.mode) ||
      !['chrome', 'msedge'].includes(args.channel) ||
      !args.clients.length || args.clients.some(n => !Number.isInteger(n) || n < 1 || n > 10) ||
      !Number.isInteger(args.repetitions) || args.repetitions < 1 || args.repetitions > 10 ||
      !Number.isInteger(args.seconds) || args.seconds < 10 || args.seconds > 600 ||
      !Number.isInteger(args.writes) || args.writes < 1 || args.writes > 20) throw Error('Arguments outside supported bounds');
  if (args.contexts !== null) {
    args.contexts = Number(args.contexts);
    if (!Number.isInteger(args.contexts) || args.contexts < 1 || args.contexts > 10 ||
        args.clients.some(n => Math.ceil(n / Math.min(n, args.contexts)) > 8)) throw Error('Invalid tab grouping');
  }
  return args;
}
function assertCredentials(credentials) {
  const origin = new URL(credentials.origin);
  if (origin.protocol !== 'https:' || origin.pathname !== '/' || origin.search || origin.hash || origin.username || origin.password ||
      credentials.kind !== 'disposable-integrated-shared-care' || !Array.isArray(credentials.clients) || credentials.clients.length !== 3 ||
      typeof credentials.fixtureId !== 'string' || credentials.fixtureId.length < 24) throw Error('Invalid private fixture credentials');
  return origin;
}
function assertFixture(credentials, state) {
  assertCredentials(credentials);
  if (state.kind !== credentials.kind || state.fixtureId !== credentials.fixtureId ||
      state.fixture?.animals !== 100 || state.fixture?.feedings !== 2000) throw Error('Refusing non-matching disposable fixture');
}
function phaseNow() { return {startedAt: new Date().toISOString(), routes: {}, bytes: {cdpEncodedChunk: 0, decodedBody: 0}, sseEvents: {}, failures: []}; }

async function attachCapture(page) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Network.enable');
  const requests = new Map(), jobs = new Set();
  const subject = {page, phase: null, cdp, pageErrors: 0, openEvents: 0};
  page.on('pageerror', () => subject.pageErrors++);
  cdp.on('Network.requestWillBeSent', e => {
    const route = routeOf(e.request.url);
    if (!route.startsWith('/api/v1/')) return;
    if (requests.size > 4096) throw Error('Capture request bound exceeded');
    requests.set(e.requestId, {route, method: e.request.method, status: null});
    if (subject.phase) {
      const item = subject.phase.routes[route] ||= {requests: 0, getRequests: 0, statuses: {}};
      item.requests++;
      if (e.request.method === 'GET') item.getRequests++;
    }
  });
  cdp.on('Network.responseReceived', e => {
    const request = requests.get(e.requestId);
    if (!request) return;
    request.status = e.response.status;
    if (request.route === '/api/v1/changes/events' && request.status === 200) subject.openEvents++;
    if (subject.phase) {
      const item = subject.phase.routes[request.route] ||= {requests: 0, getRequests: 0, statuses: {}};
      item.statuses[request.status] = (item.statuses[request.status] || 0) + 1;
    }
  });
  cdp.on('Network.dataReceived', e => {
    if (subject.phase && requests.has(e.requestId)) {
      subject.phase.bytes.cdpEncodedChunk += e.encodedDataLength;
      subject.phase.bytes.decodedBody += e.dataLength;
    }
  });
  cdp.on('Network.eventSourceMessageReceived', e => {
    if (subject.phase) {
      const name = ['keepalive', 'changes', 'reset', 'auth-required'].includes(e.eventName) ? e.eventName : 'other';
      subject.phase.sseEvents[name] = (subject.phase.sseEvents[name] || 0) + 1;
    }
  });
  cdp.on('Network.loadingFinished', e => requests.delete(e.requestId));
  cdp.on('Network.loadingFailed', e => {
    const request = requests.get(e.requestId), phase = subject.phase;
    requests.delete(e.requestId);
    if (!request || !phase) return;
    const failure = {route: request.route, status: request.status,
      terminal: /^net::ERR_[A-Z_]+$/.test(e.errorText) ? e.errorText : 'other',
      bodyOutcome: 'unavailable', applicationOutcome: 'not-established-by-terminal-event'};
    phase.failures.push(failure);
    if (request.route === '/api/v1/changes/events') return;
    const job = cdp.send('Network.getResponseBody', {requestId: e.requestId}).then(body => {
      const bytes = body.base64Encoded ? Buffer.from(body.body, 'base64') : Buffer.from(body.body);
      try { JSON.parse(bytes.toString('utf8')); failure.bodyOutcome = 'complete-valid-json'; }
      catch { failure.bodyOutcome = 'available-invalid-json'; }
      failure.bodyBytes = bytes.length;
    }).catch(() => {}).finally(() => jobs.delete(job));
    jobs.add(job);
  });
  subject.drain = async () => Promise.all([...jobs]);
  return subject;
}

async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({state: 'attached', timeout: 30000});
  await placeholder.dispatchEvent('click');
}
async function waitName(page, view, name) {
  if (view === 'overview') {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const item = page.getByRole('button', {name: new RegExp('^' + escaped + '(?:\\s|$)')}).first();
    await item.waitFor(); return item;
  }
  const item = page.getByText(name, {exact: true}).or(page.getByLabel(name, {exact: true})).first();
  await item.waitFor(); return item;
}
async function probe(page, reset) {
  return page.evaluate(reset => typeof window.tm230Metrics === 'function' ? JSON.parse(window.tm230Metrics(reset)) : null, reset);
}
async function pixelDigest(page, bytes) {
  return page.evaluate(async encoded => {
    const png = Uint8Array.from(atob(encoded), char => char.charCodeAt(0));
    const bitmap = await createImageBitmap(new Blob([png], {type: 'image/png'}));
    const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    const context = canvas.getContext('2d'); context.drawImage(bitmap, 0, 0); bitmap.close();
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const hash = await crypto.subtle.digest('SHA-256', pixels);
    return [...new Uint8Array(hash)].map(n => n.toString(16).padStart(2, '0')).join('');
  }, bytes.toString('base64'));
}
async function region(page, locator) {
  const box = await locator.boundingBox();
  if (!box || box.width < 2 || box.height < 2) throw Error('No visible data region');
  // A fixed viewport crop keeps before/after comparable even if a label changes width.
  const viewport = page.viewportSize();
  const clip = {x: 0, y: Math.max(0, Math.floor(box.y) - 3), width: viewport.width,
    height: Math.min(100, viewport.height - Math.max(0, Math.floor(box.y) - 3))};
  const bytes = await page.screenshot({clip, animations: 'disabled'});
  return {clip, digest: await pixelDigest(page, bytes)};
}
async function observeWrite(subjects, control, origin, view, previousName, nextName) {
  const before = await Promise.all(subjects.map(async s => region(s.page, await waitName(s.page, view, previousName))));
  const current = await control.context.request.get(origin + '/api/v1/animals/1');
  if (current.status() !== 200) throw Error('Cannot read synthetic Animal');
  const record = (await current.json()).animal;
  const data = renamePayload(record, nextName);
  const start = Date.now();
  const observations = subjects.map(async (s, i) => {
    await waitName(s.page, view, nextName);
    const semanticsMs = Date.now() - start;
    await s.page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const bytes = await s.page.screenshot({clip: before[i].clip, animations: 'disabled'});
    const screenshotUpperBoundMs = Date.now() - start;
    return {client: i + 1, semanticsMs, screenshotUpperBoundMs,
      dataRegionPixelsChanged: await pixelDigest(s.page, bytes) !== before[i].digest};
  });
  // Attach handlers immediately so a failed command cannot leave rejected observers unhandled.
  const collected = Promise.allSettled(observations);
  const response = await control.context.request.put(origin + '/api/v1/animals/1', {
    data, headers: {Origin: origin, 'X-CSRF-Token': control.csrf},
  });
  if (response.status() !== 200) {
    await collected; throw Error('Synthetic command failed: HTTP ' + response.status());
  }
  const values = await collected;
  if (values.some(v => v.status !== 'fulfilled')) throw Error('A Flutter view did not reflect the command');
  return {startedAt: new Date(start).toISOString(), status: response.status(),
    observations: values.map(v => v.value)};
}

async function runTrial(browser, credentials, options, clients, repetition, save, report) {
  const contexts = [], subjects = [], origin = new URL(credentials.origin).origin;
  const trial = {clients, repetition, views: [], status: 'starting'};
  report.trials.push(trial);
  let control, name = 'Evaluation Animal 1';
  try {
    const controller = await browser.newContext(); contexts.push(controller);
    const login = await controller.request.post(origin + '/api/v1/auth/login', {
      data: {username: credentials.username, password: credentials.password}, headers: {Origin: origin},
    });
    if (login.status() !== 200) throw Error('Controller login failed');
    control = {context: controller, csrf: (await login.json()).csrfToken};
    const state = await controller.request.get(origin + '/evaluation/state');
    if (state.status() !== 200) throw Error('Disposable identity missing');
    assertFixture(credentials, await state.json());
    const animal = await controller.request.get(origin + '/api/v1/animals/1');
    if (animal.status() !== 200) throw Error('Fixture Animal missing');
    name = (await animal.json()).animal.commonName;
    const groups = Math.min(clients, options.contexts || clients), clientContexts = [];
    for (let group = 0; group < groups; group++) {
      const context = await browser.newContext({viewport: {width: 1100, height: 900}, locale: 'de-DE'});
      contexts.push(context); clientContexts.push(context);
      const account = credentials.clients[group % credentials.clients.length];
      const response = await context.request.post(origin + '/api/v1/auth/login', {data: account, headers: {Origin: origin}});
      if (response.status() !== 200) throw Error('Client login failed');
    }
    trial.logicalContexts = groups;
    for (let i = 0; i < clients; i++) {
      const page = await clientContexts[i % groups].newPage(); page.setDefaultTimeout(25000);
      const subject = await attachCapture(page); subjects.push(subject);
      await page.goto(origin, {timeout: 45000});
      if (await page.evaluate(() => !!window.evaluation)) throw Error('Expected production Flutter UI');
      await enableSemantics(page);
      await page.getByRole('tab', {name: /Tiere|Animals/}).click();
      await waitName(page, 'overview', name);
    }
    for (const view of ['overview', 'detail']) {
      if (view === 'detail') for (const s of subjects) {
        await (await waitName(s.page, 'overview', name)).click();
        await waitName(s.page, 'detail', name);
      }
      // Let initial authoritative reads, route animations and SSE setup settle.
      await pause(5000);
      if (options.mode === 'sse') for (const s of subjects) {
        if (s.openEvents < 1) throw Error('Production Flutter SSE did not open');
      }
      if (options.mode === 'polling' && subjects.some(s => s.openEvents > 0)) throw Error('Polling baseline unexpectedly uses SSE');
      for (const workload of ['idle', 'writes']) {
        const window = {view, workload, startedAt: new Date().toISOString(), writes: [], clients: []};
        trial.views.push(window);
        const initialMetrics = await controller.request.get(origin + '/evaluation/metrics');
        window.serverBefore = await initialMetrics.json();
        for (const s of subjects) {
          const visibility = await s.page.evaluate(() => document.visibilityState);
          if (visibility !== 'visible') throw Error('Foreground trial contains a hidden page');
          await probe(s.page, true); s.phase = phaseNow();
        }
        window.startedAt = new Date().toISOString();
        console.log('START ' + JSON.stringify({clients, repetition, view, workload, at: window.startedAt}));
        const start = Date.now();
        if (workload === 'idle') await pause(options.seconds * 1000);
        else for (let write = 0; write < options.writes; write++) {
          const next = 'Evaluation Animal 1 [' + crypto.randomBytes(5).toString('hex') + ']';
          window.writes.push(await observeWrite(subjects, control, origin, view, name, next));
          name = next;
          // Fixed wall-clock slots: each write has the same minimum spacing in both modes.
          await pause(Math.max(0, start + (write + 1) * 30000 - Date.now()));
        }
        window.finishedAt = new Date().toISOString(); window.wallMs = Date.now() - start;
        for (const [i, s] of subjects.entries()) {
          await s.drain();
          window.clients.push({client: i + 1, ...s.phase, frames: await probe(s.page, false), pageErrors: s.pageErrors,
            visibility: await s.page.evaluate(() => document.visibilityState),
            liveStreamByteCoverage: Object.keys(s.phase.sseEvents).length === 0 || s.phase.bytes.decodedBody > 0});
          s.phase = null;
        }
        const after = await controller.request.get(origin + '/evaluation/metrics');
        window.serverAfter = await after.json();
        const times = window.writes.flatMap(w => w.observations.map(o => o.screenshotUpperBoundMs));
        window.screenshotUpperBoundMs = summarize(times);
        window.semanticsMs = summarize(window.writes.flatMap(w => w.observations.map(o => o.semanticsMs)));
        save(); console.log('DONE ' + view + '/' + workload);
      }
    }
    trial.status = 'complete';
  } finally {
    for (const s of subjects) s.phase = null;
    for (const context of contexts.slice(1).reverse()) await context.close();
    if (control) {
      const deadline = Date.now() + 5000;
      do {
        const response = await control.context.request.get(origin + '/evaluation/metrics');
        if (response.status() !== 200) break;
        trial.streamsAfterClose = (await response.json()).streams;
        if (trial.streamsAfterClose === 0) break;
        await pause(100);
      } while (Date.now() < deadline);
    }
    if (contexts[0]) await contexts[0].close();
    save();
  }
  if (trial.streamsAfterClose !== 0) throw Error('Streams retained after trial');
}
async function main() {
  const options = parseArgs(process.argv.slice(2));
  const credentials = JSON.parse(fs.readFileSync(options.credentials, 'utf8'));
  if (fs.existsSync(options.output)) throw Error('Output already exists');
  const origin = assertCredentials(credentials);
  const args = [];
  if (process.env.TM230_LOOPBACK_SPKI) {
    if (origin.hostname !== '127.0.0.1') throw Error('Test certificate pin restricted to loopback');
    args.push('--ignore-certificate-errors-spki-list=' + process.env.TM230_LOOPBACK_SPKI);
  }
  const {chromium} = require('playwright');
  const browser = await chromium.launch({channel: options.channel, headless: true, args});
  const report = {schema: 1, kind: 'integrated-flutter-acceptance', createdAt: new Date().toISOString(),
    browser: browser.version(), mode: options.mode, channel: options.channel, trials: [],
    limits: [
      'Logical contexts/tabs on one desktop controller are not separate physical devices or mobile browsers.',
      'Each trial is one repetition; client observations within it are correlated.',
      'CDP body bytes include live SSE upkeep and resync/fallback, but exclude headers/TLS/TCP overhead.',
      'Use decodedBody for body comparisons; cdpEncodedChunk can be zero for an unfinished live stream despite delivered data and is not complete wire bandwidth.',
      'Screenshot completion is a conservative capture upper bound after matching semantics and two animation callbacks; semantics alone is not paint.',
      'No screenshots, response bodies, credentials, cookies, cursor or original HAR are persisted.',
      'Only the optional probe build reports Flutter drawFrame CPU, not widget build counts or physical presentation.',
      'Historical baseline used Feeding writes; these matched repeated trials use Animal-name writes in both views.',
      'A terminal request failure is not automatically an application failure or success; unavailable body evidence stays unresolved.',
      'Pi resource data, physical lifecycle checks and a 30-minute/100-reconnect soak are separate acceptance gates.',
    ]};
  const save = () => fs.writeFileSync(options.output, JSON.stringify(report, null, 2) + '\n', {mode: 0o600});
  fs.writeFileSync(options.output, '', {flag: 'wx', mode: 0o600});
  try {
    for (let r = 1; r <= options.repetitions; r++) for (const clients of options.clients) {
      await runTrial(browser, credentials, options, clients, r, save, report);
    }
    report.status = 'complete'; report.completedAt = new Date().toISOString();
  } catch (error) { report.status = 'incomplete'; report.error = 'Capture failed; inspect local console'; throw error; }
  finally { await browser.close(); save(); }
}
module.exports = {parseArgs, assertFixture, percentile, summarize, routeOf, renamePayload};
if (require.main === module) main().catch(error => {console.error(String(error.message).split('\n')[0]); process.exitCode = 1;});
