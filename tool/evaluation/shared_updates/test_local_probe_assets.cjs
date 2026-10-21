'use strict';
const {test} = require('node:test'), assert = require('node:assert/strict'), path = require('node:path');
const {assetPath} = require('./local_probe_assets.cjs');
test('probe asset lookup confines decoded paths to the explicit local build', () => {
  const root = path.resolve('local-build');
  assert.equal(assetPath(root, '/'), path.join(root, 'index.html'));
  assert.equal(assetPath(root, '/canvaskit/canvaskit.wasm'), path.join(root, 'canvaskit/canvaskit.wasm'));
  for (const value of ['/../private.json', '/%2e%2e/private.json', '/%5c..%5cprivate', '/%00secret', '/%bad']) {
    assert.throws(() => assetPath(root, value));
  }
});
