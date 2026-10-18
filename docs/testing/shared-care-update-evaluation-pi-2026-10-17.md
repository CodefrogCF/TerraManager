# Shared Care updates: Raspberry Pi pilot, 2026-10-17

## Status

Completed: one fixed-order comparison of five transports, five logical Chrome
clients, idle and writes, plus independently collected target CPU/network samples.
Per-trial container RAM accounting is unavailable in this capture; a subsequent
operator-supplied process RSS/high-water snapshot supplements it. A subsequent real
Flutter overview/detail baseline and one cross-client update observation also completed.
The operator accepted SSE as the architectural direction on 2026-10-18.
Repeated/browser/lifecycle evidence and production acceptance remain outstanding.

Later repeated testing found retained SSE stream slots in the laboratory. The
[disconnect correction record](shared-care-sse-disconnect-correction-2026-10-18.md)
documents the failed run and correction. The browser observations below remain
exploratory evidence; resource comparisons need a fresh run with correct cleanup.

## Setup and provenance

- Raspberry Pi 5 Model B Rev 1.0, 4 GB model, Linux/aarch64, four CPUs.
- The resource file reports 4,146,880 KiB MemTotal and interface wlan0.
- Target and controller source HEAD: 8e684ec5b8388467672a4f42c5e5d366d28074c2.
- The recorded target working tree lists deployment bundles/backups and a deleted
  deploy/web-dist/.gitkeep; it lists no modified tracked application/lab source.
- Disposable lab image built successfully on the ARM64 target; Caddy 2.11.4 gateway.
- The lab Dockerfile uses dart:3.13.4. Runtime image digests were not captured.
- Controller: Windows, Node 23.9.0, Playwright 1.62.1, Chrome 155.0.8059.84.
- Trusted HTTPS on port 8443; automated Chrome navigation confirmed HTTP/2.
- Seed: 100 Animals, five Boxes, 2,000 Feedings; no pictures.
- Each transport: 120 seconds with six writes at 20-second cadence, followed in
  a separate phase by 120 seconds idle; five logical reader contexts per trial.
- Poll interval 15 seconds; long-poll timeout 25 seconds; stream heartbeat 15 seconds.
- Five write trials ran first, then five idle trials. No randomized order or repeats.
- All trials shared the warm lab. The runner deleted only the Feedings it created;
  account sessions and audit history remained. This is not a fresh-database trial.
- The production entry point, collection and Flutter implementation were not changed.

## Browser results

Measurement windows: 2026-10-17T20:48:25.063Z through 2026-10-17T21:09:06.611Z.

| Transport | Write p50 ms | Write p95 ms | Write data fetches | Observed / expected | Idle fetches | Idle lab DOM updates |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| polling | 6349 | 12732 | 120 | 30 / 30 | 120 | 40 |
| version-polling | 6519 | 12750 | 100 | 30 / 30 | 40 | 0 |
| long-polling | 140 | 164 | 90 | 30 / 30 | 20 | 0 |
| sse | 137 | 173 | 60 | 30 / 30 | 0 | 0 |
| websocket | 130 | 161 | 60 | 30 / 30 | 0 | 0 |

All ten trials completed without client errors or missing observations. The
runner created and successfully deleted 30 test Feedings. It observed all 150
expected changes. Read counts exclude login, writer/cleanup calls and initial
stream handshakes. Latency begins before the API write and ends at lab DOM
observation. The five contexts share one controller; this is not a physical
five-device measurement or a Flutter frame/rebuild measurement.

## Idle network observations

| Transport | Browser HTTP body counter B | WS payload B | Observed wlan0 RX+TX KiB/s | WLAN reduction vs polling | Counter span s |
| --- | ---: | ---: | ---: | ---: | ---: |
| polling | 4523400 | 0 | 43.274 | 0.000% | 114.665 |
| version-polling | 0 | 0 | 0.588 | 98.642% | 117.683 |
| long-polling | 0 | 0 | 0.433 | 98.999% | 115.692 |
| sse | 946 | 0 | 0.370 | 99.145% | 115.654 |
| websocket | 0 | 4600 | 0.461 | 98.935% | 117.683 |

Browser counters exclude HTTP headers, TLS/TCP overhead and outgoing traffic.
WLAN rates use first/last interface counters inside each measured window,
normalized by their actual observation span. They include unrelated host
traffic and must not be presented as bytes attributable solely to the lab.
Counter spans are shorter than the full 120-second browser windows.
Docker NetIO has human-readable rounding and includes internal gateway/backend
traffic. It was retained for diagnostics, not summed into LAN bandwidth.

## Pi resource sample quality

- 384 records from 2026-10-17T20:47:08.390939+00:00 to 2026-10-17T21:12:08.014172+00:00.
- Actual sample cadence: median 4.023 s, maximum gap 4.036 s.
- The configured two-second sleep occurs after Docker stats collection.
- Each browser window has 30 or 31 in-window resource samples.
- CPU percentages are intermittent samples; short bursts can be missed.
  Their means are not integrated CPU-time measurements. One pass cannot
  establish precise CPU savings or final per-transport budgets.
- Docker memory was 0B / 0B in every sample for both running containers.
  RAM is therefore unavailable, represented as null in the derived JSON.
- Both pre-run and post-run vcgencmd files contain throttled=0x0.

### Sampled idle CPU, percent of one logical CPU

| Transport | Dart sample mean % | Caddy sample mean % | Samples per component |
| --- | ---: | ---: | ---: |
| polling | 1.010 | 0.143 | 30 |
| version-polling | 0.040 | 0.055 | 31 |
| long-polling | 0.026 | 0.018 | 31 |
| sse | 0.031 | 0.015 | 30 |
| websocket | 0.042 | 0.025 | 31 |

### RAM follow-up: operator-supplied process snapshot

After the comparison, the operator supplied these read-only diagnostics:

- Docker: Cgroup=2, Driver=systemd, MemoryLimit=false.
- The running Dart process has four threads; Caddy has ten threads.

| Component / metric | Kernel-reported KiB | MiB |
| --- | ---: | ---: |
| Dart current VmRSS | 190192 | 185.734 |
| Dart lifetime VmHWM | 190192 | 185.734 |
| Caddy current VmRSS | 44816 | 43.766 |
| Caddy lifetime VmHWM | 48464 | 47.328 |
| Lab /tmp filesystem used | 2720 | 2.656 |

The lab tmpfs reports 524288 KiB capacity and 521568 KiB available.
Docker explicitly reports memory-limit support unavailable on this host.
This is consistent with its unusable memory statistics; no kernel-setting
change or reboot was made to collect the process snapshot.

VmRSS describes current process resident memory; VmHWM is a lifetime high-water
mark including startup. Neither can reconstruct per-trial container RAM.
Process RSS, lifetime high-water marks and tmpfs usage are separate metrics;
they must not be summed into a claimed exact container memory total. This
snapshot establishes the observed process footprint, not a transport-specific
RAM comparison or proof of memory stability over repeated reconnects.

## Real Flutter baseline on the Pi gateway

The operator switched only the isolated 8443 gateway to the existing
terramanager-web:8e684ec image, retaining the disposable API/SQLite backend.
The served version.json independently reported application version 1.15.4, build 91.
The image tag is operator-selected; an immutable image digest was not captured.
The runner authenticated five isolated Chrome contexts and navigated the real
German Flutter UI. All contexts used 1100 x 900 viewports, semantics enabled,
and the same synthetic fixture without media. Startup/login and view transitions
were outside the two 120-second idle windows. No Pi resource collector was
running during these later windows; the earlier resource samples do not apply.

| Actual Flutter view | HTTP-200 data GET responses, all clients | GETs per client | GETs/min/client | Encoded API body B | Decoded API body B |
| --- | ---: | --- | ---: | ---: | ---: |
| animals-overview | 120 | 24, 24, 24, 24, 24 | 12.00 | 4,519,080 | 4,519,080 |
| animal-detail | 400 | 80, 80, 80, 80, 80 | 39.97 | 8,772,480 | 8,772,480 |

All observed API response statuses were HTTP 200; the response-event counts
matched the Resource Timing entry counts. No JavaScript page errors were
observed. All clients reported visible/focused at the start and end of each
window, with HTTP/2 resource entries. Lower-level browser failure events were
also observed and are reported separately below; HTTP 200 alone does not prove
an error-free response-body lifecycle.

Per-client request rates use each client's measured window duration. Body sizes
are same-origin browser Resource Timing counters; they exclude startup assets,
HTTP overhead, TLS/TCP and outgoing traffic. They are not full LAN bandwidth.
Visibility/focus snapshots and polling counts establish this foreground run;
they do not establish background/resume or physical multi-device behavior.

### Actual API routes observed

| View | GET route | Responses, all clients |
| --- | --- | ---: |
| animals-overview | `/api/v1/animals` | 40 |
| animals-overview | `/api/v1/boxes` | 40 |
| animals-overview | `/api/v1/reminders` | 40 |
| animal-detail | `/api/v1/animals` | 80 |
| animal-detail | `/api/v1/animals/:id` | 40 |
| animal-detail | `/api/v1/animals/:id/feedings` | 40 |
| animal-detail | `/api/v1/animals/:id/pictures` | 40 |
| animal-detail | `/api/v1/animals/:id/shedding` | 40 |
| animal-detail | `/api/v1/animals/:id/weights` | 40 |
| animal-detail | `/api/v1/boxes` | 80 |
| animal-detail | `/api/v1/reminders` | 40 |

The measured detail rate is 40 GETs/min/client, above the earlier 36-read
source/model estimate. Each 15-second detail refresh also requests the picture
list, even though this fixture has no pictures. Source inspection suggests
the detail FutureBuilder temporarily replaces its subtree while changing the
record future, recreating SharedPictureGallery and its initial list read.
This lifecycle explanation is an inference from source and matching traffic,
not a measured Flutter rebuild count. The existing laboratory detail-stack
model omits that extra gallery lookup; its 36-read budget must not be used as
the measured real-client baseline. The earlier five-transport comparison used
the overview workload and is unaffected by this detail-model difference.

### Browser abort and navigation diagnostics

- Initial five-client windows emitted 61 overview and 107 detail requestfailed events.
- That first capture counted these events without retaining their error types.
- A subsequent read-only one-client run measured each view for 30 seconds.
  - animals-overview: 6 HTTP-200 responses; 3 net::ERR_ABORTED events after HTTP 200.
  - animal-detail: 20 HTTP-200 responses; 6 net::ERR_ABORTED events after HTTP 200.
- The control run recorded one main-document request and one navigation timing
  entry throughout. Flutter route changes also emit framenavigated; their raw
  count must not be interpreted as full page reloads.

The short diagnostic reproduces post-header cancellation events, but does
not retrospectively classify every event from the longer capture or prove
their root cause. No zero-network-error claim is made. The five-client UI
change observation below establishes that all five consumed that update.
Future acceptance runs should retain error types and distinguish body
cancellation, actual connection failures and application-visible errors.


### One cross-client Flutter update observation

After the idle windows, a separate control session created one synthetic Feeding
for Animal 1 (HTTP 201). A browser MutationObserver watched the real Flutter
Last Feeding semantics change in all five detail views.

- Write start UTC: 2026-10-17T21:57:43.937Z.
- Write-start to changed Flutter semantics, client order: 11961 ms, 12271 ms, 12580 ms, 12881 ms, 13153 ms.
- All five observed the change; the created Feeding was deleted successfully (HTTP 200).

This is one write and five correlated observations at different polling phases.
It is not a latency distribution, paint timestamp or Flutter frame/rebuild count.
The observation does not test production SSE, replay, missed-change recovery,
offline edits, session expiry or browser background/resume.

Measurement windows: 2026-10-17T21:53:40.646Z to 2026-10-17T21:55:40.672Z; 2026-10-17T21:55:43.700Z to 2026-10-17T21:57:43.725Z.

Sanitized baseline JSON SHA-256: `898b1674c3b9076c8a2da3063f6b24ed6598da501d699034a6905e8fedce2d14`.

Sanitized control JSON SHA-256: `c9f74ce99c758e329f40d3940cfeae2fedcf52b9cfd83ad89d91db9d3e6a0783`.

Reproducible measurements: [sanitized baseline JSON](data/shared-care-flutter-baseline-2026-10-17.json) and [sanitized control JSON](data/shared-care-flutter-diagnostic-2026-10-17.json).

## Provisional assessment and completion gates

The pilot supports the selected SSE invalidation path with targeted HTTP reads
and conditional/version polling fallback. Long polling, SSE and WebSockets all
provided low lab update latency in this run. Differences between their p95
values are too small to rank them from one fixed-order pass.

SSE and WebSockets eliminated idle data fetches within the measured sections.
Version polling reduced idle fetches by two thirds at the existing interval;
its fallback request budget is separate from the connected-SSE target.

The real Flutter run measured 12 overview and 40 detail-stack data GETs/min/client;
the extra gallery lookup was missing from the earlier 36-read model. Post-header
browser cancellation diagnostics remain explicitly qualified above.
The corrected 2026-10-18 run subsequently completed three repetitions with
per-trial process memory/CPU; see the [complete repeated comparison](shared-care-sse-comparison-2026-10-18.md).
That run replaces the resource comparison affected by orphaned SSE slots; it
does not rewrite this exploratory pilot. Physical-browser/lifecycle/scale and
long-term memory acceptance remain follow-up validation. Production commit hooks,
full mutation coverage, reconnect/replay/fallback, permission filtering and restore
behavior remain the [five implementation issue scopes](shared-care-sse-implementation-issues.md).

## References

- [Evaluation runbook](shared-care-update-evaluation.md)
- [ADR-037](../architecture-decisions.md#adr-037-evaluate-versioned-shared-care-invalidation-and-sse-delivery)
- [Docker stats](https://docs.docker.com/reference/cli/docker/container/stats/)
- [Docker runtime metrics](https://docs.docker.com/engine/containers/runmetrics/)
