# Integrated Shared Care acceptance — Issue #230

## Status and evidence boundary

Originally prepared against `195341013b6e58b020704e5c5ee395cfe4ed044e`
(Issues #226–#229). The integrated captures use the recorded `2dee1f1` images.
The [matched production-UI measurements](shared-care-integrated-matched-2026-10-19.md),
[resource/soak evidence](shared-care-integrated-resources-2026-10-18.md) and
[supplementary frame probe](shared-care-integrated-frames-2026-10-18.md) now
record actual outcomes separately from this procedure. The [final acceptance
report](shared-care-integrated-acceptance-2026-10-21.md) records completed validation
on 2026-10-21, including natural expiry, renewed login and automatic updates. Resource budgets were explicitly accepted
by the operator and recorded in the ADR on 2026-10-19. The [physical report](shared-care-integrated-physical-checks.md)
now records the operator-confirmed functional cases, including revocation,
rejected/successful restore and the natural twelve-hour expiry/relogin check. S22 Firefox is explicitly excluded from trusted-HTTPS
acceptance by the operator; four other clients were reported warning-free.
The [CPU-resolution report](shared-care-integrated-cpu-resolution-2026-10-19.md)
retains one inconclusive ten-client window against the original 0.25% limit and
records the separately accepted 0.30% ten-client Caddy budget. Original
measurement values and classifications remain unchanged.
The [German operator checklist](shared-care-integrated-operator-checks-de.md)
prepares those physical checks without claiming unobserved outcomes.
The [earlier comparison](shared-care-sse-comparison-2026-10-18.md)
and [real Flutter baseline](shared-care-update-evaluation-pi-2026-10-17.md)
remain reference evidence with their original limits.

The [local tool validation](shared-care-integrated-tool-validation-2026-10-18.md)
records which preparation checks passed and the exact delivery paths.

The integrated fixture wraps the current `SharedServerApi`, including its real
change queries, transactions, authentication, role checks, SSE handler and
recovery protocol. It does not use the laboratory change feed. The gateway serves
the installed production Flutter web image. The fixture contains 100 synthetic
Animals, five Boxes and 2,000 Feeding records, matching the earlier fixture.
Three caregiver accounts distribute up to ten clients within the production
eight-stream per-account limit. The controller has a separate administrator.
The API's total limit of 32 and per-account limit of eight stay unchanged.
The measured Dart AOT process includes the fixture bootstrap and diagnostic route
counters; it is not the minimal production container entry binary. Keep that
identity and diagnostic overhead in the resource interpretation. The paired
polling/SSE comparison uses the same wrapper and data.

The temporary database, account store and random credentials live only in the
fixture container's `/tmp`. Recreating the container resets them. Nothing mounts
`deploy/data`. Port 443 and the production stack remain in operation. The old
disposable #186 stack is stopped to release port 8443 and reduce idle interference.

## 1. Start the integrated fixture on the Pi

Apply the source ZIP at the repository root, then run:

```bash
cd ~/TerraManager
bash tool/evaluation/shared_updates/prepare_integrated_pi.sh
```

The script first builds the new ARM64 fixture image, then stops only the old
`tm186-evaluation` services and starts `tm230-acceptance`. It reuses the existing
web image identified from the running production Compose service and the trusted
LAN certificate. `TM230_WEB_IMAGE` can explicitly select a different identified
local `terramanager-web:*` image for a comparison. Record both API source and web
image identity; a new tools-only commit does not require rebuilding the unchanged
production web app. A successful image build is not browser or performance acceptance.

The final output includes the new private credentials path:
`$HOME/tm230-private/credentials.json`. Transfer this file privately to the local
controller; do not paste it into chat, commit it or upload it to GitHub. The
capture verifies its random fixture ID against an authenticated read-only
identity endpoint before any synthetic command. An old credentials file is
rejected. Copy again whenever the fixture container is recreated.

Open `https://192.168.1.117:8443` and verify trusted HTTPS. Accept neither a browser
certificate warning nor a global TLS bypass as trusted-HTTPS evidence.

## 2. Start process capture on the Pi

```bash
cd ~/TerraManager
bash tool/evaluation/shared_updates/start_integrated_capture.sh
```

The existing resource collector checks both PID 1 processes before starting a
three-hour capture at five-second intervals. This deliberately uses `/proc` RSS
and cumulative CPU ticks because this Pi reports `MemoryLimit=false`. Capture
the printed directory and PID. To stop this collector later, use its recorded
PID; do not kill unrelated Python processes.

Keep the generated image identities, source hashes, preflight and resource JSONL
together. CPU comparisons require identical process start ticks and clock tick
frequency; do not bridge a container restart. Record sample coverage, probe
duration and skipped slots. Docker memory values that are unavailable stay
unavailable. `VmHWM` is lifetime-wide; sampled RSS does not prove instantaneous
peak or container/tmpfs memory. Keep the Dart and Caddy series separate.
Use a fresh capture for each mode/matrix and for the soak, allowing the previous
collector to finish or verifying its command before stopping it. Three hours do
not cover both full matrices plus the soak; missing resource intervals are not
valid zero-load samples.

## 3. First real Flutter smoke, then repeated trials

The desktop controller requires Node and Playwright with installed Chrome/Edge.
Use the same dependency setup as the earlier evaluation. No dependency or new
permission is added to the app. Browser trust and Node's request-context trust
are separate: supply the existing **public** LAN root CA with
`NODE_EXTRA_CA_CERTS` when Node does not use the Windows certificate store. Never
use the server private key or a TLS-verification bypass. The initial smoke is
deliberately short:

```powershell
$env:NODE_EXTRA_CA_CERTS='C:/private/terramanager-lan-root-ca.pem'
node tool/evaluation/shared_updates/integrated_benchmark.cjs `
  --credentials C:/private/tm230-credentials.json `
  --output C:/private/tm230-smoke.json `
  --clients 1 --repetitions 1 --seconds 30 --writes 1 --channel chrome
```

It covers idle and write windows in the Animals overview and Animal details.
Setup/login and route settlement are outside the measurement windows. A write
updates the synthetic Animal's name, respecting its optimistic revision. Each
write occupies a fixed 30-second slot in either transport mode. The report keeps
semantics timing, screenshot completion and optional Flutter frame elapsed time separate.
It retains no screenshots, original names, bodies, credentials, cookies, cursor
or HAR. Capture aborts are retained, including unavailable body evidence.

After reviewing the smoke, repeat the matrix:

```powershell
node tool/evaluation/shared_updates/integrated_benchmark.cjs `
  --credentials C:/private/tm230-credentials.json `
  --output C:/private/tm230-sse-matrix.json `
  --clients 1,3,5,10 --repetitions 3 --seconds 120 --writes 3 --channel chrome
```

With two idle windows of 120 seconds and two write windows of 90 seconds per
trial, the 12 trials take roughly 90 minutes including setup. Do not shorten the
reported windows to hide initial recovery or idle upkeep. Repeat selected
five-client trials with `--channel msedge --contexts 3` to include several tabs
sharing contexts. Headless logical tabs remain **different evidence** from
physical desktop/mobile browser lifecycle tests.

Each trial reports p50/p95, not a pooled cross-trial percentile. Clients observing
the same command are correlated; the three repetitions are the independent
units. Main captures use the unmodified release Flutter UI. CDP live body bytes
include stream upkeep, fallback and resync but exclude headers and TLS/TCP
overhead. A separate host/network measurement is required for full wire bandwidth.
An event without corresponding observed live body bytes invalidates byte coverage.
Compare `bytes.decodedBody` for body-byte reductions. Chrome's
`bytes.cdpEncodedChunk` counter can be zero during a live stream even when bytes
are delivered; it is diagnostic only and must not be used as total wire traffic.

Screenshot completion is a conservative upper bound following matching semantics
and two animation callbacks; a changed data-region image supports rendered output.
It is not the first physical presentation timestamp. A no-change screenshot or a
terminal request failure without an established application outcome must be
investigated. Do not reclassify all `ERR_ABORTED` events as harmless based on the
earlier independent no-store control.

### Polling comparison

The recorded 2026-10-17 baseline remains useful for the five-client idle network
comparison, with 12/40 data GETs per minute/client in overview/detail. It does not
provide the newly requested repeated 1/3/5/10-client matched workloads.

For the repeated comparison, serve the recorded pre-SSE production Flutter web
image on the same isolated gateway and the same current synthetic API fixture,
then run the identical helper with `--mode polling`. Verify and record that
image's identity and source revision first; do not merely label a current SSE
client as polling. The runner rejects an SSE stream in polling mode. Restore the
current web image before continuing SSE/lifecycle trials. Keep fixture
dimensions, browser version, windows and write slots equal. Record mode order;
alternating it is preferred. A complete SSE matrix followed by a complete
polling matrix is a batched comparison with a time/order confound. Report that
limitation and include a five-client SSE check after restoring the current image.
Do not infer a causal RAM saving from two successively warmed process states.

The `switch_integrated_web.sh` helper accepts the intended mode, an explicitly
identified local web-image reference and its expected immutable image ID. It
checks the live disposable lab/project and image architecture, changes only the
gateway with `--no-deps --no-build --pull never`, and verifies that the lab
container and start time stayed identical. Its private JSON record contains no
credentials. Run it only after the previous browser capture has finished; the
subsequent runner must still verify actual SSE presence/absence. Start a new Pi
resource capture for the next mode. A recreated gateway has a new process
identity, so its CPU counters must not be bridged across the switch.

When running a separately copied helper, explicitly set `TM230_CHECKOUT_ROOT`
to the intended Pi checkout. `TM230_PREVIOUS_CAPTURE_DIR` can name the previous
private run directory. The helper validates the recorded sampler PID, owner,
script, output path and both disposable container arguments before SIGTERM;
an unrelated process is not stopped. This avoids running two resource collectors
through the next mode. The old JSONL remains available for final copying.

For completed captures made with the identical helper/diagnostics revision, run:

```bash
python3 tool/evaluation/shared_updates/compare_integrated.py sse.json polling.json \
  --output-prefix matched-comparison
```

The comparison rejects mismatched tool hashes, browser versions, plan or tab
grouping, incomplete trials and retained streams. It keeps every repetition
separate, normalizes idle byte/GET rates by measured time, and recomputes each
write-window p95 from its observations. A slow repetition cannot disappear in
a pooled percentile. Numerical five-client targets and unresolved request/page
evidence have separate fields; passing the numbers does not close the issue.

The original latency observation used one Feeding. New repeated trials use
Animal-name writes so overview and detail each have an unambiguous visible value.
Do not compare those different write workloads as if they were identical. If the
old web image is unavailable, reproduce it from its recorded source; do not
substitute laboratory HTML or call #229's conditional fallback the old baseline.

### Optional instrumented Flutter frame build

`tool/evaluation/shared_updates/flutter_probe.dart` starts the same production
app with a small binding that measures synchronous `drawFrame` elapsed time and
retains at most 10,000 durations per measurement window. It includes Flutter
build/layout/paint on the UI thread; it is **not** widget build count, GPU raster,
browser paint or physical presentation. `Stopwatch` also includes scheduling
and preemption; it is not an operating-system thread CPU counter. The new field
is `frameElapsedMicroseconds`. Historical tool captures retain the older
`frameCpuMicroseconds`/`drawFrame-CPU` labels, and the frozen release runner still
uses the old wording in one limit string. Interpret those as elapsed time too;
their raw evidence is preserved. The runner collects the probe when present;
ordinary production builds report `frames: null`, never zero fabricated frames.

Build this supplementary artifact separately:

```powershell
flutter build web --no-pub --target tool/evaluation/shared_updates/flutter_probe.dart --no-web-resources-cdn
```

Serve it only on the disposable gateway, retaining the production web artifact
for the main measurements. Record its separate identity and measure its overhead.
An idle heartbeat should produce no data GET or data-related frame; this needs
the recorded events and frame windows, not an inference from transport tests.

## 4. Acceptance gates and required evidence

The preparation tooling does not mark these passed. Completed outcomes are
recorded in the final acceptance report linked above:

| Gate | Required evidence |
| --- | --- |
| Five-client performance | Per-trial p95 visible/captured update <=2s, >=90% fewer idle data GETs and >=80% fewer idle received bytes including upkeep, against the matched polling baseline |
| Warm CPU and RSS | Accepted 2026-10-19 for the recorded fixture/workloads: Dart/Caddy idle CPU <=0.10/0.10% of one core; write CPU <=1.50/0.25% at 1/3/5 clients and <=1.50/0.30% at ten clients; sampled RSS <=256/80 MiB. Original assessments remain unchanged. |
| Memory/connection soak | After warmup, fixed 30-minute workload and >=100 actual reconnects, initial/final warm ten-minute median RSS, investigate >10% growth; retained streams/queues bounded; separate login/setup costs |
| Physical desktop/mobile | Browser/device/version, trusted HTTPS, several tabs, background/foreground, outage/recovery, session expiry, successful/failed restore and retained drafts |
| Correctness | #229 deterministic recovery tests plus observed UI/command outcomes; no full-page reload used as normal invalidation |
| Rendering | Data-dependent Flutter frame measurements alongside real release UI network trials, clearly separate from semantics/capture timing |
| Evidence review | Request failures classified, process identity/coverage checked, sanitized reports and actual ADR budget/tolerance updates |

Plan the soak and physical-browser actions after the first capture has confirmed
the fixture, network accounting and UI selectors. A source ZIP, a successful
headless smoke, laboratory timings or a healthy container alone cannot close
Issue #230.

## Pi preparation follow-up: read outcomes and CPU boundaries

The [first integrated Pi captures](shared-care-integrated-pi-smoke-2026-10-18.md)
confirm the real UI workload and show why terminal browser events and partial
CPU spans need explicit interpretation. They do not close the wider matrix.

For the repeated capture, use `--diagnostics reads` in addition to the earlier
arguments. The optional observer keeps the native Response/stream/reader/chunk
objects, read calls and cache policy. It observes EOF, bounded transient body
validation and the application's actual `JSON.parse` consumption. It neither
clones nor tees responses and performs no additional body reads. Only metadata
is persisted, with at most 4,096 records and eight retained unmatched body texts
of at most 512 KiB each per page. The frozen full-matrix revision excluded auth,
media and all `/api/v1/changes*` bodies, including JSON queries. Its 26 control
terminal events remain unclassified. The follow-up revision also observes JSON
`/api/v1/changes` reads; auth, media and the unbounded SSE endpoint remain
excluded. Query strings/cursors are not retained. New evidence does not
retroactively establish consumption of an earlier excluded response.

The application parse hook matches completed response text by value. It does
not carry a request identity through JavaScript primitive strings; identical
outstanding response texts can make parse attribution ambiguous. Native reader
EOF/byte/error evidence belongs to the specific response. Keep that distinction
when interpreting the additional matching-parse flag and the final UI outcome.

### Pinned browser and supplementary native timing

The controller browser updated from Chrome .84 to .85 after the full matrix.
Follow-up runs use an isolated .85 installation copy with a file-hash manifest;
the system browser is not replaced. `--executable ABSOLUTE_PATH` selects that
copy and records the launcher hash plus runtime version. Compare the bundle
manifest as well: a launcher alone does not identify every browser binary.

`--latency-observer native` additionally records expected Flutter semantics text
at its in-document mutation, then two animation callbacks. It recognizes both
single labels and merged overview rows (Animal name followed by other lines),
rejects mere name prefixes, and checks initial recognition before each measured
view. It stores timestamps, not label text. Remote locator completion, native
semantics, animation callbacks and screenshot completion remain separate;
none is a physical display timestamp. This observer adds work and must have
the same revision/mode in compared follow-up runs.

The first supplementary probe had valid frame evidence but missed the native
overview timestamp because the helper expected a standalone name. The
supervisor stopped before release trials/switching. A read-only real-UI check
identified the merged text; a browser regression test now covers that shape.
The original capture is retained; its missing field is not converted to zero.

`--probe-root ABSOLUTE_BUILD_DIRECTORY` fulfills only static assets from a local
instrumented Flutter build, with explicit hashes and no-store. API/evaluation
requests still use the trusted Pi gateway. Path traversal and symlink escapes
are rejected. Missing probe metrics fail the run. Such captures are marked
supplementary and rejected as release-comparison inputs; they cannot substitute
for the unchanged gateway release artifact. Missing production frame data stays
`null`, while an instrumented empty sample list establishes zero observed frames.

The strict comparison also checks selected browser executable and artifact kind.
An explicit `--clients 5` permits a matched subset from otherwise equal plans;
the output still reports `requiredMatrixComplete: false`. This is useful for
the .85 target check without pretending the old .84 matrix is byte-identical.

The [completed pinned comparison](shared-care-integrated-matched-2026-10-19.md)
records that subset, the full polling matrix and the remaining .85 SSE scales
in a second raw capture. `combine_integrated.py first.json next.json
--output combined.json` composes disjoint completed trial sets for the strict
comparator. It rejects changed browser/tool/workload provenance, incomplete
declared matrices, duplicate trials and nested compositions. The output retains
each trial unchanged and records each source hash, original plan and time span.
Its union client plan is an enumeration, not a global execution-order claim;
the raw inputs and actual image-switch order remain part of the evidence.

The matched .85 matrix is complete. Its three 90-second ten-client detail-write
Caddy CPU intervals remain inconclusive against the proposed 0.25% of one core.
The separate resolution follow-up keeps ten clients, three repetitions, the
same executable/modules and the 30-second write spacing, and uses six writes
per view (180-second active windows). Its 30-second idle windows are setup,
not substitutes for the primary 120-second idle acceptance windows. Analyze
this follow-up separately; do not merge its different plan into the matched
matrix or relabel the original intervals. This reduces endpoint/tick uncertainty
without idle padding or a higher CPU threshold. Final CPU acceptance and any
minimum-window definition must be recorded explicitly in the ADR after review.
The [completed result](shared-care-integrated-cpu-resolution-2026-10-19.md)
does not confirm 0.25% in every repetition: five of six Caddy active windows
are within, one is inconclusive. The operator accepted the separate
scale-specific Caddy limit of 0.30% at ten clients on 2026-10-19. All compared
upper bounds fit the accepted resource budgets. Original statuses remain
unchanged. The separate natural physical-session expiry, renewed login and
automatic-update outcome was confirmed by the operator on 2026-10-21.

The observer adds promise continuations and text decoding on the controller;
record this mode in comparisons. It is not a zero-overhead measurement. Use the
same mode on both sides of the matched network comparison. `--diagnostics off`
retains the earlier behavior and unresolved body evidence when unavailable.
Never apply one request's successful consumption to a different abort event.

Each trial now records authenticated clock-offset probes before and after it.
Each window is followed by six quiet seconds so a five-second resource probe
can finish before the next workload. Setup and these quiet boundaries remain
outside the measured windows, while all in-window fallback/resync/upkeep remains
included. The output records the exact plan and controller tool hashes.

Analyze a capture and its Pi resource snapshot with:

```bash
python3 tool/evaluation/shared_updates/analyze_integrated.py capture.json \
  --resources pi-resources.jsonl --output-prefix integrated-summary
```

The analyzer reports whole-window CPU lower/upper bounds. The lower bound uses
counter endpoints fully inside the window; the upper bound uses endpoints that
surround it, including clock offset, probe-duration uncertainty, a default 100 ms
guard and two ticks of user/system counter rounding. A zero inner counter span
does not establish zero whole-window CPU: it may miss a write at the start.
Missing surrounding probes, process restarts and regressed counters stay
unavailable. An inconclusive proposed budget is reported as inconclusive.
RSS remains sampled memory, with sample counts, probe span/gaps and process
identities; it is not a continuous peak-memory guarantee.

If a collector was extended by starting a second capture, repeat `--resources`
with both files. Host/tick metadata must match. The analyzer takes the union of
observations, deduplicates exact copies and records each input hash and overlap;
it never adds absolute CPU/network counters. Process restarts remain explicit.
For a polling baseline, the SSE budgets are reference values rather than a
polling acceptance requirement.

### Supplementary tab-reopen memory workload

`integrated_reopen_soak.cjs` prepares a separate server-resource stress workload:
five real Flutter overview clients retain their existing signed-in contexts,
warm up for two minutes, then one tab deliberately navigates away and returns
every 15 seconds during a fixed 30-minute period. Synthetic Animal-name writes
run approximately once a minute; the other pages must reflect them without
reloads. Each counted reopen requires an actual new SSE HTTP 200 response and
an observed `changes` frame, followed by the expected Flutter semantics. Initial
connections do not count toward the 100-reopen threshold. Final stream drain is
recorded outside the workload window.

This is **tab startup/reopen stress**, including startup reads. It is not an
outage/backoff or foreground-recovery test, and page navigation is not the
normal invalidation mechanism. Those client-policy checks remain separate.
The helper has no special production endpoint or simulated SSE event. It
refuses a non-matching disposable fixture before commands. Main idle/write
network results are not mixed with this heavier workload.

First run a short smoke after all primary automatic captures have stopped:

```powershell
node tool/evaluation/shared_updates/integrated_reopen_soak.cjs `
  --credentials C:/private/tm230-credentials.json `
  --output C:/private/tm230-reopen-smoke.json --seconds 120 --warmup 0
```

The duration and reconnect thresholds must remain false for that smoke.
Only after confirming real stream release/reopen, UI writes and a zero final
stream count, run the default `--seconds 1800 --warmup 120`. Record skipped
slots, actual in-window connections, any overrun, source hashes and the full Pi
resource span. A workload threshold alone is not memory acceptance: compare
initial/final warm ten-minute median RSS for each stable Dart/Caddy identity,
investigate growth above 10%, and retain the separate queue-bound evidence.
This helper is preparation until its real browser/Pi captures are recorded.

The [completed matrix and follow-up notes](shared-care-integrated-sse-matrix-2026-10-18.md)
record the first actual reopen smoke and two corrected assumptions: the process
needs LAN access, and Chrome navigation can omit an old stream's CDP terminal
event. The helper therefore verifies server stream counts 5 -> 4 -> 5 before
retiring old document bookkeeping. A new response/frame/UI check still proves
each counted reopen. This smoke does not establish the long-term memory gate.

Use `analyze_integrated_soak.py soak.json --resources pi-resources.jsonl
--output soak-summary.json` to derive the separate memory observations. Both
ten-minute windows need dense valid RSS coverage and one stable process
identity. Missing final coverage, a restart or absent before/after clock probes
keeps the growth assessment unavailable. Only reconnects completed inside the
fixed window count. The default clock/probe guards and rounding-aware CPU
bounds are retained; ordinary idle/write CPU budgets do not apply to this
repeated-startup workload.
