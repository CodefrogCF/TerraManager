#!/usr/bin/env node
'use strict';
// Optional Playwright evaluation helper. No production code or new app dependency.
// Usage: node flutter_baseline.cjs --credentials private.json --output report.json
//        [--clients 5] [--seconds 120] [--channel chrome] [--observe-change]
// Requires the real Flutter web build backed by the disposable evaluation lab.
const fs = require('node:fs');
const crypto = require('node:crypto');
const {chromium} = require('playwright');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const normalize = pathname => pathname.replace(/\/\d+(?=\/|$)/g, '/:id');

async function main() {
  const args = {};
  for (let i = 2; i < process.argv.length; i++) {
    const key = process.argv[i];
    if (key === '--observe-change') args.observeChange = true;
    else if (['--credentials', '--output', '--clients', '--seconds', '--channel'].includes(key)) {
      if (!process.argv[i + 1] || process.argv[i + 1].startsWith('--')) throw Error('Missing argument value');
      args[key.slice(2)] = process.argv[++i];
    } else throw Error('Unknown argument');
  }
  const clients = Number(args.clients || 5), seconds = Number(args.seconds || 120);
  if (!args.credentials || !args.output || !Number.isInteger(clients) || clients < 1 || clients > 10 ||
      !Number.isFinite(seconds) || seconds < 30 || seconds > 600) throw Error('Invalid baseline arguments');
  if (fs.existsSync(args.output)) throw Error('Report already exists');
  const credentials = JSON.parse(fs.readFileSync(args.credentials, 'utf8'));
  const origin = new URL(credentials.origin);
  if (origin.protocol !== 'https:' || origin.pathname !== '/' || origin.search || origin.hash ||
      origin.username || origin.password) throw Error('Expected a plain HTTPS test origin');
  const browser = await chromium.launch({channel: args.channel || 'chrome', headless: true});
  const contexts = [], subjects = [], createdFeedings = [];
  let control;
  const report = {
    schema: 1, kind: 'real-flutter-disposable-lab-network-baseline',
    createdAt: new Date().toISOString(), browser: browser.version(), clients, secondsPerView: seconds,
    views: [], changeObservation: null,
    limits: [
      'One warm run; logical Chrome contexts on one controller, not separate physical devices.',
      'Real release Flutter UI with semantics enabled; this is not a Flutter rebuild/frame measurement.',
      'Synthetic fixture without media; startup, login and view transitions are outside idle windows.',
      'Resource Timing body/transfer sizes exclude TLS/TCP overhead and are not full LAN bandwidth.',
      'Optional update observation is one synthetic Feeding and correlated observations, not a percentile distribution.',
      'No Pi resource time series is collected by this helper.',
      'requestfailed includes post-header cancellation; retain failureEvents instead of assuming every event is an application error.',
      'mainFrameNavigations includes same-document Flutter routes; mainDocumentRequests counts actual document requests.',
      'Complete means the capture finished; it is not a zero-network-error acceptance claim.',
    ],
  };
  try {
    for (let index = 0; index <= clients; index++) {
      const context = await browser.newContext({viewport: {width: 1100, height: 900}, locale: 'de-DE'});
      context.setDefaultTimeout(15000);
      contexts.push(context);
      const login = await context.request.post(origin.origin + '/api/v1/auth/login', {
        data: {username: credentials.username, password: credentials.password}, headers: {Origin: origin.origin},
      });
      if (login.status() !== 200) throw Error('Test login failed: HTTP ' + login.status());
      const session = await login.json();
      if (index === clients) {
        control = {context, csrf: session.csrfToken};
        const state = await context.request.get(origin.origin + '/evaluation/state');
        if (state.status() !== 200 || (await state.json()).kind !== 'disposable-transport-lab') {
          throw Error('Refusing to measure or write outside the disposable lab');
        }
        continue;
      }
      const page = await context.newPage();
      const subject = {page, phase: null, pageErrors: 0, navigationCount: 0, documentRequests: 0};
      subjects.push(subject);
      const initial = new Set();
      const responseStatuses = new WeakMap();
      page.on('request', request => {
        if (request.isNavigationRequest() && request.frame() === page.mainFrame()) subject.documentRequests++;
      });
      page.on('response', response => {
        const request = response.request(), pathname = new URL(response.url()).pathname;
        responseStatuses.set(request, response.status());
        if (response.status() === 200 && ['/api/v1/boxes', '/api/v1/animals', '/api/v1/reminders'].includes(pathname)) initial.add(pathname);
        if (subject.phase && request.method() === 'GET' && pathname.startsWith('/api/v1/')) {
          const route = normalize(pathname), key = String(response.status());
          const item = subject.phase.routes[route] ||= {responses: 0, statuses: {}};
          item.responses++; item.statuses[key] = (item.statuses[key] || 0) + 1;
        }
      });
      page.on('requestfailed', request => {
        if (subject.phase && new URL(request.url()).pathname.startsWith('/api/v1/')) {
          subject.phase.failedRequests++;
          const failure = request.failure()?.errorText;
          subject.phase.failureEvents.push({route: normalize(new URL(request.url()).pathname),
            responseStatus: responseStatuses.get(request) || null,
            error: /^net::ERR_[A-Z_]+$/.test(failure || '') ? failure : 'OTHER'});
        }
      });
      page.on('pageerror', () => subject.pageErrors++);
      page.on('framenavigated', frame => { if (frame === page.mainFrame()) subject.navigationCount++; });
      await page.goto(origin.origin, {timeout: 30000});
      if (await page.evaluate(() => Boolean(window.evaluation))) throw Error('Expected real Flutter, received lab HTML');
      const deadline = Date.now() + 30000;
      while (initial.size < 3 && Date.now() < deadline) await pause(100);
      if (initial.size !== 3) throw Error('Flutter initial overview did not load');
      const placeholder = page.locator('flt-semantics-placeholder');
      if (await placeholder.count()) await placeholder.first().dispatchEvent('click');
      await page.getByRole('tab', {name: /Tiere|Animals/}).click();
      await page.getByRole('button', {name: /^Evaluation Animal 1(?:\s|$)/}).first().waitFor();
      console.log('READY client ' + (index + 1));
    }
    async function windowFor(view) {
      await pause(1500);
      const result = {view, startedAt: new Date().toISOString(), configuredSeconds: seconds, clients: []};
      for (const subject of subjects) {
        subject.phase = {routes: {}, failedRequests: 0, failureEvents: []};
        subject.start = await subject.page.evaluate(() => {
          performance.setResourceTimingBufferSize(10000);
          performance.clearResourceTimings();
          return {performanceMs: performance.now(), visibility: document.visibilityState,
            focused: document.hasFocus(), navigationEntries: performance.getEntriesByType('navigation').length};
        });
      }
      const started = Date.now();
      console.log('START ' + view + ' ' + result.startedAt);
      while (Date.now() - started < seconds * 1000) await pause(Math.min(1000, seconds * 1000 - (Date.now() - started)));
      result.finishedAt = new Date().toISOString();
      result.measuredWallMs = Date.now() - started;
      for (const [index, subject] of subjects.entries()) {
        const end = await subject.page.evaluate(startMs => {
          const ended = performance.now();
          const entries = performance.getEntriesByType('resource').filter(entry =>
            new URL(entry.name).pathname.startsWith('/api/v1/') && entry.startTime >= startMs && entry.startTime < ended);
          return {visibility: document.visibilityState, focused: document.hasFocus(),
            navigationEntries: performance.getEntriesByType('navigation').length,
            observedMs: ended - startMs,
            resources: entries.map(entry => ({route: new URL(entry.name).pathname.replace(/\/\d+(?=\/|$)/g, '/:id'),
              encodedBodyBytes: entry.encodedBodySize, decodedBodyBytes: entry.decodedBodySize,
              transferBytes: entry.transferSize, durationMs: entry.duration, protocol: entry.nextHopProtocol}))};
        }, subject.start.performanceMs);
        const phase = subject.phase;
        subject.phase = null;
        result.clients.push({client: index + 1, start: subject.start, end,
          ...phase, pageErrors: subject.pageErrors, mainFrameNavigations: subject.navigationCount,
          mainDocumentRequests: subject.documentRequests});
      }
      report.views.push(result);
      fs.writeFileSync(args.output, JSON.stringify(report, null, 2) + '\n');
      console.log('DONE ' + view + ' responses=' + result.clients.reduce((sum, item) =>
        sum + Object.values(item.routes).reduce((n, route) => n + route.responses, 0), 0));
    }
    await windowFor('animals-overview');
    for (const subject of subjects) {
      await subject.page.getByRole('button', {name: /^Evaluation Animal 1(?:\s|$)/}).first().click();
      await subject.page.getByRole('button', {name: /Letzte Fütterung|Last feeding/i}).waitFor();
    }
    await windowFor('animal-detail');
    if (args.observeChange) {
      for (const subject of subjects) await subject.page.evaluate(() => {
        const read = () => [...document.querySelectorAll('[role="button"]')]
          .find(node => /Letzte Fütterung|Last feeding/i.test(node.textContent || ''))?.textContent;
        const before = read();
        if (!before) throw Error('Last Feeding semantics missing');
        window.__tm186ObservedChange = null;
        window.__tm186Observer = new MutationObserver(() => {
          const value = read();
          if (value && value !== before) {
            window.__tm186ObservedChange = Date.now();
            window.__tm186Observer.disconnect();
          }
        });
        window.__tm186Observer.observe(document.body, {subtree: true, childList: true, characterData: true});
      });
      const writeStarted = Date.now();
      const response = await control.context.request.post(origin.origin + '/api/v1/feedings', {
        data: {animalIds: [1], fedAt: new Date(writeStarted - 1000).toISOString(), notes: 'Synthetic real Flutter baseline'},
        headers: {Origin: origin.origin, 'X-CSRF-Token': control.csrf, 'Idempotency-Key': crypto.randomUUID()},
      });
      if (response.status() !== 201) throw Error('Synthetic Feeding failed: HTTP ' + response.status());
      for (const feeding of (await response.json()).feedings) createdFeedings.push(feeding.id);
      await Promise.all(subjects.map(subject => subject.page.waitForFunction(() => window.__tm186ObservedChange !== null, undefined, {timeout: 22000})));
      report.changeObservation = {writes: 1, status: response.status(), writeStartedAt: new Date(writeStarted).toISOString(),
        writeStartToFlutterSemanticsMs: await Promise.all(subjects.map(subject => subject.page.evaluate(start =>
          window.__tm186ObservedChange - start, writeStarted)))};
      console.log('CHANGE ' + JSON.stringify(report.changeObservation));
    }
    report.completedAt = new Date().toISOString();
    report.status = 'complete';
  } finally {
    const statuses = [];
    if (control) for (const id of createdFeedings) {
      const response = await control.context.request.delete(origin.origin + '/api/v1/feedings/' + id,
        {headers: {Origin: origin.origin, 'X-CSRF-Token': control.csrf}});
      statuses.push(response.status());
    }
    report.cleanup = {syntheticFeedings: createdFeedings.length, statuses};
    for (const context of contexts.reverse()) await context.close();
    await browser.close();
    fs.writeFileSync(args.output, JSON.stringify(report, null, 2) + '\n');
    if (statuses.some(status => status !== 200)) throw Error('Synthetic Feeding cleanup failed');
  }
  console.log('REPORT ' + args.output);
}
main().catch(error => { console.error(String(error.message).split('\n')[0]); process.exitCode = 1; });
