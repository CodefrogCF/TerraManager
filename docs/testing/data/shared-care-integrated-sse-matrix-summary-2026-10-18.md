# Integrated Flutter measurement windows

Capture: complete; browser: 155.0.8059.84; mode: sse; read diagnostics: reads.

| Clients | Repetition | View | Workload | Data GETs | Body bytes | Upkeep | Terminal / proven consumed | Capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 5 | 1 | overview | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 1 | overview | writes | 45 | 1708130 | 30 | 3 / 1 | 1179 |
| 5 | 1 | detail | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 1 | detail | writes | 75 | 1579365 | 30 | 23 / 22 | 917 |
| 1 | 1 | overview | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 1 | overview | writes | 9 | 341640 | 6 | 1 / 1 | 316 |
| 1 | 1 | detail | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 1 | detail | writes | 15 | 315873 | 6 | 8 / 8 | 268 |
| 3 | 1 | overview | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 1 | overview | writes | 27 | 1024920 | 18 | 0 / 0 | 1051 |
| 3 | 1 | detail | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 1 | detail | writes | 45 | 947619 | 18 | 17 / 16 | 1393 |
| 10 | 1 | overview | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 1 | overview | writes | 90 | 3416400 | 60 | 3 / 2 | 6114 |
| 10 | 1 | detail | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 1 | detail | writes | 150 | 3158730 | 60 | 37 / 34 | 1078 |
| 5 | 2 | overview | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 2 | overview | writes | 45 | 1708200 | 30 | 14 / 12 | 603 |
| 5 | 2 | detail | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 2 | detail | writes | 75 | 1579392 | 31 | 22 / 20 | 542 |
| 1 | 2 | overview | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 2 | overview | writes | 9 | 341640 | 6 | 1 / 1 | 413 |
| 1 | 2 | detail | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 2 | detail | writes | 15 | 315873 | 6 | 3 / 3 | 285 |
| 3 | 2 | overview | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 2 | overview | writes | 27 | 1024920 | 18 | 3 / 1 | 754 |
| 3 | 2 | detail | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 2 | detail | writes | 45 | 947619 | 18 | 19 / 17 | 374 |
| 10 | 2 | overview | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 2 | overview | writes | 90 | 3416400 | 60 | 5 / 5 | 2380 |
| 10 | 2 | detail | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 2 | detail | writes | 150 | 3158730 | 60 | 31 / 31 | 1338 |
| 5 | 3 | overview | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 3 | overview | writes | 45 | 1708200 | 30 | 4 / 1 | 2494 |
| 5 | 3 | detail | idle | 0 | 1080 | 40 | 0 / 0 | - |
| 5 | 3 | detail | writes | 75 | 1579365 | 30 | 17 / 15 | 971 |
| 1 | 3 | overview | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 3 | overview | writes | 9 | 341640 | 6 | 0 / 0 | 702 |
| 1 | 3 | detail | idle | 0 | 216 | 8 | 0 / 0 | - |
| 1 | 3 | detail | writes | 15 | 315873 | 6 | 7 / 7 | 1147 |
| 3 | 3 | overview | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 3 | overview | writes | 27 | 1024920 | 18 | 5 / 5 | 1134 |
| 3 | 3 | detail | idle | 0 | 648 | 24 | 0 / 0 | - |
| 3 | 3 | detail | writes | 45 | 947619 | 18 | 18 / 17 | 327 |
| 10 | 3 | overview | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 3 | overview | writes | 90 | 3416400 | 60 | 13 / 10 | 1957 |
| 10 | 3 | detail | idle | 0 | 2160 | 80 | 0 / 0 | - |
| 10 | 3 | detail | writes | 150 | 3158730 | 60 | 45 / 44 | 1020 |

## Process observations

CPU intervals use whole-window bounds. Inconclusive is not a failure or a pass.

| View / workload | Process | RSS max MiB | CPU lower / upper % of one core | Proposed CPU budget |
| --- | --- | ---: | ---: | --- |
| 5 clients r1 overview / idle | tm230-acceptance-lab-1 | 162.531 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r1 overview / idle | tm230-acceptance-gateway-1 | 46.109 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r1 overview / writes | tm230-acceptance-lab-1 | 162.578 | 0.333 / 0.522 | within-conservative-bound |
| 5 clients r1 overview / writes | tm230-acceptance-gateway-1 | 46.984 | 0.044 / 0.133 | within-conservative-bound |
| 5 clients r1 detail / idle | tm230-acceptance-lab-1 | 162.250 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r1 detail / idle | tm230-acceptance-gateway-1 | 47.000 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r1 detail / writes | tm230-acceptance-lab-1 | 163.078 | 0.267 / 0.467 | within-conservative-bound |
| 5 clients r1 detail / writes | tm230-acceptance-gateway-1 | 47.328 | 0.067 / 0.156 | within-conservative-bound |
| 1 clients r1 overview / idle | tm230-acceptance-lab-1 | 163.469 | 0.000 / 0.017 | within-conservative-bound |
| 1 clients r1 overview / idle | tm230-acceptance-gateway-1 | 47.594 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r1 overview / writes | tm230-acceptance-lab-1 | 163.703 | 0.067 / 0.156 | within-conservative-bound |
| 1 clients r1 overview / writes | tm230-acceptance-gateway-1 | 45.672 | 0.000 / 0.067 | within-conservative-bound |
| 1 clients r1 detail / idle | tm230-acceptance-lab-1 | 162.047 | 0.000 / 0.017 | within-conservative-bound |
| 1 clients r1 detail / idle | tm230-acceptance-gateway-1 | 45.734 | 0.000 / 0.033 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-lab-1 | 162.375 | 0.044 / 0.122 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-gateway-1 | 45.750 | 0.011 / 0.067 | within-conservative-bound |
| 3 clients r1 overview / idle | tm230-acceptance-lab-1 | 162.703 | 0.000 / 0.025 | within-conservative-bound |
| 3 clients r1 overview / idle | tm230-acceptance-gateway-1 | 47.406 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r1 overview / writes | tm230-acceptance-lab-1 | 162.703 | 0.233 / 0.389 | within-conservative-bound |
| 3 clients r1 overview / writes | tm230-acceptance-gateway-1 | 47.562 | 0.044 / 0.111 | within-conservative-bound |
| 3 clients r1 detail / idle | tm230-acceptance-lab-1 | 162.156 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r1 detail / idle | tm230-acceptance-gateway-1 | 46.391 | 0.000 / 0.025 | within-conservative-bound |
| 3 clients r1 detail / writes | tm230-acceptance-lab-1 | 162.484 | 0.167 / 0.289 | within-conservative-bound |
| 3 clients r1 detail / writes | tm230-acceptance-gateway-1 | 46.359 | 0.033 / 0.122 | within-conservative-bound |
| 10 clients r1 overview / idle | tm230-acceptance-lab-1 | 162.703 | 0.008 / 0.050 | within-conservative-bound |
| 10 clients r1 overview / idle | tm230-acceptance-gateway-1 | 49.047 | 0.017 / 0.050 | within-conservative-bound |
| 10 clients r1 overview / writes | tm230-acceptance-lab-1 | 162.703 | 0.900 / 0.955 | within-conservative-bound |
| 10 clients r1 overview / writes | tm230-acceptance-gateway-1 | 50.156 | 0.178 / 0.233 | within-conservative-bound |
| 10 clients r1 detail / idle | tm230-acceptance-lab-1 | 162.203 | 0.008 / 0.050 | within-conservative-bound |
| 10 clients r1 detail / idle | tm230-acceptance-gateway-1 | 50.156 | 0.008 / 0.050 | within-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-lab-1 | 163.078 | 0.511 / 0.833 | within-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-gateway-1 | 50.875 | 0.156 / 0.278 | inconclusive-at-this-resolution |
| 5 clients r2 overview / idle | tm230-acceptance-lab-1 | 162.438 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r2 overview / idle | tm230-acceptance-gateway-1 | 51.141 | 0.008 / 0.042 | within-conservative-bound |
| 5 clients r2 overview / writes | tm230-acceptance-lab-1 | 162.984 | 0.344 / 0.544 | within-conservative-bound |
| 5 clients r2 overview / writes | tm230-acceptance-gateway-1 | 50.641 | 0.044 / 0.122 | within-conservative-bound |
| 5 clients r2 detail / idle | tm230-acceptance-lab-1 | 162.047 | 0.000 / 0.042 | within-conservative-bound |
| 5 clients r2 detail / idle | tm230-acceptance-gateway-1 | 48.312 | 0.000 / 0.042 | within-conservative-bound |
| 5 clients r2 detail / writes | tm230-acceptance-lab-1 | 162.297 | 0.233 / 0.411 | within-conservative-bound |
| 5 clients r2 detail / writes | tm230-acceptance-gateway-1 | 48.844 | 0.067 / 0.156 | within-conservative-bound |
| 1 clients r2 overview / idle | tm230-acceptance-lab-1 | 182.797 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r2 overview / idle | tm230-acceptance-gateway-1 | 48.922 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r2 overview / writes | tm230-acceptance-lab-1 | 183.016 | 0.067 / 0.156 | within-conservative-bound |
| 1 clients r2 overview / writes | tm230-acceptance-gateway-1 | 47.812 | 0.000 / 0.056 | within-conservative-bound |
| 1 clients r2 detail / idle | tm230-acceptance-lab-1 | 180.750 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r2 detail / idle | tm230-acceptance-gateway-1 | 46.578 | 0.000 / 0.033 | within-conservative-bound |
| 1 clients r2 detail / writes | tm230-acceptance-lab-1 | 181.078 | 0.056 / 0.133 | within-conservative-bound |
| 1 clients r2 detail / writes | tm230-acceptance-gateway-1 | 46.594 | 0.022 / 0.067 | within-conservative-bound |
| 3 clients r2 overview / idle | tm230-acceptance-lab-1 | 181.438 | 0.000 / 0.025 | within-conservative-bound |
| 3 clients r2 overview / idle | tm230-acceptance-gateway-1 | 47.938 | 0.000 / 0.042 | within-conservative-bound |
| 3 clients r2 overview / writes | tm230-acceptance-lab-1 | 181.891 | 0.211 / 0.378 | within-conservative-bound |
| 3 clients r2 overview / writes | tm230-acceptance-gateway-1 | 48.016 | 0.033 / 0.100 | within-conservative-bound |
| 3 clients r2 detail / idle | tm230-acceptance-lab-1 | 181.891 | 0.000 / 0.042 | within-conservative-bound |
| 3 clients r2 detail / idle | tm230-acceptance-gateway-1 | 47.500 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r2 detail / writes | tm230-acceptance-lab-1 | 182.219 | 0.144 / 0.233 | within-conservative-bound |
| 3 clients r2 detail / writes | tm230-acceptance-gateway-1 | 47.375 | 0.022 / 0.100 | within-conservative-bound |
| 10 clients r2 overview / idle | tm230-acceptance-lab-1 | 181.297 | 0.008 / 0.050 | within-conservative-bound |
| 10 clients r2 overview / idle | tm230-acceptance-gateway-1 | 49.984 | 0.017 / 0.050 | within-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-lab-1 | 181.969 | 0.622 / 0.933 | within-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-gateway-1 | 50.328 | 0.100 / 0.200 | within-conservative-bound |
| 10 clients r2 detail / idle | tm230-acceptance-lab-1 | 181.531 | 0.008 / 0.042 | within-conservative-bound |
| 10 clients r2 detail / idle | tm230-acceptance-gateway-1 | 51.156 | 0.025 / 0.058 | within-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-lab-1 | 182.969 | 0.500 / 0.789 | within-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-gateway-1 | 51.438 | 0.156 / 0.278 | inconclusive-at-this-resolution |
| 5 clients r3 overview / idle | tm230-acceptance-lab-1 | 181.531 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r3 overview / idle | tm230-acceptance-gateway-1 | 50.969 | 0.000 / 0.050 | within-conservative-bound |
| 5 clients r3 overview / writes | tm230-acceptance-lab-1 | 181.859 | 0.333 / 0.567 | within-conservative-bound |
| 5 clients r3 overview / writes | tm230-acceptance-gateway-1 | 49.297 | 0.067 / 0.144 | within-conservative-bound |
| 5 clients r3 detail / idle | tm230-acceptance-lab-1 | 181.641 | 0.000 / 0.033 | within-conservative-bound |
| 5 clients r3 detail / idle | tm230-acceptance-gateway-1 | 49.594 | 0.000 / 0.042 | within-conservative-bound |
| 5 clients r3 detail / writes | tm230-acceptance-lab-1 | 181.969 | 0.278 / 0.467 | within-conservative-bound |
| 5 clients r3 detail / writes | tm230-acceptance-gateway-1 | 49.500 | 0.067 / 0.156 | within-conservative-bound |
| 1 clients r3 overview / idle | tm230-acceptance-lab-1 | 183.359 | 0.000 / 0.025 | within-conservative-bound |
| 1 clients r3 overview / idle | tm230-acceptance-gateway-1 | 49.938 | 0.000 / 0.033 | within-conservative-bound |
| 1 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.922 | 0.067 / 0.156 | within-conservative-bound |
| 1 clients r3 overview / writes | tm230-acceptance-gateway-1 | 47.406 | 0.011 / 0.056 | within-conservative-bound |
| 1 clients r3 detail / idle | tm230-acceptance-lab-1 | 180.531 | 0.000 / 0.017 | within-conservative-bound |
| 1 clients r3 detail / idle | tm230-acceptance-gateway-1 | 47.438 | 0.000 / 0.033 | within-conservative-bound |
| 1 clients r3 detail / writes | tm230-acceptance-lab-1 | 180.859 | 0.078 / 0.133 | within-conservative-bound |
| 1 clients r3 detail / writes | tm230-acceptance-gateway-1 | 46.969 | 0.022 / 0.078 | within-conservative-bound |
| 3 clients r3 overview / idle | tm230-acceptance-lab-1 | 181.531 | 0.000 / 0.025 | within-conservative-bound |
| 3 clients r3 overview / idle | tm230-acceptance-gateway-1 | 48.109 | 0.008 / 0.042 | within-conservative-bound |
| 3 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.359 | 0.278 / 0.322 | within-conservative-bound |
| 3 clients r3 overview / writes | tm230-acceptance-gateway-1 | 47.547 | 0.033 / 0.089 | within-conservative-bound |
| 3 clients r3 detail / idle | tm230-acceptance-lab-1 | 182.359 | 0.000 / 0.033 | within-conservative-bound |
| 3 clients r3 detail / idle | tm230-acceptance-gateway-1 | 47.859 | 0.000 / 0.050 | within-conservative-bound |
| 3 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.078 | 0.156 / 0.300 | within-conservative-bound |
| 3 clients r3 detail / writes | tm230-acceptance-gateway-1 | 47.797 | 0.033 / 0.111 | within-conservative-bound |
| 10 clients r3 overview / idle | tm230-acceptance-lab-1 | 181.531 | 0.008 / 0.050 | within-conservative-bound |
| 10 clients r3 overview / idle | tm230-acceptance-gateway-1 | 49.953 | 0.017 / 0.058 | within-conservative-bound |
| 10 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.859 | 0.867 / 0.911 | within-conservative-bound |
| 10 clients r3 overview / writes | tm230-acceptance-gateway-1 | 50.703 | 0.167 / 0.211 | within-conservative-bound |
| 10 clients r3 detail / idle | tm230-acceptance-lab-1 | 182.859 | 0.008 / 0.050 | within-conservative-bound |
| 10 clients r3 detail / idle | tm230-acceptance-gateway-1 | 50.766 | 0.017 / 0.050 | within-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.469 | 0.500 / 0.767 | within-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-gateway-1 | 51.594 | 0.156 / 0.267 | inconclusive-at-this-resolution |

## Limits

- Clients within each trial are correlated. Keep repetitions separate.
- Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.
- Screenshot completion is an upper capture bound, not physical presentation time.
- CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.
- Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.
- Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted.
