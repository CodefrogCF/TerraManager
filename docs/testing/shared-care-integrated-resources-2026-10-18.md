# Integrated SSE resources and connection soak

Date: 2026-10-18. Raspberry Pi 5 Model B, 4 GB, Linux aarch64. Current production
API and Flutter UI on the disposable 100-Animal / 2,000-Feeding fixture.
Production port 443 was not involved. Issue #230 remains open.

## Inputs and reproduction

The two complete five-second captures are published byte-for-byte after checking
for exact private fixture usernames, passwords and identity. They contain
resource metadata, no application response bodies or pictures:

| Input | Samples | First / last host sample UTC | SHA-256 |
| --- | ---: | --- | --- |
| [14:53 capture](data/shared-care-integrated-pi-resources-2026-10-18T145330Z.jsonl) | 2160 | 14:53:43.192433 / 17:53:38.192036 | `b64eb27b935f1caef0e00f676b153e47944243ceb1805d5f075fb0f306d5fb1b` |
| [17:48 capture](data/shared-care-integrated-pi-resources-2026-10-18T174803Z.jsonl) | 1738 | 17:48:15.599012 / 20:13:00.598735 | `d5582c68977b415e06b3a90e6ac9f1e84f4ca75cc7c528f301d962bd1e03c9b0` |

The 322.593-second overlap is a union of observations; absolute counters are
never added. No trailing partial records occur. The inputs cover all 48 matrix
windows and the outer probes needed by the final soak. The analyzer retains
source hashes, clock probes, sample gaps and conservative whole-window CPU
bounds. RSS is sampled PID 1 memory, excluding container tmpfs and browser RAM.
Docker reports `MemoryLimit=false`; its zero `MemUsage` values are not RAM evidence.

Regenerate from the repository root:

```bash
python3 tool/evaluation/shared_updates/analyze_integrated.py \
  docs/testing/data/shared-care-integrated-sse-matrix-2026-10-18.json \
  --resources docs/testing/data/shared-care-integrated-pi-resources-2026-10-18T145330Z.jsonl \
  --resources docs/testing/data/shared-care-integrated-pi-resources-2026-10-18T174803Z.jsonl \
  --output-prefix matrix-summary
python3 tool/evaluation/shared_updates/analyze_integrated_soak.py \
  docs/testing/data/shared-care-integrated-reopen-soak-2026-10-18.json \
  --resources docs/testing/data/shared-care-integrated-pi-resources-2026-10-18T174803Z.jsonl \
  --output soak-summary.json
```

## Release matrix

Process identities stayed stable: Dart start ticks `1104844068`, Caddy
`1104844086`. Highest sampled RSS across matrix windows: **183.359375 MiB Dart /
51.593750 MiB Caddy**, within the proposed 256 / 80 MiB limits. Maximum probe
gaps were 6.026 / 6.066 seconds.

- Dart: **48/48** conservative CPU intervals within proposed budgets.
- Caddy: **45/48** within; **three inconclusive**, all ten-client detail writes.
  All five-client CPU windows are within the proposed bounds.
- Proposed CPU budgets remain 0.10 / 0.10% of one core idle, 1.50 / 0.25% during
  ordinary writes (Dart / Caddy). They are not raised to turn uncertainty into a pass.

| Ten-client detail writes | Caddy lower % | Caddy upper % | Against proposed 0.25% |
| ---: | ---: | ---: | --- |
| Repetition 1 | 0.155550 | 0.277769 | Inconclusive |
| Repetition 2 | 0.155535 | 0.277741 | Inconclusive |
| Repetition 3 | 0.155528 | 0.266619 | Inconclusive |

The [JSON](data/shared-care-integrated-sse-matrix-summary-2026-10-18.json) and
[tables](data/shared-care-integrated-sse-matrix-summary-2026-10-18.md) retain each
window. A budget straddled by the uncertainty interval is neither an established
exceedance nor a pass. Read-only process probes add their own overhead.

## Fixed 30-minute reopen workload

The [successful capture](data/shared-care-integrated-reopen-soak-2026-10-18.json)
ran **19:42:36.502–20:12:36.506 UTC**, after separate setup/warmup. Chrome was
**155.0.8059.85**; the earlier matrix used .84.

- **118 actual completed reopen cycles** inside 1,800.004 seconds.
- Each cycle observes server streams **5 -> 4 -> 5** around one tab's
  `about:blank` and return, plus a new HTTP 200, `changes` frame and expected UI.
- **Zero page errors**, maximum sampled streams five, final sampled streams zero.
- Four milliseconds of timestamp-span excess; the helper reports a three-ms
  scheduling overrun. Cleanup is outside the fixed workload window.

The [summary](data/shared-care-integrated-reopen-soak-summary-2026-10-18.json)
uses first/final warm ten-minute medians, each with 120 valid RSS samples,
stable identities and maximum gaps around six seconds:

| Process | First median MiB | Final median MiB | Growth | Highest sampled MiB |
| --- | ---: | ---: | ---: | ---: |
| Dart | 181.640625 | 181.640625 | 0.000% | 182.468750 |
| Caddy | 50.765625 | 50.968750 | 0.400% | 51.312500 |

Both are within the 10% investigation threshold and sampled RSS limits. This
supports stability in this workload; it does not prove absence of leaks or
per-mode RAM savings. Reopen includes Flutter startup/route reads and does not
establish native outage, mobile background or expiry behavior. There was no
live queue-size measurement; queue bounds need separate source/test evidence.

Whole-workload CPU bounds were Dart 0.472221–0.475554%, Caddy 0.378332–0.383332%
of one core. Ordinary idle/write CPU limits do not apply to repeated page startup.

## Outstanding latency observation

Five-client overview repetition 3 retains its 2,494-ms capture p95 and 2,277-ms
remote semantics p95. For its slowest write/client, EOF and matching application
parse were recorded for Boxes at +104 ms, Animals at +423 ms and Reminders at
+792 ms; the remote selector completed at +2,277 ms. The reads were sequential.
About 1,485 ms remains after the last recorded matching parse before selector
completion. This narrows the diagnostic scope; it does not prove physical paint
timing or a rendering/controller root cause. The original outlier remains.

Matched polling, supplementary frames, unresolved `/changes` terminal events,
physical lifecycle results and final ADR budget decisions remain open.
