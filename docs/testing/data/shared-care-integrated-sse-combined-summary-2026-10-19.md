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
| 1 | 1 | overview | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 1 | overview | writes | 9 | 341661 | 6 | 0 / 0 | 799 |
| 1 | 1 | detail | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 1 | detail | writes | 15 | 315894 | 6 | 6 / 6 | 265 |
| 3 | 1 | overview | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 1 | overview | writes | 27 | 1024983 | 18 | 2 / 2 | 719 |
| 3 | 1 | detail | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 1 | detail | writes | 45 | 947682 | 18 | 12 / 12 | 952 |
| 10 | 1 | overview | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 1 | overview | writes | 90 | 3416610 | 60 | 4 / 4 | 1871 |
| 10 | 1 | detail | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 1 | detail | writes | 150 | 3158940 | 60 | 32 / 32 | 1178 |
| 1 | 2 | overview | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 2 | overview | writes | 9 | 341661 | 6 | 1 / 1 | 364 |
| 1 | 2 | detail | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 2 | detail | writes | 15 | 315894 | 6 | 5 / 5 | 305 |
| 3 | 2 | overview | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 2 | overview | writes | 27 | 1024983 | 18 | 8 / 8 | 431 |
| 3 | 2 | detail | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 2 | detail | writes | 45 | 947682 | 18 | 14 / 14 | 390 |
| 10 | 2 | overview | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 2 | overview | writes | 90 | 3416610 | 60 | 17 / 17 | 1424 |
| 10 | 2 | detail | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 2 | detail | writes | 150 | 3158940 | 60 | 44 / 44 | 991 |
| 1 | 3 | overview | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 3 | overview | writes | 9 | 341661 | 6 | 1 / 1 | 317 |
| 1 | 3 | detail | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 3 | detail | writes | 15 | 315894 | 6 | 3 / 3 | 284 |
| 3 | 3 | overview | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 3 | overview | writes | 27 | 1024983 | 18 | 6 / 6 | 559 |
| 3 | 3 | detail | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 3 | detail | writes | 45 | 947682 | 18 | 13 / 13 | 362 |
| 10 | 3 | overview | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 3 | overview | writes | 90 | 3416610 | 60 | 6 / 6 | 1873 |
| 10 | 3 | detail | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 3 | detail | writes | 150 | 3158940 | 60 | 29 / 29 | 1402 |

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
| 1 clients r1 overview / idle | tm230-acceptance-lab-1 | 180.969 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r1 overview / idle | tm230-acceptance-gateway-1 | 43.875 | 0.000 / 0.042 | within-conservative-bound |
| 1 clients r1 overview / writes | tm230-acceptance-lab-1 | 181.297 | 0.056 / 0.144 | within-conservative-bound |
| 1 clients r1 overview / writes | tm230-acceptance-gateway-1 | 44.016 | 0.000 / 0.056 | within-conservative-bound |
| 1 clients r1 detail / idle | tm230-acceptance-lab-1 | 181.297 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r1 detail / idle | tm230-acceptance-gateway-1 | 44.109 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-lab-1 | 181.516 | 0.056 / 0.133 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-gateway-1 | 44.125 | 0.011 / 0.067 | within-conservative-bound |
| 3 clients r1 overview / idle | tm230-acceptance-lab-1 | 181.203 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r1 overview / idle | tm230-acceptance-gateway-1 | 45.844 | 0.000 / 0.042 | within-conservative-bound |
| 3 clients r1 overview / writes | tm230-acceptance-lab-1 | 181.531 | 0.211 / 0.355 | within-conservative-bound |
| 3 clients r1 overview / writes | tm230-acceptance-gateway-1 | 45.562 | 0.022 / 0.089 | within-conservative-bound |
| 3 clients r1 detail / idle | tm230-acceptance-lab-1 | 181.484 | 0.000 / 0.025 | within-conservative-bound |
| 3 clients r1 detail / idle | tm230-acceptance-gateway-1 | 45.703 | 0.000 / 0.042 | within-conservative-bound |
| 3 clients r1 detail / writes | tm230-acceptance-lab-1 | 181.375 | 0.178 / 0.322 | within-conservative-bound |
| 3 clients r1 detail / writes | tm230-acceptance-gateway-1 | 45.688 | 0.044 / 0.111 | within-conservative-bound |
| 10 clients r1 overview / idle | tm230-acceptance-lab-1 | 181.703 | 0.008 / 0.042 | within-conservative-bound |
| 10 clients r1 overview / idle | tm230-acceptance-gateway-1 | 48.766 | 0.008 / 0.042 | within-conservative-bound |
| 10 clients r1 overview / writes | tm230-acceptance-lab-1 | 182.922 | 0.611 / 0.956 | within-conservative-bound |
| 10 clients r1 overview / writes | tm230-acceptance-gateway-1 | 49.672 | 0.111 / 0.244 | within-conservative-bound |
| 10 clients r1 detail / idle | tm230-acceptance-lab-1 | 182.922 | 0.017 / 0.058 | within-conservative-bound |
| 10 clients r1 detail / idle | tm230-acceptance-gateway-1 | 49.750 | 0.017 / 0.058 | within-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-lab-1 | 182.312 | 0.522 / 0.833 | within-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-gateway-1 | 50.703 | 0.156 / 0.278 | inconclusive-at-this-resolution |
| 1 clients r2 overview / idle | tm230-acceptance-lab-1 | 182.984 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r2 overview / idle | tm230-acceptance-gateway-1 | 50.906 | 0.000 / 0.033 | within-conservative-bound |
| 1 clients r2 overview / writes | tm230-acceptance-lab-1 | 183.094 | 0.067 / 0.144 | within-conservative-bound |
| 1 clients r2 overview / writes | tm230-acceptance-gateway-1 | 47.328 | 0.011 / 0.056 | within-conservative-bound |
| 1 clients r2 detail / idle | tm230-acceptance-lab-1 | 182.312 | 0.000 / 0.017 | within-conservative-bound |
| 1 clients r2 detail / idle | tm230-acceptance-gateway-1 | 46.250 | 0.008 / 0.042 | within-conservative-bound |
| 1 clients r2 detail / writes | tm230-acceptance-lab-1 | 182.531 | 0.056 / 0.144 | within-conservative-bound |
| 1 clients r2 detail / writes | tm230-acceptance-gateway-1 | 46.406 | 0.011 / 0.056 | within-conservative-bound |
| 3 clients r2 overview / idle | tm230-acceptance-lab-1 | 183.703 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r2 overview / idle | tm230-acceptance-gateway-1 | 47.734 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r2 overview / writes | tm230-acceptance-lab-1 | 182.531 | 0.211 / 0.367 | within-conservative-bound |
| 3 clients r2 overview / writes | tm230-acceptance-gateway-1 | 48.062 | 0.011 / 0.111 | within-conservative-bound |
| 3 clients r2 detail / idle | tm230-acceptance-lab-1 | 181.422 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r2 detail / idle | tm230-acceptance-gateway-1 | 47.312 | 0.000 / 0.025 | within-conservative-bound |
| 3 clients r2 detail / writes | tm230-acceptance-lab-1 | 181.812 | 0.178 / 0.311 | within-conservative-bound |
| 3 clients r2 detail / writes | tm230-acceptance-gateway-1 | 47.250 | 0.033 / 0.111 | within-conservative-bound |
| 10 clients r2 overview / idle | tm230-acceptance-lab-1 | 181.719 | 0.017 / 0.050 | within-conservative-bound |
| 10 clients r2 overview / idle | tm230-acceptance-gateway-1 | 49.484 | 0.017 / 0.058 | within-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-lab-1 | 182.156 | 0.611 / 0.944 | within-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-gateway-1 | 50.031 | 0.100 / 0.200 | within-conservative-bound |
| 10 clients r2 detail / idle | tm230-acceptance-lab-1 | 181.938 | 0.008 / 0.042 | within-conservative-bound |
| 10 clients r2 detail / idle | tm230-acceptance-gateway-1 | 50.438 | 0.017 / 0.058 | within-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-lab-1 | 182.828 | 0.500 / 0.811 | within-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-gateway-1 | 51.141 | 0.156 / 0.267 | inconclusive-at-this-resolution |
| 1 clients r3 overview / idle | tm230-acceptance-lab-1 | 182.109 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r3 overview / idle | tm230-acceptance-gateway-1 | 51.297 | 0.000 / 0.033 | within-conservative-bound |
| 1 clients r3 overview / writes | tm230-acceptance-lab-1 | 181.938 | 0.056 / 0.133 | within-conservative-bound |
| 1 clients r3 overview / writes | tm230-acceptance-gateway-1 | 48.109 | 0.000 / 0.056 | within-conservative-bound |
| 1 clients r3 detail / idle | tm230-acceptance-lab-1 | 181.938 | 0.000 / 0.017 | within-conservative-bound |
| 1 clients r3 detail / idle | tm230-acceptance-gateway-1 | 46.766 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.656 | 0.056 / 0.133 | within-conservative-bound |
| 1 clients r3 detail / writes | tm230-acceptance-gateway-1 | 46.531 | 0.000 / 0.067 | within-conservative-bound |
| 3 clients r3 overview / idle | tm230-acceptance-lab-1 | 182.219 | 0.000 / 0.025 | within-conservative-bound |
| 3 clients r3 overview / idle | tm230-acceptance-gateway-1 | 48.047 | 0.000 / 0.042 | within-conservative-bound |
| 3 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.547 | 0.200 / 0.356 | within-conservative-bound |
| 3 clients r3 overview / writes | tm230-acceptance-gateway-1 | 48.500 | 0.033 / 0.100 | within-conservative-bound |
| 3 clients r3 detail / idle | tm230-acceptance-lab-1 | 181.938 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r3 detail / idle | tm230-acceptance-gateway-1 | 47.312 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r3 detail / writes | tm230-acceptance-lab-1 | 181.828 | 0.167 / 0.311 | within-conservative-bound |
| 3 clients r3 detail / writes | tm230-acceptance-gateway-1 | 47.312 | 0.022 / 0.100 | within-conservative-bound |
| 10 clients r3 overview / idle | tm230-acceptance-lab-1 | 181.719 | 0.017 / 0.050 | within-conservative-bound |
| 10 clients r3 overview / idle | tm230-acceptance-gateway-1 | 49.781 | 0.017 / 0.067 | within-conservative-bound |
| 10 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.938 | 0.644 / 0.966 | within-conservative-bound |
| 10 clients r3 overview / writes | tm230-acceptance-gateway-1 | 50.703 | 0.111 / 0.211 | within-conservative-bound |
| 10 clients r3 detail / idle | tm230-acceptance-lab-1 | 181.938 | 0.017 / 0.058 | within-conservative-bound |
| 10 clients r3 detail / idle | tm230-acceptance-gateway-1 | 50.781 | 0.017 / 0.050 | within-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.828 | 0.522 / 0.833 | within-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-gateway-1 | 51.297 | 0.156 / 0.289 | inconclusive-at-this-resolution |

## Limits

- Clients within each trial are correlated. Keep repetitions separate.
- Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.
- Screenshot completion is an upper capture bound, not physical presentation time.
- CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.
- Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.
- Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted.
