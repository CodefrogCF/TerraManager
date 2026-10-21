# Integrated Flutter measurement windows

Capture: complete; browser: 155.0.8059.84; mode: sse; read diagnostics: off.

| Clients | Repetition | View | Workload | Data GETs | Body bytes | Upkeep | Terminal / proven consumed | Capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | overview | idle | 0 | 54 | 2 | 0 / 0 | - |
| 1 | 1 | overview | writes | 3 | 113873 | 2 | 0 / 0 | 291 |
| 1 | 1 | detail | idle | 0 | 54 | 2 | 0 / 0 | - |
| 1 | 1 | detail | writes | 5 | 105284 | 2 | 2 / 0 | 267 |

## Process observations

CPU intervals use whole-window bounds. Inconclusive is not a failure or a pass.

| View / workload | Process | RSS max MiB | CPU lower / upper % of one core | Proposed CPU budget |
| --- | --- | ---: | ---: | --- |
| 1 clients r1 overview / idle | tm230-acceptance-lab-1 | 126.250 | 0.000 / 0.200 | inconclusive-at-this-resolution |
| 1 clients r1 overview / idle | tm230-acceptance-gateway-1 | 43.953 | 0.000 / 0.133 | inconclusive-at-this-resolution |
| 1 clients r1 overview / writes | tm230-acceptance-lab-1 | 126.438 | 0.000 / 0.233 | within-conservative-bound |
| 1 clients r1 overview / writes | tm230-acceptance-gateway-1 | 44.062 | 0.000 / 0.100 | within-conservative-bound |
| 1 clients r1 detail / idle | tm230-acceptance-lab-1 | 126.438 | 0.000 / 0.167 | inconclusive-at-this-resolution |
| 1 clients r1 detail / idle | tm230-acceptance-gateway-1 | 44.203 | 0.000 / 0.100 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-lab-1 | 124.547 | 0.000 / 0.167 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-gateway-1 | 44.469 | 0.000 / 0.133 | within-conservative-bound |

## Limits

- Clients within each trial are correlated. Keep repetitions separate.
- Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.
- Screenshot completion is an upper capture bound, not physical presentation time.
- CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.
- Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.
- Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted.
