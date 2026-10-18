'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {parseArgs, assertFixture, percentile, summarize, routeOf, renamePayload} = require('./integrated_benchmark.cjs');
test('argument bounds reject overloaded accounts and incomplete captures', () => {
  const base = ['--credentials', 'private.json', '--output', 'result.json'];
  assert.deepEqual(parseArgs([...base, '--clients', '1,3,5,10', '--repetitions', '3']).clients, [1,3,5,10]);
  assert.equal(parseArgs([...base, '--clients', '10', '--contexts', '3']).contexts, 3);
  for (const extra of [['--clients', '11'], ['--clients', '10', '--contexts', '1'], ['--repetitions', '0'],
    ['--seconds', 'NaN'], ['--writes', '21'], ['--mode', 'unknown'], ['--channel', 'safari'], ['--unknown', 'a'], ['--seconds']]) {
    assert.throws(() => parseArgs([...base, ...extra]));
  }
});
test('matching synthetic fixture identity is mandatory before commands', () => {
  const credentials = {origin: 'https://192.0.2.1:8443', kind: 'disposable-integrated-shared-care',
    fixtureId: 'a'.repeat(32), clients: [{}, {}, {}]};
  const state = {kind: credentials.kind, fixtureId: credentials.fixtureId, fixture: {animals: 100, feedings: 2000}};
  assert.doesNotThrow(() => assertFixture(credentials, state));
  assert.throws(() => assertFixture(credentials, {...state, kind: 'disposable-transport-lab'}));
  assert.throws(() => assertFixture(credentials, {...state, fixtureId: 'b'.repeat(32)}));
  assert.throws(() => assertFixture({...credentials, origin: 'http://192.0.2.1'}, state));
  assert.throws(() => assertFixture({...credentials, origin: 'https://192.0.2.1/?password=secret'}, state));
});
test('percentiles are per-trial nearest-rank values; empty samples stay unavailable', () => {
  assert.equal(percentile([], .95), null);
  assert.deepEqual(summarize([20, 5, 10, 15]), {n: 4, p50: 10, p95: 20});
  assert.equal(routeOf('https://example.test/api/v1/animals/23?since=private'), '/api/v1/animals/:id');
});
test('a name command preserves required display flags and optional profile data without immutable fields', () => {
  const result = renamePayload({id: 1, revision: 'rev', commonName: 'old', latinName: 'Example',
    showWeightOnDetail: false, showSheddingOnDetail: true, birthDate: null, notes: 'retained', createdAt: 'ignored'}, 'new');
  assert.equal(result.expectedRevision, 'rev');
  assert.equal(result.commonName, 'new');
  assert.equal(result.showWeightOnDetail, false);
  assert.equal(result.showSheddingOnDetail, true);
  assert.equal(result.notes, 'retained');
  assert.equal(result.birthDate, null);
  assert.equal('id' in result, false);
  assert.equal('createdAt' in result, false);
});
