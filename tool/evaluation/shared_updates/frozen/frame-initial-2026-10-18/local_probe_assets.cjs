'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
function assetPath(root, pathname) {
  const decoded = decodeURIComponent(pathname);
  if (decoded.includes('\\') || decoded.includes('\0')) throw Error('Invalid static path');
  const target = path.resolve(root, '.' + (decoded === '/' ? '/index.html' : decoded));
  if (!target.startsWith(path.resolve(root) + path.sep)) throw Error('Static path escapes build');
  return target;
}
function artifact(root) {
  const files = ['index.html', 'flutter_bootstrap.js', 'main.dart.js'];
  return {kind: 'supplementary-local-Flutter-probe', files: Object.fromEntries(files.map(name =>
    [name, crypto.createHash('sha256').update(fs.readFileSync(path.join(root, name))).digest('hex')])),
    limit: 'Only static app assets are fulfilled locally with no-store; API/evaluation requests still use the trusted Pi gateway. Not a production release/network-byte baseline.'};
}
async function installProbeAssets(context, origin, root) {
  const types = {'.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
    '.wasm': 'application/wasm', '.png': 'image/png', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.otf': 'font/otf'};
  await context.route(origin + '/**', async route => {
    const url = new URL(route.request().url());
    if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/evaluation/')) return route.continue();
    try {
      const file = assetPath(root, url.pathname), real = fs.realpathSync(file);
      if (!real.startsWith(fs.realpathSync(root) + path.sep) || !fs.statSync(real).isFile()) throw Error('Not an asset');
      await route.fulfill({status: 200, body: fs.readFileSync(real), headers: {'content-type': types[path.extname(real)] || 'application/octet-stream', 'cache-control': 'no-store'}});
    } catch { await route.fulfill({status: 404, body: 'Probe asset missing'}); }
  });
}
module.exports = {assetPath, artifact, installProbeAssets};
