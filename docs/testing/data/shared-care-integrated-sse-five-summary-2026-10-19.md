# Integrated Flutter measurement windows

Capture: complete; browser: 155.0.8059.85; mode: sse; read diagnostics: reads.

| Clients | Repetition | View | Workload | Data GETs | Body bytes | Upkeep | Terminal / proven consumed | Capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 5 | 1 | overview | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 1 | overview | writes | 45 | 1708305 | 30 | 6 / 6 | 813 |
| 5 | 1 | detail | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 1 | detail | writes | 75 | 1579470 | 30 | 21 / 21 | 988 |
| 5 | 2 | overview | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 2 | overview | writes | 45 | 1708305 | 30 | 9 / 9 | 1029 |
| 5 | 2 | detail | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 2 | detail | writes | 75 | 1579470 | 30 | 21 / 21 | 423 |
| 5 | 3 | overview | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 3 | overview | writes | 45 | 1708305 | 30 | 7 / 7 | 762 |
| 5 | 3 | detail | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 3 | detail | writes | 75 | 1579470 | 30 | 28 / 28 | 445 |

## Process observations

CPU intervals use whole-window bounds. Inconclusive is not a failure or a pass.

| View / workload | Process | RSS max MiB | CPU lower / upper % of one core | Proposed CPU budget |
| --- | --- | ---: | ---: | --- |
| 5 clients r1 overview / idle | tm230-acceptance-lab-1 | 181.859 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r1 overview / idle | tm230-acceptance-gateway-1 | 49.094 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r1 overview / writes | tm230-acceptance-lab-1 | 181.969 | 0.322 / 0.544 | within-conservative-bound |
| 5 clients r1 overview / writes | tm230-acceptance-gateway-1 | 48.219 | 0.056 / 0.122 | within-conservative-bound |
| 5 clients r1 detail / idle | tm230-acceptance-lab-1 | 181.969 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r1 detail / idle | tm230-acceptance-gateway-1 | 48.719 | 0.000 / 0.050 | within-conservative-bound |
| 5 clients r1 detail / writes | tm230-acceptance-lab-1 | 181.969 | 0.278 / 0.467 | within-conservative-bound |
| 5 clients r1 detail / writes | tm230-acceptance-gateway-1 | 48.812 | 0.056 / 0.144 | within-conservative-bound |
| 5 clients r2 overview / idle | tm230-acceptance-lab-1 | 182.391 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r2 overview / idle | tm230-acceptance-gateway-1 | 50.016 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r2 overview / writes | tm230-acceptance-lab-1 | 182.453 | 0.322 / 0.533 | within-conservative-bound |
| 5 clients r2 overview / writes | tm230-acceptance-gateway-1 | 50.031 | 0.056 / 0.133 | within-conservative-bound |
| 5 clients r2 detail / idle | tm230-acceptance-lab-1 | 182.000 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r2 detail / idle | tm230-acceptance-gateway-1 | 49.500 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r2 detail / writes | tm230-acceptance-lab-1 | 181.781 | 0.289 / 0.478 | within-conservative-bound |
| 5 clients r2 detail / writes | tm230-acceptance-gateway-1 | 49.156 | 0.078 / 0.167 | within-conservative-bound |
| 5 clients r3 overview / idle | tm230-acceptance-lab-1 | 181.891 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r3 overview / idle | tm230-acceptance-gateway-1 | 50.047 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.000 | 0.322 / 0.544 | within-conservative-bound |
| 5 clients r3 overview / writes | tm230-acceptance-gateway-1 | 50.078 | 0.044 / 0.133 | within-conservative-bound |
| 5 clients r3 detail / idle | tm230-acceptance-lab-1 | 182.000 | 0.000 / 0.042 | within-conservative-bound |
| 5 clients r3 detail / idle | tm230-acceptance-gateway-1 | 49.672 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.062 | 0.300 / 0.489 | within-conservative-bound |
| 5 clients r3 detail / writes | tm230-acceptance-gateway-1 | 49.406 | 0.067 / 0.156 | within-conservative-bound |

## Limits

- Clients within each trial are correlated. Keep repetitions separate.
- Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.
- Screenshot completion is an upper capture bound, not physical presentation time.
- CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.
- Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.
- Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted.
