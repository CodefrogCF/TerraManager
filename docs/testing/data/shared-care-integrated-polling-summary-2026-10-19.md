# Integrated Flutter measurement windows

Capture: complete; browser: 155.0.8059.85; mode: polling; read diagnostics: reads.

| Clients | Repetition | View | Workload | Data GETs | Body bytes | Upkeep | Terminal / proven consumed | Capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 5 | 1 | overview | idle | 120 | 4519600 | 0 | 67 / 67 | - |
| 5 | 1 | overview | writes | 90 | 3389700 | 0 | 44 / 44 | 14777 |
| 5 | 1 | detail | idle | 400 | 8885049 | 0 | 117 / 117 | - |
| 5 | 1 | detail | writes | 300 | 6580530 | 0 | 73 / 73 | 3506 |
| 1 | 1 | overview | idle | 24 | 903920 | 0 | 10 / 10 | - |
| 1 | 1 | overview | writes | 18 | 677940 | 0 | 8 / 8 | 2503 |
| 1 | 1 | detail | idle | 80 | 1754808 | 0 | 28 / 28 | - |
| 1 | 1 | detail | writes | 60 | 1316106 | 0 | 15 / 15 | 3966 |
| 3 | 1 | overview | idle | 72 | 2711760 | 0 | 27 / 27 | - |
| 3 | 1 | overview | writes | 54 | 2033820 | 0 | 29 / 29 | 13670 |
| 3 | 1 | detail | idle | 240 | 5264424 | 0 | 55 / 55 | - |
| 3 | 1 | detail | writes | 180 | 3948318 | 0 | 35 / 35 | 3001 |
| 10 | 1 | overview | idle | 240 | 9039200 | 0 | 99 / 99 | - |
| 10 | 1 | overview | writes | 183 | 6892390 | 0 | 70 / 70 | 15075 |
| 10 | 1 | detail | idle | 803 | 17661070 | 0 | 199 / 199 | - |
| 10 | 1 | detail | writes | 609 | 13268410 | 0 | 169 / 169 | 15315 |
| 5 | 2 | overview | idle | 120 | 4519600 | 0 | 71 / 71 | - |
| 5 | 2 | overview | writes | 90 | 3389700 | 0 | 55 / 55 | 14241 |
| 5 | 2 | detail | idle | 400 | 8774040 | 0 | 162 / 162 | - |
| 5 | 2 | detail | writes | 300 | 6580530 | 0 | 96 / 96 | 3480 |
| 1 | 2 | overview | idle | 24 | 903920 | 0 | 10 / 10 | - |
| 1 | 2 | overview | writes | 18 | 677940 | 0 | 8 / 8 | 2962 |
| 1 | 2 | detail | idle | 80 | 1754808 | 0 | 20 / 20 | - |
| 1 | 2 | detail | writes | 60 | 1316106 | 0 | 17 / 17 | 4018 |
| 3 | 2 | overview | idle | 72 | 2711760 | 0 | 33 / 33 | - |
| 3 | 2 | overview | writes | 54 | 2033820 | 0 | 22 / 22 | 14209 |
| 3 | 2 | detail | idle | 240 | 5264424 | 0 | 62 / 62 | - |
| 3 | 2 | detail | writes | 180 | 3948318 | 0 | 51 / 51 | 3974 |
| 10 | 2 | overview | idle | 240 | 9039200 | 0 | 114 / 114 | - |
| 10 | 2 | overview | writes | 180 | 6779400 | 0 | 79 / 79 | 14782 |
| 10 | 2 | detail | idle | 800 | 17548080 | 0 | 210 / 210 | - |
| 10 | 2 | detail | writes | 601 | 13229709 | 0 | 161 / 161 | 15293 |
| 5 | 3 | overview | idle | 120 | 4519600 | 0 | 56 / 56 | - |
| 5 | 3 | overview | writes | 90 | 3389700 | 0 | 45 / 45 | 13194 |
| 5 | 3 | detail | idle | 400 | 8774040 | 0 | 108 / 108 | - |
| 5 | 3 | detail | writes | 300 | 6580530 | 0 | 78 / 78 | 3482 |
| 1 | 3 | overview | idle | 24 | 903920 | 0 | 12 / 12 | - |
| 1 | 3 | overview | writes | 18 | 677940 | 0 | 10 / 10 | 2953 |
| 1 | 3 | detail | idle | 80 | 1754808 | 0 | 21 / 21 | - |
| 1 | 3 | detail | writes | 63 | 1318087 | 0 | 13 / 13 | 4015 |
| 3 | 3 | overview | idle | 72 | 2711760 | 0 | 29 / 29 | - |
| 3 | 3 | overview | writes | 54 | 2033820 | 0 | 21 / 21 | 14162 |
| 3 | 3 | detail | idle | 240 | 5264424 | 0 | 58 / 58 | - |
| 3 | 3 | detail | writes | 180 | 3948318 | 0 | 46 / 46 | 4112 |
| 10 | 3 | overview | idle | 240 | 9039200 | 0 | 109 / 109 | - |
| 10 | 3 | overview | writes | 180 | 6779400 | 0 | 66 / 66 | 14370 |
| 10 | 3 | detail | idle | 800 | 17548080 | 0 | 200 / 200 | - |
| 10 | 3 | detail | writes | 614 | 13383359 | 0 | 137 / 137 | 15106 |

## Process observations

CPU intervals use whole-window bounds. Inconclusive is not a failure or a pass.

| View / workload | Process | RSS max MiB | CPU lower / upper % of one core | Proposed CPU budget |
| --- | --- | ---: | ---: | --- |
| 5 clients r1 overview / idle | tm230-acceptance-lab-1 | 182.109 | 0.958 / 1.092 | exceeds-conservative-bound |
| 5 clients r1 overview / idle | tm230-acceptance-gateway-1 | 46.281 | 0.117 / 0.158 | exceeds-conservative-bound |
| 5 clients r1 overview / writes | tm230-acceptance-lab-1 | 182.000 | 0.989 / 1.167 | within-conservative-bound |
| 5 clients r1 overview / writes | tm230-acceptance-gateway-1 | 47.141 | 0.122 / 0.178 | within-conservative-bound |
| 5 clients r1 detail / idle | tm230-acceptance-lab-1 | 182.000 | 1.883 / 2.042 | exceeds-conservative-bound |
| 5 clients r1 detail / idle | tm230-acceptance-gateway-1 | 48.875 | 0.367 / 0.425 | exceeds-conservative-bound |
| 5 clients r1 detail / writes | tm230-acceptance-lab-1 | 181.516 | 1.767 / 2.200 | exceeds-conservative-bound |
| 5 clients r1 detail / writes | tm230-acceptance-gateway-1 | 49.078 | 0.311 / 0.467 | exceeds-conservative-bound |
| 1 clients r1 overview / idle | tm230-acceptance-lab-1 | 182.000 | 0.175 / 0.208 | exceeds-conservative-bound |
| 1 clients r1 overview / idle | tm230-acceptance-gateway-1 | 49.172 | 0.008 / 0.050 | within-conservative-bound |
| 1 clients r1 overview / writes | tm230-acceptance-lab-1 | 181.391 | 0.122 / 0.256 | within-conservative-bound |
| 1 clients r1 overview / writes | tm230-acceptance-gateway-1 | 46.672 | 0.000 / 0.067 | within-conservative-bound |
| 1 clients r1 detail / idle | tm230-acceptance-lab-1 | 181.516 | 0.367 / 0.400 | exceeds-conservative-bound |
| 1 clients r1 detail / idle | tm230-acceptance-gateway-1 | 46.672 | 0.067 / 0.100 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-lab-1 | 182.000 | 0.333 / 0.467 | within-conservative-bound |
| 1 clients r1 detail / writes | tm230-acceptance-gateway-1 | 47.047 | 0.056 / 0.122 | within-conservative-bound |
| 3 clients r1 overview / idle | tm230-acceptance-lab-1 | 182.109 | 0.567 / 0.658 | exceeds-conservative-bound |
| 3 clients r1 overview / idle | tm230-acceptance-gateway-1 | 48.234 | 0.067 / 0.100 | within-conservative-bound |
| 3 clients r1 overview / writes | tm230-acceptance-lab-1 | 182.109 | 0.567 / 0.722 | within-conservative-bound |
| 3 clients r1 overview / writes | tm230-acceptance-gateway-1 | 47.000 | 0.056 / 0.111 | within-conservative-bound |
| 3 clients r1 detail / idle | tm230-acceptance-lab-1 | 182.109 | 1.167 / 1.258 | exceeds-conservative-bound |
| 3 clients r1 detail / idle | tm230-acceptance-gateway-1 | 49.188 | 0.233 / 0.275 | exceeds-conservative-bound |
| 3 clients r1 detail / writes | tm230-acceptance-lab-1 | 182.000 | 1.078 / 1.378 | within-conservative-bound |
| 3 clients r1 detail / writes | tm230-acceptance-gateway-1 | 49.219 | 0.189 / 0.300 | inconclusive-at-this-resolution |
| 10 clients r1 overview / idle | tm230-acceptance-lab-1 | 182.000 | 1.983 / 2.092 | exceeds-conservative-bound |
| 10 clients r1 overview / idle | tm230-acceptance-gateway-1 | 49.938 | 0.242 / 0.283 | exceeds-conservative-bound |
| 10 clients r1 overview / writes | tm230-acceptance-lab-1 | 182.000 | 1.878 / 2.278 | exceeds-conservative-bound |
| 10 clients r1 overview / writes | tm230-acceptance-gateway-1 | 50.203 | 0.222 / 0.311 | inconclusive-at-this-resolution |
| 10 clients r1 detail / idle | tm230-acceptance-lab-1 | 181.781 | 3.750 / 3.983 | exceeds-conservative-bound |
| 10 clients r1 detail / idle | tm230-acceptance-gateway-1 | 50.734 | 0.733 / 0.808 | exceeds-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-lab-1 | 181.672 | 3.522 / 4.333 | exceeds-conservative-bound |
| 10 clients r1 detail / writes | tm230-acceptance-gateway-1 | 50.891 | 0.700 / 0.911 | exceeds-conservative-bound |
| 5 clients r2 overview / idle | tm230-acceptance-lab-1 | 181.812 | 1.008 / 1.083 | exceeds-conservative-bound |
| 5 clients r2 overview / idle | tm230-acceptance-gateway-1 | 50.406 | 0.117 / 0.150 | exceeds-conservative-bound |
| 5 clients r2 overview / writes | tm230-acceptance-lab-1 | 182.000 | 0.933 / 1.200 | within-conservative-bound |
| 5 clients r2 overview / writes | tm230-acceptance-gateway-1 | 49.797 | 0.089 / 0.167 | within-conservative-bound |
| 5 clients r2 detail / idle | tm230-acceptance-lab-1 | 182.109 | 1.867 / 2.067 | exceeds-conservative-bound |
| 5 clients r2 detail / idle | tm230-acceptance-gateway-1 | 50.000 | 0.358 / 0.417 | exceeds-conservative-bound |
| 5 clients r2 detail / writes | tm230-acceptance-lab-1 | 181.625 | 1.844 / 2.133 | exceeds-conservative-bound |
| 5 clients r2 detail / writes | tm230-acceptance-gateway-1 | 50.031 | 0.344 / 0.444 | exceeds-conservative-bound |
| 1 clients r2 overview / idle | tm230-acceptance-lab-1 | 182.000 | 0.192 / 0.225 | exceeds-conservative-bound |
| 1 clients r2 overview / idle | tm230-acceptance-gateway-1 | 50.031 | 0.008 / 0.050 | within-conservative-bound |
| 1 clients r2 overview / writes | tm230-acceptance-lab-1 | 182.000 | 0.178 / 0.300 | within-conservative-bound |
| 1 clients r2 overview / writes | tm230-acceptance-gateway-1 | 48.641 | 0.011 / 0.067 | within-conservative-bound |
| 1 clients r2 detail / idle | tm230-acceptance-lab-1 | 182.000 | 0.383 / 0.417 | exceeds-conservative-bound |
| 1 clients r2 detail / idle | tm230-acceptance-gateway-1 | 47.797 | 0.075 / 0.108 | inconclusive-at-this-resolution |
| 1 clients r2 detail / writes | tm230-acceptance-lab-1 | 182.000 | 0.367 / 0.489 | within-conservative-bound |
| 1 clients r2 detail / writes | tm230-acceptance-gateway-1 | 47.906 | 0.056 / 0.122 | within-conservative-bound |
| 3 clients r2 overview / idle | tm230-acceptance-lab-1 | 181.625 | 0.592 / 0.667 | exceeds-conservative-bound |
| 3 clients r2 overview / idle | tm230-acceptance-gateway-1 | 49.047 | 0.067 / 0.100 | within-conservative-bound |
| 3 clients r2 overview / writes | tm230-acceptance-lab-1 | 181.609 | 0.578 / 0.711 | within-conservative-bound |
| 3 clients r2 overview / writes | tm230-acceptance-gateway-1 | 48.062 | 0.067 / 0.122 | within-conservative-bound |
| 3 clients r2 detail / idle | tm230-acceptance-lab-1 | 181.516 | 1.150 / 1.225 | exceeds-conservative-bound |
| 3 clients r2 detail / idle | tm230-acceptance-gateway-1 | 49.984 | 0.217 / 0.267 | exceeds-conservative-bound |
| 3 clients r2 detail / writes | tm230-acceptance-lab-1 | 182.000 | 1.078 / 1.255 | within-conservative-bound |
| 3 clients r2 detail / writes | tm230-acceptance-gateway-1 | 50.000 | 0.200 / 0.278 | inconclusive-at-this-resolution |
| 10 clients r2 overview / idle | tm230-acceptance-lab-1 | 181.781 | 1.983 / 2.233 | exceeds-conservative-bound |
| 10 clients r2 overview / idle | tm230-acceptance-gateway-1 | 50.234 | 0.242 / 0.300 | exceeds-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-lab-1 | 181.672 | 1.967 / 2.233 | exceeds-conservative-bound |
| 10 clients r2 overview / writes | tm230-acceptance-gateway-1 | 50.578 | 0.233 / 0.300 | inconclusive-at-this-resolution |
| 10 clients r2 detail / idle | tm230-acceptance-lab-1 | 181.781 | 3.833 / 3.991 | exceeds-conservative-bound |
| 10 clients r2 detail / idle | tm230-acceptance-gateway-1 | 50.719 | 0.742 / 0.800 | exceeds-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-lab-1 | 181.891 | 3.511 / 4.467 | exceeds-conservative-bound |
| 10 clients r2 detail / writes | tm230-acceptance-gateway-1 | 51.141 | 0.656 / 0.911 | exceeds-conservative-bound |
| 5 clients r3 overview / idle | tm230-acceptance-lab-1 | 182.000 | 0.958 / 1.100 | exceeds-conservative-bound |
| 5 clients r3 overview / idle | tm230-acceptance-gateway-1 | 49.844 | 0.108 / 0.158 | exceeds-conservative-bound |
| 5 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.000 | 0.978 / 1.156 | within-conservative-bound |
| 5 clients r3 overview / writes | tm230-acceptance-gateway-1 | 49.844 | 0.111 / 0.167 | within-conservative-bound |
| 5 clients r3 detail / idle | tm230-acceptance-lab-1 | 181.781 | 1.825 / 2.050 | exceeds-conservative-bound |
| 5 clients r3 detail / idle | tm230-acceptance-gateway-1 | 50.281 | 0.358 / 0.408 | exceeds-conservative-bound |
| 5 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.000 | 1.878 / 2.266 | exceeds-conservative-bound |
| 5 clients r3 detail / writes | tm230-acceptance-gateway-1 | 50.281 | 0.344 / 0.478 | exceeds-conservative-bound |
| 1 clients r3 overview / idle | tm230-acceptance-lab-1 | 182.500 | 0.192 / 0.225 | exceeds-conservative-bound |
| 1 clients r3 overview / idle | tm230-acceptance-gateway-1 | 50.344 | 0.017 / 0.050 | within-conservative-bound |
| 1 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.000 | 0.211 / 0.267 | within-conservative-bound |
| 1 clients r3 overview / writes | tm230-acceptance-gateway-1 | 47.375 | 0.022 / 0.067 | within-conservative-bound |
| 1 clients r3 detail / idle | tm230-acceptance-lab-1 | 182.000 | 0.392 / 0.425 | exceeds-conservative-bound |
| 1 clients r3 detail / idle | tm230-acceptance-gateway-1 | 48.031 | 0.067 / 0.108 | inconclusive-at-this-resolution |
| 1 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.109 | 0.344 / 0.467 | within-conservative-bound |
| 1 clients r3 detail / writes | tm230-acceptance-gateway-1 | 48.156 | 0.067 / 0.122 | within-conservative-bound |
| 3 clients r3 overview / idle | tm230-acceptance-lab-1 | 182.000 | 0.600 / 0.683 | exceeds-conservative-bound |
| 3 clients r3 overview / idle | tm230-acceptance-gateway-1 | 49.125 | 0.067 / 0.100 | within-conservative-bound |
| 3 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.000 | 0.589 / 0.700 | within-conservative-bound |
| 3 clients r3 overview / writes | tm230-acceptance-gateway-1 | 48.141 | 0.056 / 0.111 | within-conservative-bound |
| 3 clients r3 detail / idle | tm230-acceptance-lab-1 | 182.109 | 1.158 / 1.250 | exceeds-conservative-bound |
| 3 clients r3 detail / idle | tm230-acceptance-gateway-1 | 49.844 | 0.208 / 0.258 | exceeds-conservative-bound |
| 3 clients r3 detail / writes | tm230-acceptance-lab-1 | 181.891 | 1.089 / 1.389 | within-conservative-bound |
| 3 clients r3 detail / writes | tm230-acceptance-gateway-1 | 49.844 | 0.189 / 0.300 | inconclusive-at-this-resolution |
| 10 clients r3 overview / idle | tm230-acceptance-lab-1 | 182.000 | 1.925 / 2.158 | exceeds-conservative-bound |
| 10 clients r3 overview / idle | tm230-acceptance-gateway-1 | 50.328 | 0.225 / 0.292 | exceeds-conservative-bound |
| 10 clients r3 overview / writes | tm230-acceptance-lab-1 | 182.109 | 2.000 / 2.189 | exceeds-conservative-bound |
| 10 clients r3 overview / writes | tm230-acceptance-gateway-1 | 50.734 | 0.244 / 0.311 | inconclusive-at-this-resolution |
| 10 clients r3 detail / idle | tm230-acceptance-lab-1 | 182.109 | 3.850 / 4.100 | exceeds-conservative-bound |
| 10 clients r3 detail / idle | tm230-acceptance-gateway-1 | 51.234 | 0.750 / 0.817 | exceeds-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-lab-1 | 182.109 | 3.511 / 4.278 | exceeds-conservative-bound |
| 10 clients r3 detail / writes | tm230-acceptance-gateway-1 | 51.234 | 0.656 / 0.867 | exceeds-conservative-bound |

## Limits

- Clients within each trial are correlated. Keep repetitions separate.
- Decoded body bytes include SSE upkeep, resync and fallback, not headers or TLS/TCP wire overhead.
- Screenshot completion is an upper capture bound, not physical presentation time.
- CPU uses surrounding/inside probes and two rounding ticks. Do not call inner-span zero the whole-window load.
- Without before/after clock probes, zero offset plus the explicit guard is only a provisional assumption.
- Sampled RSS is not instantaneous peak or container/tmpfs memory; proposed budgets are not automatically accepted.
