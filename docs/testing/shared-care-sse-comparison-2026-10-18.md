# Repeated polling/SSE evaluation on Raspberry Pi, 2026-10-18

## Status and decision

Twelve overview windows completed: five logical Chrome clients, 120 seconds per
window, idle and writes, polling and SSE, three repetitions with alternating order.
The matching Pi resource capture is complete and aligned with every window.
These results support ADR-037: committed revisions, targeted HTTP refresh, SSE
notifications and conditional/version polling fallback.

The comparison uses the real API/SQLite lab and a simple laboratory DOM, not the
production synchronization implementation or Flutter frame timing. Physical
browser, lifecycle and scale acceptance remains implementation follow-up work.

## Setup and provenance

- Raspberry Pi 5 Model B Rev 1.0, 4 GB RAM, ARM64; interface wlan0.
- Chrome 155.0.8059.84; five isolated contexts on one Windows controller.
- Disposable HTTPS gateway on port 8443; trusted TLS, Caddy 2.11.4-alpine.
- Fixture: 100 Animals, 5 Boxes, 2000 Feedings, no pictures.
- Source HEAD: `df1eb51135acfa9bee0b56ff5eb9a7e940efbc45`; all five captured Pi/controller source hashes match.
- Browser windows: 2026-10-18T07:32:41.211000+00:00 through 2026-10-18T07:57:35.999000+00:00.
- Resource capture: 2026-10-18T07:28:36.881239+00:00 through 2026-10-18T08:07:26.880950+00:00; 467 samples.
- Warm shared lab, no reset between windows; generated sessions and audit history remain.
- Both recorded throttling states: throttled=0x0.

Immutable ARM64 image identities:

- `["terramanager-update-evaluation:local"] sha256:661e085724d05cf2cbcbfc4f01bf3a0e6b6d4c954720699ee3330c34cfec0e42 arm64`
- `["caddy:2.11.4-alpine"] sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b arm64`

## Browser results

| Repetition | Idle GETs polling / SSE | Write GETs polling / SSE | Polling write p95 ms | SSE write p95 ms | Idle HTTP body bytes polling / SSE |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 120 / 0 | 120 / 60 | 12778 | 173 | 4523400 / 880 |
| 2 | 120 / 0 | 120 / 60 | 12765 | 179 | 4523382 / 946 |
| 3 | 120 / 0 | 120 / 60 | 12763 | 180 | 4523391 / 946 |

- All 36 synthetic Feedings were created and successfully deleted; all 180 expected observations arrived.
- Client errors and missing observations were zero. All twelve post-window stream guards passed at zero.
- A preceding five-client Pi/Caddy SSE smoke also left zero streams after closing.
- Idle received HTTP body bytes including upkeep fell by 99.979% to 99.981%.
- Body counters exclude HTTP headers, TLS/TCP framing and outgoing traffic.
- p95 starts before the write request and ends at lab DOM update; it includes acknowledgement, transport and refresh.
- Each write window contains six Feedings and thirty correlated observations. Repetitions remain separate.

Connected-lab targets passed: p95 <= 2 seconds, >= 90% fewer idle data GETs,
and >= 80% fewer idle received body bytes including upkeep. These are lab passes.

## Main-process CPU and whole-host WLAN

CPU uses cumulative user+system ticks over the actual covered probe interval.
100% means one busy CPU core; values are not percentages of all four cores.

These are in-window operating costs. Login/setup and cleanup occur outside
the windows. At 100 Hz, the smallest tick is 10 ms; very low idle SSE costs
are quantized, so differences between those repetitions should not be ranked.

| Workload | Process | Polling mean CPU range, % of one core | SSE mean CPU range, % of one core |
| --- | --- | ---: | ---: |
| idle | Dart | 0.930 to 0.982 | 0.009 to 0.017 |
| idle | Caddy | 0.113 to 0.122 | 0.009 to 0.026 |
| writes | Dart | 0.957 to 1.043 | 0.635 to 0.661 |
| writes | Caddy | 0.113 to 0.130 | 0.061 to 0.078 |

| Workload | Polling host RX+TX KiB/s range | SSE host RX+TX KiB/s range |
| --- | ---: | ---: |
| idle | 37.216 to 39.040 | 0.428 to 0.652 |
| writes | 38.018 to 40.774 | 25.551 to 25.987 |

Whole-host WLAN includes production traffic, SSH and sampler activity. It is
supporting evidence with a different scope from browser body counters. Do not
attribute every byte to the lab or add proxy and backend NetIO together.

## RSS and memory limits

| Process | First capture RSS MiB | Maximum observed during measured windows MiB | Last capture RSS MiB |
| --- | ---: | ---: | ---: |
| Dart | 25.109 | 183.328 | 150.734 |
| Caddy | 40.547 | 48.781 | 44.047 |

Dart RSS rose across the shared run, reaching about 183.3 MiB, and later fell
to about 150.7 MiB in the post-comparison capture. Both transports shared the
same process; fresh logins, runtime heap allocation and retained session/audit
state confound a per-mode memory comparison. The cause of the RSS changes is
not established by these counters. Zero retained streams does not prove that
all memory is bounded, and this run establishes no SSE RAM saving.

RSS describes PID 1, excluding container/tmpfs accounting and an exact
instantaneous peak. Docker MemUsage was 0B / 0B and remains unavailable, not
zero memory. VmHWM is lifetime-wide and is not used as a per-trial peak.

Proposed production regression targets for this same five-client fixture:

| Target after warmup | Dart | Caddy |
| --- | ---: | ---: |
| Mean idle CPU, % of one core | <= 0.10 | <= 0.10 |
| Mean CPU with six writes/120 s, % of one core | <= 1.50 | <= 0.25 |
| Maximum sampled PID 1 RSS | <= 256 MiB | <= 80 MiB |

These are proposed budgets with headroom above the lab observations, not
production passes. Validate them during integration. Add a 30-minute fixed-
workload run with at least 100 reconnects after warmup; investigate a final
10-minute median RSS more than 10% above the initial warm 10-minute median.
Keep process identity, workload, login/setup and cooldown phases explicit.

## Resource-data quality

- Every sample contains valid RSS and cumulative CPU counters for both processes.
- Twenty-four process observations per component per browser window; no discarded counter pairs.
- Counter coverage: 95.77% to 96.66% of the window; maximum in-window gap 6.034 s.
- Five-second scheduled cadence; zero skipped interval slots and no Docker sample errors.
- Both process identities remained constant; no CPU counter regressions.
- Probes use their own UTC/monotonic timestamps, not the earlier outer Docker timestamp.
- CPU averages use the covered span (about 115-116 s), not a fabricated full 120 s.
- Read-only docker exec probes add overhead consistently to both modes.
- Controller window start minus preceding server timestamp ranged from -111.4 to -16.1 ms.
  This includes request dispatch and clock offset; it is not an NTP measurement.

## Independent post-header ERR_ABORTED diagnostic

After the timed Pi comparison, a loopback HTTP control used the same Chrome
without TerraManager, credentials or deliberate request cancellation:

| Cache policy | Body reader | Complete valid bodies | Playwright requestfailed events |
| --- | --- | ---: | ---: |
| no-store | stream | 3 / 3 | 3 |
| no-store | native-json | 3 / 3 | 0 |
| no-cache | stream | 3 / 3 | 0 |
| no-cache | native-json | 3 / 3 | 0 |

All manual stream reads reached EOF and parsed the complete 8222-byte JSON.
The no-store/manual-stream cases nevertheless emitted net::ERR_ABORTED.
This reproduces a browser/tooling symptom independently of the backend.
It does not retrospectively classify the 61/107 failed terminal events in
the earlier Flutter capture or justify changing application cache policy.
Future tests must retain body/application outcomes separately from terminal events.

## Follow-up scope

The evaluation now records repeated target-device latency, request/body
traffic and per-window process CPU/RSS, alongside the earlier five-transport
pilot and real Flutter polling baseline. The architecture direction remains SSE.
The previous failed nine-window attempt stays separate and is not pooled here.

Remaining integration/acceptance work: committed transactional revisions,
central Flutter invalidation, authenticated streaming, replay/reconciliation,
foreground/background behavior, session revocation, conditional fallback,
restore handling, physical browsers and the wider 1/3/5/10-client matrix.
The [five implementation issue drafts](shared-care-sse-implementation-issues.md)
define this work, including measurable latency, traffic and proposed resource targets.

## Evidence and reproduction

- [Browser results, smoke and source-script identities](data/shared-care-sse-browser-2026-10-18.json)
- [Timestamped Pi resource capture](data/shared-care-sse-resources-2026-10-18.jsonl)
- [Derived per-window summary](data/shared-care-sse-summary-2026-10-18.json)
- [Source/image identities and data-quality checks](data/shared-care-sse-provenance-2026-10-18.json)
- [Independent stream diagnostic](data/shared-care-stream-diagnostic-2026-10-18.json)

From the repository root, using only the Python standard library:

```bash
python3 tool/evaluation/shared_updates/test_analyze_sse_comparison.py
python3 tool/evaluation/shared_updates/analyze_sse_comparison.py \
  docs/testing/data/shared-care-sse-browser-2026-10-18.json \
  --resources docs/testing/data/shared-care-sse-resources-2026-10-18.jsonl \
  --output-prefix /tmp/tm186-sse-review
```

Input SHA-256 values:

- `shared-care-sse-browser-2026-10-18.json`: `657feed7f97eb32180a95b0c64175fc9109e2fa64538116d6d4320f91aa92649`
- `shared-care-sse-resources-2026-10-18.jsonl`: `dd1c62b8699969843657be388b6b39740ac71d06efe153d2dd53468154e1db1f`
- `shared-care-stream-diagnostic-2026-10-18.json`: `36d7cfa223d28a14ff2c474ba26abe06f98483d123290ec3825b379d2710b1dd`
- `shared-care-sse-summary-2026-10-18.json`: `d237875018f48bdfa24bc84d063ffcf903973ca59fe3dd506d2e2871379d7220`

## Complete per-window observations

Run status: complete; completed windows: 12/12.
Pi resources loaded: True.

5 logical Chrome contexts, overview workload, 120 seconds/window, 3 planned repetitions.
Warm disposable lab with alternating order; this is not production SSE or Flutter frame timing.

| Trial | Repetition | Workload | Mode | Data GET starts | Writes | Observed / expected | Errors | Lab p95 ms |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | idle | polling | 120 | 0 | 0 / 0 | 0 | - |
| 2 | 1 | idle | sse | 0 | 0 | 0 / 0 | 0 | - |
| 3 | 1 | writes | sse | 60 | 6 | 30 / 30 | 0 | 173 |
| 4 | 1 | writes | polling | 120 | 6 | 30 / 30 | 0 | 12778 |
| 5 | 2 | writes | polling | 120 | 6 | 30 / 30 | 0 | 12765 |
| 6 | 2 | writes | sse | 60 | 6 | 30 / 30 | 0 | 179 |
| 7 | 2 | idle | sse | 0 | 0 | 0 / 0 | 0 | - |
| 8 | 2 | idle | polling | 120 | 0 | 0 / 0 | 0 | - |
| 9 | 3 | idle | polling | 120 | 0 | 0 / 0 | 0 | - |
| 10 | 3 | idle | sse | 0 | 0 | 0 / 0 | 0 | - |
| 11 | 3 | writes | sse | 60 | 6 | 30 / 30 | 0 | 180 |
| 12 | 3 | writes | polling | 120 | 6 | 30 / 30 | 0 | 12763 |

### Results across repetitions

| Workload | Mode | Completed repetitions | Data fetches min / median / max | p95 per repetition ms |
| --- | --- | ---: | --- | --- |
| idle | polling | 3 | 120 / 120 / 120 | - |
| idle | sse | 3 | 0 / 0 / 0 | - |
| writes | polling | 3 | 120 / 120 / 120 | 12778, 12765, 12763 |
| writes | sse | 3 | 60 / 60 / 60 | 173, 179, 180 |

### Paired idle reductions

| Repetition | Fewer data fetches | Fewer received HTTP body bytes |
| --- | ---: | ---: |
| 1 | 100.000% | 99.981% |
| 2 | 100.000% | 99.979% |
| 3 | 100.000% | 99.979% |

### Main-process observations

| Trial | Component | RSS max observed MiB | CPU seconds | Covered seconds | CPU mean % of one core | Coverage | Discarded pairs |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | tm186-evaluation-lab-1 | 87.141 | 1.100 | 114.993 | 0.957 | 95.78% | 0 |
| 1 | tm186-evaluation-gateway-1 | 45.781 | 0.130 | 114.981 | 0.113 | 95.77% | 0 |
| 2 | tm186-evaluation-lab-1 | 107.406 | 0.010 | 115.007 | 0.009 | 95.81% | 0 |
| 2 | tm186-evaluation-gateway-1 | 45.922 | 0.010 | 115.006 | 0.009 | 95.81% | 0 |
| 3 | tm186-evaluation-lab-1 | 107.578 | 0.730 | 115.004 | 0.635 | 95.83% | 0 |
| 3 | tm186-evaluation-gateway-1 | 46.797 | 0.080 | 115.008 | 0.070 | 95.83% | 0 |
| 4 | tm186-evaluation-lab-1 | 125.812 | 1.100 | 115.001 | 0.957 | 95.80% | 0 |
| 4 | tm186-evaluation-gateway-1 | 48.016 | 0.140 | 115.000 | 0.122 | 95.79% | 0 |
| 5 | tm186-evaluation-lab-1 | 144.812 | 1.200 | 115.007 | 1.043 | 95.83% | 0 |
| 5 | tm186-evaluation-gateway-1 | 48.094 | 0.150 | 115.028 | 0.130 | 95.85% | 0 |
| 6 | tm186-evaluation-lab-1 | 145.938 | 0.730 | 115.000 | 0.635 | 95.82% | 0 |
| 6 | tm186-evaluation-gateway-1 | 48.188 | 0.070 | 115.008 | 0.061 | 95.82% | 0 |
| 7 | tm186-evaluation-lab-1 | 163.500 | 0.020 | 116.009 | 0.017 | 96.66% | 0 |
| 7 | tm186-evaluation-gateway-1 | 48.219 | 0.030 | 116.011 | 0.026 | 96.66% | 0 |
| 8 | tm186-evaluation-lab-1 | 164.500 | 1.130 | 115.015 | 0.982 | 95.80% | 0 |
| 8 | tm186-evaluation-gateway-1 | 47.859 | 0.140 | 115.021 | 0.122 | 95.80% | 0 |
| 9 | tm186-evaluation-lab-1 | 164.734 | 1.070 | 115.003 | 0.930 | 95.80% | 0 |
| 9 | tm186-evaluation-gateway-1 | 48.109 | 0.130 | 115.006 | 0.113 | 95.80% | 0 |
| 10 | tm186-evaluation-lab-1 | 183.281 | 0.020 | 116.004 | 0.017 | 96.63% | 0 |
| 10 | tm186-evaluation-gateway-1 | 48.250 | 0.020 | 116.008 | 0.017 | 96.64% | 0 |
| 11 | tm186-evaluation-lab-1 | 183.328 | 0.760 | 115.012 | 0.661 | 95.81% | 0 |
| 11 | tm186-evaluation-gateway-1 | 48.094 | 0.090 | 115.031 | 0.078 | 95.83% | 0 |
| 12 | tm186-evaluation-lab-1 | 182.953 | 1.130 | 114.995 | 0.983 | 95.79% | 0 |
| 12 | tm186-evaluation-gateway-1 | 48.781 | 0.130 | 114.991 | 0.113 | 95.78% | 0 |

### Whole-host network observations

WLAN includes production traffic, SSH and diagnostic activity. These are not isolated lab wire bytes.

| Trial | Host RX+TX KiB/s | Counter span seconds | Samples |
| --- | ---: | ---: | ---: |
| 1 | 39.040 | 114.976 | 24 |
| 2 | 0.652 | 114.998 | 24 |
| 3 | 25.898 | 115.010 | 24 |
| 4 | 40.774 | 114.997 | 24 |
| 5 | 39.869 | 115.043 | 24 |
| 6 | 25.987 | 115.012 | 24 |
| 7 | 0.544 | 116.008 | 24 |
| 8 | 37.216 | 115.021 | 24 |
| 9 | 38.782 | 115.009 | 24 |
| 10 | 0.428 | 116.015 | 24 |
| 11 | 25.551 | 115.043 | 24 |
| 12 | 38.018 | 114.994 | 24 |

### Limits

- Logical contexts on one controller; lab DOM is not Flutter frame/rebuild timing.
- Counterbalanced workload order, one warm lab, no randomization or database resets.
- Each child deletes its created Feedings; sessions and audit history remain.
- Independent Pi resource recording is required; align actual UTC trial windows.
- Transport prototypes do not establish production reconnect/fallback correctness.
- Per-trial latency values describe correlated client observations; repetitions remain separate.
- HTTP body counters exclude headers, TLS/TCP framing and outgoing traffic.
- Main-process RSS is not total container/tmpfs memory or an exact instantaneous peak.
- Process CPU is cumulative tick delta over the actual covered probe span, not the full configured window.
- Discarded reset/restart pairs and coverage are reported; host-interface traffic includes unrelated work.
