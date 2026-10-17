# Shared Care update evaluation: local checkpoint 2026-10-17

## Scope and source

Issue #186, source revision 5c5d2731d1bcee3c0faf9c3c7d7b2ca2c7589f54 (version 1.15.4+91).
Implementation and validation used an isolated archive/overlay copy. The primary
checkout is preserved. This checkpoint delivers the evaluation tooling, proposed
ADR-037 and four focused follow-up drafts. Production polling remains unchanged.

The ADR remains Proposed. Raspberry Pi CPU/RAM/bandwidth, trusted Caddy runtime,
the actual Flutter client and the agreed multi-browser/device matrix have not
been measured here. Issue #186 cannot be accepted as complete from this checkpoint.

## Executed checks

- Flutter 3.47.2 / bundled Dart 3.13.2; Python 3.12; Node 23.9.0;
  externally supplied Playwright 1.62.1 and installed Chrome 155.0.8059.84.
- Flutter pub get passed with process-local FLUTTER_WINDOWS=false; the initial
  Windows symlink attempt was resolved without changing the primary checkout
  or system Developer Mode. Pub/Gradle dependency locks are unchanged.
- Whole-project flutter analyze --no-pub: no issues found.
- Dart formatting: 532 files, zero changes in the whole-project format check;
  subsequent changed Dart files were formatted again.
- 23 focused Dart/Flutter tests passed: evaluation feed/HTTP/streams, existing
  production authentication/roles/CSRF and public-documentation contracts.
- Four Python unit tests passed, including HAR redaction, unknown body sizes and
  explicit observation-window rate calculation. Python compilation and both
  JavaScript syntax checks passed.
- Independent AOT CLI build passed, including native SQLite assets. A compiled
  miniature fixture smoke passed authentication and anonymous-access denial;
  the final build also ran the complete browser matrix below.
- Both base and real-Flutter gateway override passed docker compose config.
  Docker runtime/ARM64 image building and Caddy TLS were not executed locally:
  the local Docker engine was not running.
- The resource collector ran locally without Docker as a metadata/output smoke;
  this is not a Pi or container-resource result.

## Local browser transport checks

Environment: Windows x64 controller and native Windows AOT lab server, loopback
HTTP/1.1, 5 synthetic Boxes, 100 Animals, 2,000 seeded Feedings, no media.
Three separate Chrome contexts model API workloads, not physical devices.

The normal 15,000 ms polling interval was retained. Each write case ran 40 seconds
and created two real API Feedings. Each idle case ran 35 seconds without writes.
Warm-up/login/initial snapshots are excluded; request starts can therefore differ
from response completions for an already pending long poll.

All cases completed without HTTP/workload errors or missing expected write
observations. Writes yielded 30 observations across the five modes and three
clients. Created Feedings were removed through the authenticated API between
modes; audit/session history remains, so these ordered smoke cases are not
identical cold database images. Acceptance trials must restart/randomize as
documented in the runbook. A separate eight-second, one-context SSE detail-stack smoke also passed
with accelerated polling parameters; it is a correctness check, not a performance
result.

### Writes

| Mode | Fetch starts | Encoded HTTP body bytes | WS payload bytes | Lab DOM updates | Write-start to DOM p95 ms |
|---|---:|---:|---:|---:|---:|
| polling | 18 | 678026 | 0 | 6 | 12557 |
| version-polling | 18 | 667187 | 0 | 6 | 12790 |
| long-polling | 18 | 667180 | 0 | 6 | 171 |
| sse | 12 | 667562 | 0 | 6 | 153 |
| websocket | 12 | 666068 | 1740 | 6 | 103 |

### Idle

| Mode | Fetch starts | Encoded HTTP body bytes | WS payload bytes | Lab DOM updates | Write-start to DOM p95 ms |
|---|---:|---:|---:|---:|---:|
| polling | 18 | 678040 | 0 | 6 | - |
| version-polling | 6 | 0 | 0 | 0 | - |
| long-polling | 3 | 0 | 0 | 0 | - |
| sse | 0 | 102 | 0 | 0 | - |
| websocket | 0 | 0 | 690 | 0 | - |

## Interpretation and measurement limits

These are short functional/prototype runs, with six write observations per
mode. Their p95 values are not statistically robust Pi performance evidence.
The write-start-to-lab-DOM clock includes client coordination, the write request,
server work, delivery/poll wait, refresh and rendering. It is not a direct
database-commit timestamp or real Flutter frame latency.

Fetch starts include version queries; initial stream handshakes are warm-up.
Encoded HTTP body bytes include ongoing SSE data as observed by Chromium CDP.
They exclude request/response headers, TLS/TCP and outgoing traffic. WebSocket
payload bytes are separate and exclude frame overhead. Zero conditional-response
body bytes are not zero network traffic. SSE uses comment heartbeats; the WS
prototype uses JSON state heartbeats, so payload choices must be considered
before attributing a byte difference to the underlying transport.

Lab DOM updates are not Flutter rebuild counts. The source-derived nominal
baseline is 12 overview data GETs/minute/client and up to 36 for the modeled
Animal-detail stack. Actual Flutter HAR/frame and physical multi-client runs
remain required. The HAR summarizer requires an explicit known capture duration
for rates; the first-to-last-request span is diagnostic only.

## Delivered design and next gates

The lab uses the real SharedServerApi, session cookies, origin checks, existing
CSRF/role/conflict rules and server-owned SQLite data on fresh private scratch
storage. No production endpoint, app permission, cloud service, Pub dependency
or production deployment configuration is changed.

The laboratory feed observes completed successful Feeding POSTs, after commit
and response delivery. It does not implement the future transactional publisher
or all mutation routes. Its bounded replay/reset, authenticated streams and
conditional HTTP support are comparison prototypes. Production lifecycle,
snapshot consistency, slow-consumer bounds, revoke deadlines, polling fallback,
local due-time transitions and restore reset remain explicit follow-up scope.

The optional gateway override serves the existing real Shared Care Web image
against this disposable API so the next Pi step can capture real Flutter traffic
without mounting production collection/account data. Both gateway modes need
runtime validation on the actual trusted HTTPS deployment.

Follow the runbook to collect the real Pi/current-Flutter baseline, compare
shortlisted candidates with repeated samples, set CPU/RAM budgets, finalize
ADR-037 and turn the copyable drafts into implementation issues. No GitHub issue,
comment, push or deployment was performed by this delivery.
