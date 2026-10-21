# Matched integrated Flutter comparison

Required matrix complete: False; five-client numerical targets: True; request/page evidence open: False.

| Clients | Repetition | View | Workload | SSE / polling data GETs | SSE / polling body bytes | GET reduction % | Body reduction % | SSE / polling capture p95 ms |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
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

## Limits

- Numerical targets are not overall issue acceptance: resource bounds, rendering, physical lifecycle and the soak are separate.
- Each repetition stays separate; clients observing the same write are correlated.
- Body-byte rates include stream upkeep/fallback/resync but exclude headers, TLS/TCP and other wire overhead.
- Capture p95 is an upper bound after semantics/two animation callbacks, not physical presentation time.
- Unclassified terminal events remain open even if UI values and numerical targets succeed.
- Exact image identities and experiment mode order need their separate provenance record.
- Batched SSE then polling has a time/order confound; no per-mode RAM saving follows from this comparison.
