# Integrated Shared Care acceptance — Issue #230

## Status and evidence boundary

Prepared against `195341013b6e58b020704e5c5ee395cfe4ed044e` (Issues #226–#229).
This runbook and the tooling are preparation, **not a Pi performance result**.
Issue #230 remains open until measurements and the physical-browser gates below
are recorded. The [earlier comparison](shared-care-sse-comparison-2026-10-18.md)
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
semantics timing, screenshot completion and optional Flutter frame CPU separate.
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
current web image before continuing SSE/lifecycle trials. Alternate mode order
and keep fixture dimensions, browser version, windows and write slots equal.

The original latency observation used one Feeding. New repeated trials use
Animal-name writes so overview and detail each have an unambiguous visible value.
Do not compare those different write workloads as if they were identical. If the
old web image is unavailable, reproduce it from its recorded source; do not
substitute laboratory HTML or call #229's conditional fallback the old baseline.

### Optional instrumented Flutter frame build

`tool/evaluation/shared_updates/flutter_probe.dart` starts the same production
app with a small binding that measures synchronous `drawFrame` CPU duration and
retains at most 10,000 durations per measurement window. It includes Flutter
build/layout/paint on the UI thread; it is **not** widget build count, GPU raster,
browser paint or physical presentation. The runner collects it when present;
ordinary production builds report `frames: null`, never zero fabricated frames.

Build this supplementary artifact separately:

```powershell
flutter build web --no-pub --target tool/evaluation/shared_updates/flutter_probe.dart --no-web-resources-cdn
```

Serve it only on the disposable gateway, retaining the production web artifact
for the main measurements. Record its separate identity and measure its overhead.
An idle heartbeat should produce no data GET or data-related frame; this needs
the recorded events and frame windows, not an inference from transport tests.

## 4. Remaining acceptance gates

These are intentionally not marked passed by the preparation tooling:

| Gate | Required evidence |
| --- | --- |
| Five-client performance | Per-trial p95 visible/captured update <=2s, >=90% fewer idle data GETs and >=80% fewer idle received bytes including upkeep, against the matched polling baseline |
| Warm CPU and RSS | Same-fixture Dart/Caddy idle CPU <=0.10/0.10% of one core, write CPU <=1.50/0.25%, sampled RSS <=256/80 MiB; investigate and document proposed-budget changes |
| Memory/connection soak | After warmup, fixed 30-minute workload and >=100 actual reconnects, initial/final warm ten-minute median RSS, investigate >10% growth; retained streams/queues bounded; separate login/setup costs |
| Physical desktop/mobile | Browser/device/version, trusted HTTPS, several tabs, background/foreground, outage/recovery, session expiry, successful/failed restore and retained drafts |
| Correctness | #229 deterministic recovery tests plus observed UI/command outcomes; no full-page reload used as normal invalidation |
| Rendering | Data-dependent Flutter frame measurements alongside real release UI network trials, clearly separate from semantics/capture timing |
| Evidence review | Request failures classified, process identity/coverage checked, sanitized reports and actual ADR budget/tolerance updates |

Plan the soak and physical-browser actions after the first capture has confirmed
the fixture, network accounting and UI selectors. A source ZIP, a successful
headless smoke, laboratory timings or a healthy container alone cannot close
Issue #230.
