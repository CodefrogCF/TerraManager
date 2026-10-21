# Matched integrated Flutter comparison

Required matrix complete: True; five-client numerical targets: True; request/page evidence open: False.

| Clients | Repetition | View | Workload | SSE / polling data GETs | SSE / polling body bytes | GET reduction % | Body reduction % | SSE / polling capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | detail | idle | 0 / 80 | 216 / 1754808 | 100.000 | 99.988 | - / - |
| 1 | 1 | detail | writes | 15 / 60 | 315894 / 1316106 | - | - | 265.000 / 3966.000 |
| 1 | 1 | overview | idle | 0 / 24 | 216 / 903920 | 100.000 | 99.976 | - / - |
| 1 | 1 | overview | writes | 9 / 18 | 341661 / 677940 | - | - | 799.000 / 2503.000 |
| 1 | 2 | detail | idle | 0 / 80 | 216 / 1754808 | 100.000 | 99.988 | - / - |
| 1 | 2 | detail | writes | 15 / 60 | 315894 / 1316106 | - | - | 305.000 / 4018.000 |
| 1 | 2 | overview | idle | 0 / 24 | 216 / 903920 | 100.000 | 99.976 | - / - |
| 1 | 2 | overview | writes | 9 / 18 | 341661 / 677940 | - | - | 364.000 / 2962.000 |
| 1 | 3 | detail | idle | 0 / 80 | 216 / 1754808 | 100.000 | 99.988 | - / - |
| 1 | 3 | detail | writes | 15 / 63 | 315894 / 1318087 | - | - | 284.000 / 4015.000 |
| 1 | 3 | overview | idle | 0 / 24 | 216 / 903920 | 100.000 | 99.976 | - / - |
| 1 | 3 | overview | writes | 9 / 18 | 341661 / 677940 | - | - | 317.000 / 2953.000 |
| 3 | 1 | detail | idle | 0 / 240 | 648 / 5264424 | 100.000 | 99.988 | - / - |
| 3 | 1 | detail | writes | 45 / 180 | 947682 / 3948318 | - | - | 952.000 / 3001.000 |
| 3 | 1 | overview | idle | 0 / 72 | 648 / 2711760 | 100.000 | 99.976 | - / - |
| 3 | 1 | overview | writes | 27 / 54 | 1024983 / 2033820 | - | - | 719.000 / 13670.000 |
| 3 | 2 | detail | idle | 0 / 240 | 648 / 5264424 | 100.000 | 99.988 | - / - |
| 3 | 2 | detail | writes | 45 / 180 | 947682 / 3948318 | - | - | 390.000 / 3974.000 |
| 3 | 2 | overview | idle | 0 / 72 | 648 / 2711760 | 100.000 | 99.976 | - / - |
| 3 | 2 | overview | writes | 27 / 54 | 1024983 / 2033820 | - | - | 431.000 / 14209.000 |
| 3 | 3 | detail | idle | 0 / 240 | 648 / 5264424 | 100.000 | 99.988 | - / - |
| 3 | 3 | detail | writes | 45 / 180 | 947682 / 3948318 | - | - | 362.000 / 4112.000 |
| 3 | 3 | overview | idle | 0 / 72 | 648 / 2711760 | 100.000 | 99.976 | - / - |
| 3 | 3 | overview | writes | 27 / 54 | 1024983 / 2033820 | - | - | 559.000 / 14162.000 |
| 5 | 1 | detail | idle | 0 / 400 | 1080 / 8885049 | 100.000 | 99.988 | - / - |
| 5 | 1 | detail | writes | 75 / 300 | 1579470 / 6580530 | - | - | 988.000 / 3506.000 |
| 5 | 1 | overview | idle | 0 / 120 | 1080 / 4519600 | 100.000 | 99.976 | - / - |
| 5 | 1 | overview | writes | 45 / 90 | 1708305 / 3389700 | - | - | 813.000 / 14777.000 |
| 5 | 2 | detail | idle | 0 / 400 | 1080 / 8774040 | 100.000 | 99.988 | - / - |
| 5 | 2 | detail | writes | 75 / 300 | 1579470 / 6580530 | - | - | 423.000 / 3480.000 |
| 5 | 2 | overview | idle | 0 / 120 | 1080 / 4519600 | 100.000 | 99.976 | - / - |
| 5 | 2 | overview | writes | 45 / 90 | 1708305 / 3389700 | - | - | 1029.000 / 14241.000 |
| 5 | 3 | detail | idle | 0 / 400 | 1080 / 8774040 | 100.000 | 99.988 | - / - |
| 5 | 3 | detail | writes | 75 / 300 | 1579470 / 6580530 | - | - | 445.000 / 3482.000 |
| 5 | 3 | overview | idle | 0 / 120 | 1080 / 4519600 | 100.000 | 99.976 | - / - |
| 5 | 3 | overview | writes | 45 / 90 | 1708305 / 3389700 | - | - | 762.000 / 13194.000 |
| 10 | 1 | detail | idle | 0 / 803 | 2160 / 17661070 | 100.000 | 99.988 | - / - |
| 10 | 1 | detail | writes | 150 / 609 | 3158940 / 13268410 | - | - | 1178.000 / 15315.000 |
| 10 | 1 | overview | idle | 0 / 240 | 2160 / 9039200 | 100.000 | 99.976 | - / - |
| 10 | 1 | overview | writes | 90 / 183 | 3416610 / 6892390 | - | - | 1871.000 / 15075.000 |
| 10 | 2 | detail | idle | 0 / 800 | 2160 / 17548080 | 100.000 | 99.988 | - / - |
| 10 | 2 | detail | writes | 150 / 601 | 3158940 / 13229709 | - | - | 991.000 / 15293.000 |
| 10 | 2 | overview | idle | 0 / 240 | 2160 / 9039200 | 100.000 | 99.976 | - / - |
| 10 | 2 | overview | writes | 90 / 180 | 3416610 / 6779400 | - | - | 1424.000 / 14782.000 |
| 10 | 3 | detail | idle | 0 / 800 | 2160 / 17548080 | 100.000 | 99.988 | - / - |
| 10 | 3 | detail | writes | 150 / 614 | 3158940 / 13383359 | - | - | 1402.000 / 15106.000 |
| 10 | 3 | overview | idle | 0 / 240 | 2160 / 9039200 | 100.000 | 99.976 | - / - |
| 10 | 3 | overview | writes | 90 / 180 | 3416610 / 6779400 | - | - | 1873.000 / 14370.000 |

## Limits

- Numerical targets are not overall issue acceptance: resource bounds, rendering, physical lifecycle and the soak are separate.
- Each repetition stays separate; clients observing the same write are correlated.
- Body-byte rates include stream upkeep/fallback/resync but exclude headers, TLS/TCP and other wire overhead.
- Capture p95 is an upper bound after semantics/two animation callbacks, not physical presentation time.
- Unclassified terminal events remain open even if UI values and numerical targets succeed.
- Exact image identities and experiment mode order need their separate provenance record.
- Separate transport batches have time/order and warm-up confounds; consult composition/switch timestamps. No per-mode RAM saving follows from this comparison.
