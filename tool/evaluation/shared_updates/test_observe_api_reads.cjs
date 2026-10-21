'use strict';
const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const {chromium} = require('playwright');
const {installReadObserver, correlateReadFailure} = require('./observe_api_reads.cjs');
const {installSemanticsObserver} = require('./observe_semantics.cjs');
let browser, server, origin;
before(async () => {
  server = http.createServer((request, response) => {
    if (!request.url.startsWith('/api/')) { response.end('<title>Read observation control</title>'); return; }
    const body = '{"animals":[1,2,3]}';
    if (request.url.endsWith('/2')) {
      response.writeHead(200, {'Content-Type': 'application/json', 'Content-Length': String(body.length + 50)});
      response.write(body.slice(0, 8)); setTimeout(() => response.destroy(), 50); return;
    }
    response.writeHead(200, {'Content-Type': 'application/json', 'Cache-Control': 'no-store'});
    response.write(body); setTimeout(() => response.end('\n'), 50);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  origin = 'http://127.0.0.1:' + server.address().port;
  browser = await chromium.launch({channel: 'chrome', headless: true});
});
after(async () => {
  if (browser) await browser.close();
  if (server) { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
});
async function capture(id, behavior) {
  const context = await browser.newContext();
  try {
    await context.addInitScript(installReadObserver);
    const page = await context.newPage(); await page.goto(origin);
    await page.evaluate(async ({id, behavior}) => {
      const response = await fetch(typeof id === 'string' ? id : '/api/v1/animals/' + id), reader = response.body.getReader();
      let text = ''; const decoder = new TextDecoder();
      try {
        for (;;) {
          const chunk = await reader.read(); if (chunk.done) break;
          text += decoder.decode(chunk.value, {stream: true});
          if (behavior === 'cancel') { JSON.parse(text); await reader.cancel(); return; }
        }
        text += decoder.decode();
        if (behavior === 'parse') JSON.parse(text);
      } catch (_) { /* The truncated-response case must remain a read error. */ }
    }, {id, behavior});
    return await page.evaluate(() => window.__tm230ReadSnapshot());
  } finally { await context.close(); }
}
test('complete actual consumption is distinguished from a terminal event', async () => {
  const snapshot = await capture(1, 'parse'), read = snapshot.records[0];
  assert.equal(read.eof, true); assert.equal(read.jsonValid, true);
  assert.equal(read.applicationJsonParsed, true); assert.equal(read.listCount, 3);
  assert.equal(snapshot.droppedReads, 0);
  assert.equal('_text' in read, false); assert.equal('_decoder' in read, false);
  const classified = correlateReadFailure({route: read.route, ordinal: 1, bodyOutcome: 'unavailable'}, snapshot.records);
  assert.equal(classified.bodyOutcome, 'actual-body-valid-json-read-to-eof');
  assert.equal(classified.applicationOutcome, 'json-decoded-by-actual-application-consumer');
});
test('JSON changes reconciliation is observed without retaining its query', async () => {
  const snapshot = await capture('/api/v1/changes?since=private-test-cursor', 'parse');
  assert.equal(snapshot.records.length, 1);
  assert.equal(snapshot.records[0].route, '/api/v1/changes');
  assert.equal(snapshot.records[0].eof, true);
  assert.equal(snapshot.records[0].applicationJsonParsed, true);
  assert.equal(JSON.stringify(snapshot).includes('private-test-cursor'), false);
  assert.equal((await capture('/api/v1/changes/events', 'parse')).records.length, 0);
});
test('truncated HTTP 200 is never classified as a successful application read', async () => {
  const {records} = await capture(2, 'parse'), read = records[0];
  assert.equal(read.status, 200); assert.equal(read.eof, false);
  assert.equal(read.applicationJsonParsed, false); assert.ok(read.readerError);
  const result = correlateReadFailure({route: read.route, ordinal: 1, bodyOutcome: 'unavailable'}, records);
  assert.equal(result.bodyOutcome, 'actual-reader-error');
});
test('cancelling after a valid first JSON chunk does not establish complete consumption', async () => {
  const {records} = await capture(3, 'cancel'), read = records[0];
  assert.equal(read.eof, false); assert.equal(read.cancelCalled, true);
  assert.equal(read.cancelAfterEof, false); assert.equal(read.applicationJsonParsed, false);
  assert.equal(correlateReadFailure({route: read.route, ordinal: 1, bodyOutcome: 'unavailable'}, records).bodyOutcome, 'unavailable');
});
test('observer validation is separate from application JSON decoding', async () => {
  const {records} = await capture(4, 'no-parse'), read = records[0];
  assert.equal(read.eof, true); assert.equal(read.jsonValid, true); assert.equal(read.applicationJsonParsed, false);
  assert.equal(correlateReadFailure({route: read.route, ordinal: 1}, records).applicationOutcome, 'not-established-by-read-observer');
  assert.equal(correlateReadFailure({route: read.route, ordinal: 99}, records).readEvidence, null);
});
test('native timestamps recognize merged Flutter row text and reject a name prefix', async () => {
  const context = await browser.newContext();
  try {
    await context.addInitScript(installSemanticsObserver);
    const page = await context.newPage(); await page.goto(origin);
    await page.evaluate(async () => {
      const row = document.createElement('flt-semantics');
      row.textContent = 'Previous Animal\nExample species'; document.body.appendChild(row);
      window.__tm230ArmName('Expected Animal');
      row.textContent = 'Expected AnimalExtra\nExample species';
      await new Promise(resolve=>setTimeout(resolve, 0));
      if (window.__tm230NameSnapshot().found) throw Error('Matched only a name prefix');
      row.textContent = 'Expected Animal\nExample species';
    });
    await page.waitForFunction(()=>window.__tm230NameSnapshot()?.twoAnimationCallbacksAt !== null);
    const result = await page.evaluate(()=>window.__tm230NameSnapshot());
    assert.equal(result.found, true);
    assert.ok(result.twoAnimationCallbacksAt >= result.observedAt);
    assert.equal('name' in result, false);
  } finally { await context.close(); }
});
