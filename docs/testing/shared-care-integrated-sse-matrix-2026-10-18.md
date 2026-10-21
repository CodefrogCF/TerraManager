# Integrated Shared Care SSE matrix on Raspberry Pi

Date: 2026-10-18. Source/image identities are recorded in the
[operator provenance](data/shared-care-integrated-image-provenance-2026-10-18.json).
Device: Raspberry Pi 5 Model B, four cores, 4 GB RAM, Linux aarch64.
Controller: Windows x64, Node 23.9.0, Chrome **155.0.8059.84**, trusted LAN HTTPS.
Production Flutter release UI and current production API on a disposable fixture:
100 Animals, five Boxes and 2,000 Feedings. Issue #230 remains open.

## Completed capture

The [raw metadata](data/shared-care-integrated-sse-matrix-2026-10-18.json)
contains all twelve trials: 1/3/5/10 clients, three repetitions each. Every trial
has overview/detail idle and write windows, for **48 completed windows**.
Idle windows are 120 seconds; each write window contains three Animal-name
changes in 30-second slots. Six quiet seconds separate window boundaries.
The helper/observer hashes are retained in the capture. No UI or transport
source change was applied during this run.

- All **24 idle windows** had zero data GETs and 216 received body bytes per
  client, including eight stream keepalives. Headers/TLS/TCP overhead is excluded.
- All **342 expected UI observations** matched the new synthetic name and had a
  changed decoded image region. No screenshot or response body is persisted.
- All twelve trials ended with **zero retained server streams**.
- There were **zero page errors**.
- All release frame-probe fields are `null`; there is no frame measurement in
  this release capture. `null` must not be interpreted as zero frames.

Derived [JSON](data/shared-care-integrated-sse-matrix-summary-2026-10-18.json)
and [tables](data/shared-care-integrated-sse-matrix-summary-2026-10-18.md) preserve
every repetition separately and now include both full Pi resource inputs.
The [resource and soak report](shared-care-integrated-resources-2026-10-18.md)
records coverage, overlap, process identity and the unresolved CPU intervals.

## Five-client update observations

| Repetition | Overview semantics p95 ms | Overview capture upper-bound p95 ms | Detail semantics p95 ms | Detail capture upper-bound p95 ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 876 | 1179 | 847 | 917 |
| 2 | 349 | 603 | 467 | 542 |
| 3 | 2277 | 2494 | 914 | 971 |

The third overview repetition does not establish the two-second bound. It is
retained, not removed or hidden by pooling repetitions. Capture completion is a
conservative upper bound after expected semantics and two animation callbacks;
neither value is a direct physical presentation timestamp. The resource report
and [supplementary frame measurements](shared-care-integrated-frames-2026-10-18.md)
are available; physical-device evidence is still needed
to distinguish server, client-rendering and controller-observation costs.

The first ten-client overview repetition had a 6,114 ms capture p95. This is also
retained as a scaling observation. The issue's two-second numerical target is
specified for five clients; this does not make the ten-client observation an
established production root cause or an accepted performance result.

## Terminal request events

The capture contains 299 terminal browser request events. Of those, 273 have
specific native-reader EOF/valid-body evidence and a matching-text application
JSON parse; 26 are `/api/v1/changes` control-query events excluded by this
observer revision. The latter remain unclassified. The
[observer limits](shared-care-integrated-acceptance.md#pi-preparation-follow-up-read-outcomes-and-cpu-boundaries)
also describe the distinction between response-specific read evidence and
matching primitive-string parse attribution. UI convergence does not by itself
classify each excluded control request, and no universal abort root cause is claimed.

## Follow-up check and process correction

The first automatic follow-up failed before login because the sandboxed process
was denied its LAN socket (`EACCES`). It did not start a measured workload. The
retry with the required process network access reached the real UI.

That retry exposed a test-helper assumption: navigation did not emit the
expected CDP terminal event for an old EventSource. The helper now requires the
actual server stream count to move **5 -> 4 -> 5** around each navigation, and
retires the old document's CDP bookkeeping only after observed server release.
It still requires a new SSE HTTP 200, an actual `changes` frame and the expected
Flutter page. Missing CDP terminal events are recorded, not treated as evidence
that the server released a stream.

The [corrected 120-second smoke](data/shared-care-integrated-reopen-smoke-2026-10-18.json)
completed six such reopen cycles across all five
clients, one successful write with five UI observations, zero page errors and
zero final server streams. Its short duration and six reopens do not satisfy the
30-minute/100-reconnect workload. The [full follow-up](data/shared-care-integrated-reopen-soak-2026-10-18.json)
completed 118 actual reopen cycles inside the fixed 30-minute window. Its
[resource analysis](shared-care-integrated-resources-2026-10-18.md) is separate
from ordinary idle/write workloads and physical outage recovery.

Chrome reported **155.0.8059.85** on the follow-up, after the matrix's browser
process had exited. Preserve that version difference in later comparisons;
the strict comparison helper must not silently describe the two as identical.
There is no evidence here that the browser update caused the matrix outlier.

## Remaining evidence

The matched polling capture, request-control diagnostics, the frame probe, physical lifecycle tests
and final ADR budgets/tolerances remain pending. Device inventory and short
smokes do not mark those criteria passed.
