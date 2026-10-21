# Integrated Flutter measurement windows

Capture: complete; browser: 155.0.8059.85; mode: sse; read diagnostics: reads.

| Clients | Repetition | View | Workload | Data GETs | Body bytes | Upkeep | Terminal / proven consumed | Capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 10 | 1 | overview | idle | 0 | 540 | 20 | 0 / 0 | - |
| 10 | 1 | overview | writes | 180 | 6833220 | 120 | 9 / 9 | 2449 |
| 10 | 1 | detail | idle | 0 | 540 | 20 | 0 / 0 | - |
| 10 | 1 | detail | writes | 300 | 6317880 | 120 | 67 / 67 | 1231 |
| 10 | 2 | overview | idle | 0 | 540 | 20 | 0 / 0 | - |
| 10 | 2 | overview | writes | 180 | 6833220 | 120 | 16 / 16 | 1662 |
| 10 | 2 | detail | idle | 0 | 540 | 20 | 0 / 0 | - |
| 10 | 2 | detail | writes | 300 | 6317880 | 120 | 74 / 74 | 1036 |
| 10 | 3 | overview | idle | 0 | 540 | 20 | 0 / 0 | - |
| 10 | 3 | overview | writes | 180 | 6833220 | 120 | 40 / 40 | 1644 |
| 10 | 3 | detail | idle | 0 | 540 | 20 | 0 / 0 | - |
| 10 | 3 | detail | writes | 300 | 6317880 | 120 | 68 / 68 | 1119 |

## Process observations

CPU intervals use whole-window bounds. Inconclusive is not a failure or a pass.

| View / workload | Process | RSS max MiB | CPU lower / upper % of one core | Proposed CPU budget |
| --- | --- | ---: | ---: | --- |
| 10 clients r1 overview / idle | tm230-acceptance-lab-1 | 181.719 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r1 overview / idle | tm230-acceptance-gateway-1 | 49.531 | 0.000 / 0.133 | inconclusive-at-this-resolution |
| 10 clients r1 overview / writes | tm230-acceptance-lab-1 | 182.328 | 0.778 / 0.950 | within-conservative-bound |
| 10 clients r1 overview / writes | tm230-acceptance-gateway-1 | 51.562 | 0.150 / 0.206 | within-conservative-bound |
| 10 clients r1 detail / idle | tm230-acceptance-lab-1 | 181.891 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r1 detail / idle | tm230-acceptance-gateway-1 | 51.750 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-lab-1 | 183.156 | 0.617 / 0.767 | within-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-gateway-1 | 52.219 | 0.183 / 0.244 | within-conservative-bound |
| 10 clients r2 overview / idle | tm230-acceptance-lab-1 | 181.891 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r2 overview / idle | tm230-acceptance-gateway-1 | 51.484 | 0.000 / 0.067 | within-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-lab-1 | 182.453 | 0.772 / 0.944 | within-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-gateway-1 | 51.734 | 0.156 / 0.206 | within-conservative-bound |
| 10 clients r2 detail / idle | tm230-acceptance-lab-1 | 181.828 | 0.000 / 0.133 | inconclusive-at-this-resolution |
| 10 clients r2 detail / idle | tm230-acceptance-gateway-1 | 51.734 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-lab-1 | 182.828 | 0.617 / 0.772 | within-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-gateway-1 | 52.234 | 0.189 / 0.250 | within-conservative-bound |
| 10 clients r3 overview / idle | tm230-acceptance-lab-1 | 182.328 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r3 overview / idle | tm230-acceptance-gateway-1 | 51.094 | 0.000 / 0.133 | inconclusive-at-this-resolution |
| 10 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.547 | 0.767 / 0.950 | within-conservative-bound |
| 10 clients r3 overview / writes | tm230-acceptance-gateway-1 | 51.641 | 0.150 / 0.206 | within-conservative-bound |
| 10 clients r3 detail / idle | tm230-acceptance-lab-1 | 181.500 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r3 detail / idle | tm230-acceptance-gateway-1 | 51.781 | 0.000 / 0.100 | within-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-lab-1 | 183.156 | 0.656 / 0.805 | within-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-gateway-1 | 52.641 | 0.200 / 0.261 | inconclusive-at-this-resolution |

## Limits

- Clients within each trial are correlated. Keep repetitions separate.
- Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.
- Screenshot completion is an upper capture bound, not physical presentation time.
- CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.
- Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.
- Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted.
