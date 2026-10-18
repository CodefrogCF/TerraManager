// Disposable fixture only. Requires Node, Playwright, Caddy, a local TLS certificate
// and the compiled fixture/adapter. Writes no credentials to its JSON report.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const net = require('node:net');
const https = require('node:https');
const http2 = require('node:http2');
const {spawn} = require('node:child_process');
const {StringDecoder} = require('node:string_decoder');
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const args = Object.fromEntries(process.argv.slice(2).map(arg => {
  const split = arg.indexOf('=');
  return [arg.slice(0, split), arg.slice(split + 1)];
}));
for (const key of ['fixture', 'adapter', 'caddy', 'cert', 'key', 'ca', 'output']) {
  if (!args[key]) throw Error('Missing argument: ' + key);
}
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(read, check, description, timeoutMilliseconds = 10000) {
  const end = Date.now() + timeoutMilliseconds;
  while (Date.now() < end) {
    const result = await read();
    if (check(result)) return result;
    await wait(20);
  }
  throw Error('Timed out: ' + description);
}
async function freePort() {
  const server = net.createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}
function child(command, argv, options = {}) {
  const process = spawn(command, argv, {windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'], ...options});
  process.stdout.on('error', () => {}); process.stderr.on('error', () => {});
  return process;
}
(async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'tm-sse-proxy-'));
  const ca = fs.readFileSync(args.ca);
  let fixture, caddy, browser;
  const records = [];
  try {
    const port = await freePort();
    const origin = 'https://127.0.0.1:' + port;
    fixture = child(path.resolve(args.fixture), [origin, path.resolve(args.adapter)]);
    const backendPort = await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(Error('Fixture startup timed out')), 15000);
      let output = '';
      fixture.stdout.on('data', chunk => {
        output += chunk;
        for (const line of output.split('\n')) {
          try { const data = JSON.parse(line); if (data.port) { clearTimeout(timeout); resolve(data.port); return; } } catch (_) {}
        }
      });
      fixture.once('exit', () => {clearTimeout(timeout); reject(Error('Fixture failed to start'));});
    });
    // Preserve the production gateway's directives; replace only test addresses,
    // TLS file paths and web root. No trust-store installation is performed.
    let config = fs.readFileSync(path.join(__dirname, '../../deploy/Caddyfile'), 'utf8');
    config = config.replace('default_sni {$TM_HOST}', 'admin off\n  auto_https disable_redirects\n  default_sni 127.0.0.1');
    config = config.replace('https://{$TM_HOST} {', origin + ' {\n  bind 127.0.0.1');
    config = config.replace('tls /certs/server.crt /certs/server.key',
      'tls "' + path.resolve(args.cert).replaceAll('\\', '/') + '" "' + path.resolve(args.key).replaceAll('\\', '/') + '"');
    config = config.replace('server:8080', '127.0.0.1:' + backendPort);
    config = config.replace('  handle /api/* {', '  handle /fixture/* {\n    reverse_proxy 127.0.0.1:' + backendPort + '\n  }\n  handle /api/* {');
    config = config.replace('root * /srv/web', 'root * "' + directory.replaceAll('\\', '/') + '"');
    const configFile = path.join(directory, 'Caddyfile'); fs.writeFileSync(configFile, config);
    caddy = child(path.resolve(args.caddy), ['run', '--config', configFile, '--adapter', 'caddyfile']);
    caddy.stderr.on('data', () => {});
    function request(method, route, session, body) {
      return new Promise((resolve, reject) => {
        const payload = body == null ? null : JSON.stringify(body);
        const headers = {'Content-Type': 'application/json'};
        if (session) { headers.Cookie = session.cookie; headers['X-CSRF-Token'] = session.csrf; }
        const req = https.request(origin + route, {method, ca, headers, rejectUnauthorized: true}, response => {
          const chunks = [];
          response.on('data', chunk => chunks.push(chunk));
          response.on('end', () => {
            const data = Buffer.concat(chunks).toString();
            resolve({status: response.statusCode, headers: response.headers, body: data ? JSON.parse(data) : null});
          });
          response.on('error', reject);
        });
        req.on('error', reject); req.setTimeout(10000, () => req.destroy(Error('Request timeout')));
        req.end(payload);
      });
    }
    await until(async () => { try { return (await request('GET', '/api/v1/health')).status; } catch (_) { return 0; } }, value => value === 200, 'trusted HTTPS gateway');
    async function login() {
      const reply = await request('POST', '/api/v1/auth/login', null,
        {username: 'sse-test-admin', password: 'Disposable SSE fixture password 123'});
      assert.equal(reply.status, 200);
      return {cookie: reply.headers['set-cookie'][0].split(';')[0], csrf: reply.body.csrfToken};
    }
    async function openStreams(expected) {
      return until(async () => (await request('GET', '/fixture/stats')).body.openStreams,
        value => value === expected, 'open stream count ' + expected);
    }
    const session = await login();
    // Real HTTP/1.1 and HTTP/2 connections through Caddy, repeatedly cancelled
    // while idle. Trust is verified using the supplied CA on every request.
    for (const protocol of ['h1', 'h2']) {
      for (let repetition = 0; repetition < 12; repetition++) {
        let close, start;
        const event = await new Promise((resolve, reject) => {
          let body = ''; const decoder = new StringDecoder('utf8');
          const consume = chunk => { body += decoder.write(chunk); if (body.includes('\n\n')) resolve(body); };
          if (protocol === 'h1') {
            const req = https.get(origin + '/api/v1/changes/events', {ca, headers: {Cookie: session.cookie}}, response => {
              assert.equal(response.statusCode, 200); response.on('data', consume); response.on('error', reject);
              close = () => {response.destroy(); req.destroy();};
            }); req.on('error', reject); start = req;
          } else {
            const connection = http2.connect(origin, {ca}); connection.on('error', reject);
            const req = connection.request({':path': '/api/v1/changes/events', cookie: session.cookie});
            req.on('data', consume); req.on('error', reject);
            close = () => {req.close(); connection.destroy();}; start = connection;
          }
          setTimeout(() => reject(Error('Initial SSE frame timeout')), 10000).unref();
        });
        assert.match(event, /event: changes/); await openStreams(1); close(); await openStreams(0);
      }
      records.push({kind: 'idle-disconnect', protocol, repetitions: 12, remainingStreams: 0});
    }
    // Use the real Dart web adapter, not a JavaScript replacement for it.
    const channels = (args.browsers || 'chrome,msedge').split(',');
    for (const channel of channels) {
      const launchArgs = args.spki ? ['--ignore-certificate-errors-spki-list=' + args.spki] : [];
      browser = await chromium.launch({channel, headless: true, args: launchArgs});
      const context = await browser.newContext();
      const split = session.cookie.indexOf('=');
      await context.addCookies([{name: session.cookie.slice(0, split), value: session.cookie.slice(split + 1),
        url: origin, secure: true, httpOnly: true, sameSite: 'Strict'}]);
      const page = await context.newPage();
      await page.goto(origin + '/fixture/browser');
      await page.waitForFunction(() => window.tmSseSmoke?.ready);
      const eventCount = () => page.evaluate(() => JSON.parse(window.tmSseSmoke.events).length);
      for (let repetition = 0; repetition < 8; repetition++) {
        await page.evaluate(() => window.tmSseSmoke.start('/api/v1/changes/events'));
        await until(eventCount, n => n === 1, 'browser initial hint');
        assert.equal((await request('POST', '/api/v1/boxes', session, {name: 'Private test Box ' + repetition})).status, 201);
        await until(eventCount, n => n >= 2, 'browser commit hint');
        const event = await page.evaluate(() => JSON.parse(window.tmSseSmoke.events).at(-1));
        assert.equal(event.event, 'changes'); assert.equal(event.id, event.data.cursor);
        assert.ok(!JSON.stringify(event).includes('Private test Box'));
        await page.evaluate(() => window.tmSseSmoke.stop()); await openStreams(0);
      }
      await page.evaluate(() => window.tmSseSmoke.start('/fixture/fragmented'));
      await until(eventCount, n => n === 1, 'fragmented UTF-8 frame');
      const fragment = await page.evaluate(() => JSON.parse(window.tmSseSmoke.events)[0]);
      assert.deepEqual(fragment, {event: 'changes', data: {note: 'Äö🦎'}, id: 'fragment-1'});
      await page.evaluate(() => window.tmSseSmoke.stop());
      if (args.heartbeat === 'true') {
        await page.evaluate(() => window.tmSseSmoke.start('/api/v1/changes/events'));
        await until(eventCount, n => n === 1, 'initial frame before keepalive');
        await until(() => page.evaluate(() => JSON.parse(window.tmSseSmoke.events).some(e => e.event === 'keepalive')),
          value => value, 'observable periodic keepalive through Caddy', 25000);
        await page.evaluate(() => window.tmSseSmoke.stop()); await openStreams(0);
        records.push({kind: 'observable-keepalive', browser: channel, intervalSeconds: 15,
          receivedWithoutCollectionWrite: true, remainingStreams: 0});
      }
      const protocol = await page.evaluate(() => performance.getEntriesByType('resource').find(e => e.name.endsWith('/fixture/adapter.js'))?.nextHopProtocol);
      records.push({kind: 'browser-adapter', browser: channel, version: browser.version(),
        protocol, commitAndDisconnectRepetitions: 8, fragmentedUtf8: true, remainingStreams: 0});
      // Initial unauthorized response must not keep the native retry running.
      await context.clearCookies(); let attempts = 0;
      page.on('request', request => { if (request.url().endsWith('/api/v1/changes/events')) attempts++; });
      await page.evaluate(() => window.tmSseSmoke.start('/api/v1/changes/events'));
      await page.waitForFunction(() => window.tmSseSmoke.errors === 1);
      await wait(3500); assert.equal(attempts, 1); await openStreams(0);
      records.push({kind: 'unauthorized-no-retry', browser: channel, attempts, observedMilliseconds: 3500});
      await context.close(); await browser.close(); browser = null;
    }
    const report = {schema: 1, kind: 'production-shared-care-sse-transport-smoke',
      observedAt: new Date().toISOString(), tls: {nodeCaVerified: true,
        browserTrust: args.spki ? 'explicit test certificate SPKI pin; no global TLS bypass' : 'system trust'},
      caddy: '2.11.4', records, limits: ['Local disposable Windows fixture; not Raspberry Pi performance evidence.',
        'Full Flutter behavior has separate widget tests; this browser test uses the compiled production EventSource adapter.',
        'HTTP/3, Safari and physical mobile browsers require the target-device matrix.']};
    fs.writeFileSync(args.output, JSON.stringify(report, null, 2) + '\n', {flag: 'wx'});
    console.log(JSON.stringify(report, null, 2));
  } finally {
    if (browser) await browser.close();
    if (caddy) { caddy.kill(); await new Promise(resolve => { if (caddy.exitCode != null) resolve(); else caddy.once('exit', resolve); }); }
    if (fixture && fixture.exitCode == null) {
      fixture.stdin.end('stop\n');
      await Promise.race([new Promise(resolve => fixture.once('exit', resolve)), wait(10000).then(() => fixture.kill())]);
    }
    const absoluteDirectory = path.resolve(directory);
    assert.equal(path.dirname(absoluteDirectory), path.resolve(os.tmpdir()));
    assert.ok(path.basename(absoluteDirectory).startsWith('tm-sse-proxy-'));
    fs.rmSync(absoluteDirectory, {recursive: true, force: true});
  }
})().catch(error => { console.error(error.stack); process.exitCode = 1; });
