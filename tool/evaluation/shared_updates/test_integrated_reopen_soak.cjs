'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {parseArgs, workloadThresholds} = require('./integrated_reopen_soak.cjs');

test('a short smoke never satisfies the duration/reopen acceptance workload', () => {
  assert.equal(workloadThresholds(60000, 120).reconnectWorkloadThresholdMet, false);
  assert.equal(workloadThresholds(1800000, 99).reconnectWorkloadThresholdMet, false);
  assert.equal(workloadThresholds(1800000, 100).reconnectWorkloadThresholdMet, true);
});
test('soak bounds preserve a fixed workload and reject unsupported controls', () => {
  const base = ['--credentials', 'private.json', '--output', 'report.json'];
  assert.equal(parseArgs(base).seconds, 1800);
  assert.equal(parseArgs([...base, '--seconds', '60', '--warmup', '0']).warmup, 0);
  for (const extra of [['--seconds', '29'], ['--seconds', '3601'], ['--warmup', '-1'],
    ['--clients', '10'], ['--channel', 'firefox'], ['--seconds', 'NaN'], ['--unknown', 'x']]) {
    assert.throws(() => parseArgs([...base, ...extra]));
  }
});
