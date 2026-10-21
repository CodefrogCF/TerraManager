# Integrated Flutter measurement windows

Capture: complete; browser: 155.0.8059.85; mode: sse; read diagnostics: reads.

| Clients | Repetition | View | Workload | Data GETs | Body bytes | Upkeep | Terminal / proven consumed | Capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | overview | idle | 0 | 54 | 2 | 0 / 0 | - |
| 1 | 1 | overview | writes | 3 | 113887 | 2 | 0 / 0 | 707 |
| 1 | 1 | detail | idle | 0 | 54 | 2 | 0 / 0 | - |
| 1 | 1 | detail | writes | 5 | 105298 | 2 | 0 / 0 | 278 |

## Process observations

CPU intervals use whole-window bounds. Inconclusive is not a failure or a pass.

| View / workload | Process | RSS max MiB | CPU lower / upper % of one core | Proposed CPU budget |
| --- | --- | ---: | ---: | --- |

## Supplementary drawFrame elapsed time

Synchronous elapsed wall time includes preemption. It is not OS CPU time, GPU time or presentation latency. Missing release measurements remain null.

| View / workload | Client | Frames | Dropped | p95 elapsed microseconds |
| --- | ---: | ---: | ---: | ---: |
| overview / idle | 1 | 0 | 0 | None |
| overview / writes | 1 | 3 | 0 | 238600 |
| detail / idle | 1 | 0 | 0 | None |
| detail / writes | 1 | 2 | 0 | 31500 |

## Limits

- Clients within each trial are correlated. Keep repetitions separate.
- Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.
- Screenshot completion is an upper capture bound, not physical presentation time.
- CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.
- Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.
- Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted.
