'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {makePlan, parseArgs, validateResult, assertLabIdle, classifyBenchmarkFailure} = require('./run_sse_comparison.cjs');

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

function fakeRequestApi(streams) {
  const fixture = {disposed: false};
  fixture.api = {newContext: async () => ({
    post: async () => ({status: () => 200}),
    get: async url => ({status: () => 200, json: async () => url.endsWith('/evaluation/state') ?
      {kind: 'disposable-transport-lab'} : {streams}}),
    dispose: async () => { fixture.disposed = true; },
  })};
  return fixture;
}

test('a clean lab permits a trial and disposes the health context', async () => {
  const fixture = fakeRequestApi(0);
  await assertLabIdle({origin: 'https://test.invalid'}, {requestApi: fixture.api});
  assert.equal(fixture.disposed, true);
});

test('remaining streams stop a trial before browsers start', async () => {
  const fixture = fakeRequestApi(32);
  await assert.rejects(assertLabIdle({origin: 'https://test.invalid'},
    {requestApi: fixture.api, maxWaitMs: 0}), /lab_streams_not_idle count=32/);
  assert.equal(fixture.disposed, true);
});

test('diagnostics preserve only known categories, without request secrets', () => {
  assert.equal(classifyBenchmarkFailure('SSE connection failed\nAuthorization: PRIVATE'), 'sse_start_failed');
  assert.equal(classifyBenchmarkFailure('lab_streams_not_idle count=32\nCookie: PRIVATE'), 'lab_streams_not_idle count=32');
  assert.equal(classifyBenchmarkFailure('Authorization: PRIVATE'), null);
});
