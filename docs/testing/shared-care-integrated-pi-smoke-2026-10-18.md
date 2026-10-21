# Integrated Shared Care on Pi — first captures and measurement corrections

Date: 2026-10-18. Installed source: `2dee1f11a85309b5b8402c2c1d43d144ea28260d`.
Device: Raspberry Pi 5 Model B Rev 1.0, four cores, 4 GB RAM, Linux aarch64.
Browser controller: Windows x64, Chrome 155.0.8059.84, trusted LAN HTTPS.
Recorded event timestamps are UTC. These are short one-client preparation
captures; **Issue #230 remains open**.

## Real release Flutter UI

The installed production web image is served by the isolated test gateway. The
fixture uses the production API/SSE implementation and the fixed synthetic
100-Animal, five-Box, 2,000-Feeding dataset. There are no production collection
writes. The release UI has no frame-CPU instrumentation.

| Capture | View | Idle seconds | Idle data GETs | Idle received body bytes | Keepalives | Write-to-expected-semantics ms | Write-to-screenshot-completion upper bound ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Plain | Overview | 30 | 0 | 54 | 2 | 215 | 291 |
| Plain | Detail | 30 | 0 | 54 | 2 | 202 | 267 |
| Read observer | Overview | 30 | 0 | 54 | 2 | See JSON | 298 |
| Read observer | Detail | 30 | 0 | 54 | 2 | See JSON | 266 |

Every expected name change and its decoded pixel-region change was observed.
Each capture closed with zero retained server streams. No page error occurred.
There is one write observation per view in each capture, **not a meaningful p95
latency distribution**. Decoded body bytes include upkeep but exclude HTTP/TLS/TCP
headers/framing; they are not total wire bandwidth.

Inputs: [plain capture](data/shared-care-integrated-pi-smoke-2026-10-18.json),
[observed capture](data/shared-care-integrated-pi-observed-smoke-2026-10-18.json).

## Actual terminal request outcomes

The plain detail write emitted two `net::ERR_ABORTED` terminal events, for Boxes
and Animals, after HTTP 200. CDP could not retrieve their response bodies. The
raw capture retains those events as unresolved; a complete capture is not an
assertion that all terminal events are harmless.

A diagnostic installed bounded hooks before loading the actual Flutter app. It
kept the original native objects/pulls/cache policy and observed the bytes the
app consumed, EOF, JSON validity and the application's own JSON decoding. The
observer's validation calls use the saved native parser so they cannot count as
application consumption. Response text is transient and excluded from snapshots.

- A [separate three-write diagnostic](data/shared-care-integrated-pi-read-diagnostic-2026-10-18.json)
  captured three Animals `ERR_ABORTED` events. Each actual reader consumed 101,402
  bytes through EOF, validated JSON, and the Flutter consumer parsed the body.
  The detail page displayed the expected value after the corresponding read chain.
- The repeated short observed capture reproduced both a Boxes and an Animals
  `ERR_ABORTED`: respectively 1,981 and 101,402 bytes. Each was read through EOF
  and parsed by the actual application, with the expected detail UI update.
- These five concrete requests establish successful consumption despite their
  terminal event. They do not retroactively prove the first two requests or all
  historic aborts succeeded, and do not establish a universal browser root cause.

The repeated runner can now attach the evidence to the exact route/ordinal of
each failure. Negative browser controls distinguish truncated HTTP 200, early
cancellation after a valid first chunk, observer-only validation and actual
application JSON consumption. Source: `observe_api_reads.cjs` and its tests.

Diagnostic hooks add controller-side promise continuations and bounded decoding.
The two short runs do not quantify overhead as a distribution. The full repeated
comparison must retain the diagnostic mode and its limitations on both sides.

## Process observations and CPU interpretation

The [resource snapshot](data/shared-care-integrated-pi-resources-smoke-2026-10-18.jsonl)
contains 58 complete records spanning the plain smoke. Both process identities
remain stable. All six in-window probes per process/window have valid RSS.
The sample cadence is about five seconds; the maximum in-window gap is about
5.05 seconds. The clock tick rate is 100 Hz.

- Maximum sampled in-window RSS: Dart **126.44 MiB**, Caddy **44.47 MiB**.
- Those values are below the proposed sampled-memory budgets in this short run.
  They do not prove the warm multi-client or long-term memory bounds.
- Using only the first/last probes inside each 30-second window missed the
  initial write burst and returned zero tick deltas. Treating that as total CPU
  would understate the workload.
- The corrected analyzer uses surrounding endpoints for an upper bound and
  fully internal endpoints for a lower bound. It reports uncertainty and
  inconclusive results; some short idle budgets cannot be resolved at this cadence.

The [derived JSON](data/shared-care-integrated-pi-smoke-summary-2026-10-18.json)
and [table](data/shared-care-integrated-pi-smoke-summary-2026-10-18.md) preserve the
whole-window CPU bounds, raw-input hashes, RSS sample counts and probe coverage.
The first plain capture had no per-trial clock probes, so its zero-offset plus
100 ms guard is provisional. A [subsequent clock check](data/shared-care-integrated-pi-clock-2026-10-18.json)
bounded the Pi offset to +19 to +24 ms; the observed capture's own before/after
probes bounded it to +20 to +26 ms and +20 to +25 ms. No unqualified CPU-budget
acceptance is inferred from the provisional first capture.

New runs include six quiet seconds after every window to prevent the next
workload's CPU burst entering the surrounding boundary probes. The quiet time
is outside both modes' measured windows and is recorded in the plan.

## Validation and ongoing work

- Eight Node/browser-control tests passed, including negative read-consumption
  controls and the existing runner argument/fixture/command tests.
- Seventeen Python tests passed: CPU boundaries, joining overlapping captures,
  warm-median coverage/restarts, and matched comparisons that retain outliers
  and unresolved request evidence. Six existing CPU tests are included.
- Two new Node tests validate reopen-workload bounds and ensure that a short
  smoke or fewer than 100 actual reopens cannot satisfy its workload threshold.
  They do not validate the real browser reopen sequence; that capture is pending.
- The gateway-only switch helper passed Bash syntax validation. It has not yet
  been executed against Docker on the Pi.
- The observed Pi run completed all four windows with actual read evidence and
  zero retained streams. Production Dart/Flutter library source is unchanged.

The repeated SSE matrix was started with client order 5, 1, 3, 10 and three
repetitions, 120-second idle windows and three 30-second write slots per view.
It is a new diagnostic-tool revision whose hashes are recorded in that capture.
This first-smoke snapshot predates its completion. The subsequent
[full matrix report](shared-care-integrated-sse-matrix-2026-10-18.md) records all
twelve completed trials, the retained outlier and the remaining acceptance work.

Resource run IDs are `run-20261018T145330Z` (original three-hour capture) and
`run-20261018T174803Z` (replacement four-hour capture). Their short overlap must
be recorded when the full resource data is joined. Do not add their process CPU
or network counters together. Keep image/source identity evidence with the run.

The operator confirmed that the original polling web image is still available.
Exact immutable [image identities](data/shared-care-integrated-image-provenance-2026-10-18.json)
record the pre-SSE web image and the current API fixture/web image. The gateway
switch helper checks the intended immutable web-image ID before changing it.

Physical follow-up is planned on three Android devices with Firefox/Brave and a
Windows laptop with Firefox/Chrome/Edge. Models, browser/OS versions, certificate
trust, background/foreground, outage, expiry and restore outcomes remain to be
recorded. The matched polling matrix, supplementary Flutter frame windows,
30-minute/100-reconnect soak and final ADR budgets are also pending.

The [physical-check protocol](shared-care-integrated-physical-checks.md) records
the operator-reported Galaxy S25 Ultra/S22 and Windows 11 browser versions.
All physical outcomes remain `not run`; inventory is not test evidence.
