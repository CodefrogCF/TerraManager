'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {makePlan, parseArgs, validateResult} = require('./run_sse_comparison.cjs');

test('each repetition covers both modes idle/writes and alternates the order', () => {
  const plan = makePlan();
  assert.equal(plan.measuredSeconds, 1440);
  assert.equal(plan.trials.length, 12);
  for (let repetition = 1; repetition <= 3; repetition++) {
    const cases = plan.trials.filter(item => item.repetition === repetition);
    assert.deepEqual(new Set(cases.map(item => item.phase + ':' + item.mode)),
      new Set(['idle:polling', 'idle:sse', 'writes:polling', 'writes:sse']));
  }
  assert.equal(plan.trials[0].mode, 'polling');
  assert.equal(plan.trials[4].phase, 'writes');
});

test('invalid dimensions and unknown flags cannot silently change the workload', () => {
  for (const options of [{clients: 0}, {seconds: 39}, {repetitions: NaN}, {clients: 11}]) {
    assert.throws(() => makePlan(options));
  }
  assert.throws(() => parseArgs(['--production', 'yes']));
  assert.deepEqual(parseArgs(['--plan', '--clients', '3']), {plan: true, clients: '3'});
});

test('partial results and missing observations stop the comparison', () => {
  const plan = makePlan({clients: 1});
  const trial = {phase: 'writes', mode: 'sse'};
  const result = {serverMetadata: {kind: 'disposable-transport-lab'}, clients: 1,
    seconds: 120, view: 'overview', mode: 'sse', errors: 0, missingObservations: 0,
    writes: 1, clientsDetail: [{expectedChanges: 1, observedChanges: 1}]};
  const report = {kind: 'disposable-api-and-lab-dom-workload', results: [result]};
  assert.equal(validateResult(report, trial, plan), result);
  result.clientsDetail[0].observedChanges = 0;
  assert.throws(() => validateResult(report, trial, plan));
});
