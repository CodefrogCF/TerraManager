# Shared Care update evaluation and acceptance

Issues #186 and #226-#230; integrated acceptance completed **2026-10-21** within
the fixture, accepted budgets and browser scope below. This does not assert a
current GitHub issue state. [ADR-037](../architecture-decisions.md#adr-037-evaluate-versioned-shared-care-invalidation-and-sse-delivery)
compares polling, conditional polling, long polling, SSE and WebSockets.
The [change contract](../shared-care-change-contract.md) defines implementation.

## Requirements and outcomes

| Requirement | Evidence |
| --- | --- |
| Requests, latency, traffic and Pi resources | Same integrated API/fixture, polling and SSE Web release clients, trusted Caddy HTTPS; 1/3/5/10 logical clients, three repetitions, overview/detail and idle/write workloads: 12 trials / 48 windows per mode. |
| Targeted refresh | Authoritative affected-resource reads, unchanged-picture reuse, clock-driven due state; drafts/navigation preserved without browser reload. |
| Reliability and access | Foreground propagation, mobile background/resume and network recovery, two tabs, stale edits, uncertain disconnected saves, account revocation, rejected/successful restore, natural 12-hour expiry and renewed login/update flow operator-confirmed. |
| Resource cleanup | 30-minute soak completed 118 reopen cycles; no page errors, maximum five streams and zero retained at end. Warm median RSS stable for Dart and about +0.400% for Caddy. Bounded writers/replay also covered by source/tests. |
| Ownership/permissions | Existing cookie/origin/CSRF/role/conflict checks retained; no browser collection database, cloud dependency or new native permission. |

## Measured performance

Raspberry Pi 5 B / 4 GB, ARM64; 100 Animals, five Boxes, 2,000 Feedings. Integrated
API/SSE Web image revision `2dee1f1`; comparison polling Web `8e684ec`. The current
API served both. Pinned matched captures used Chrome 155.0.8059.85; the earlier
.84 matrix remains separate evidence in the archive.

| Five-client measurement | Polling | SSE |
| --- | ---: | ---: |
| Overview idle data GETs/min/client | 12 | 0 |
| Detail-stack idle data GETs/min/client | 40 | 0 |
| Idle decoded API-body reduction | Baseline | At least 99.976%, including keepalives |
| Per-repetition/view write capture p95 | Overview 13,194-14,777 ms; detail 3,480-3,506 ms | 423-1,029 ms, below the two-second target |

All **342 expected SSE write observations** in the matched matrix displayed
the changed value and capture region. Capture completion is a latency upper
bound, not physical display timing. Body bytes exclude headers/TLS/TCP; frame
elapsed time is not CPU/GPU use. Batched mode order does not prove causal RAM
savings. Preserve original outliers/classifications in the archived data.

### Accepted process budgets

CPU is percent of one core; RSS is sampled process memory, not instantaneous
peak, container/tmpfs or client-device memory.

| Condition | Dart | Caddy |
| --- | ---: | ---: |
| Primary idle, 1/3/5/10 clients | 0.10% | 0.10% |
| Writes, 1/3/5 clients | 1.50% | 0.25% |
| Writes, 10 clients | 1.50% | 0.30% |
| Sampled RSS | 256 MiB | 80 MiB |

All 108 main/supplementary active CPU upper bounds fit the accepted limits.
Main-matrix RSS maxima were 183.70 / 51.30 MiB; longer-window follow-up maxima
183.16 / 52.64 MiB (Dart/Caddy). The operator accepted 0.30% for ten-client Caddy
writes on 2026-10-19; the former 0.25% classifications remain unchanged. Three
original 90-second intervals and one supplementary 180-second interval were
inconclusive against that original threshold. Setup-only idle windows are not
primary idle acceptance. Maximum ten-client conservative bound was 0.289%.

## Physical-browser scope

S25 Ultra / Android 16 / Brave 1.97.57 and Windows 11 Chrome, Firefox and Edge
were reported warning-free and passed their requested functional checks.
Mobile network recovery was estimated around ten seconds; it is not a percentile.
Natural twelve-hour expiry displayed sign-in without manual reload; renewed login
and automatic updates worked afterward.

**S22 Firefox is excluded from trusted-HTTPS acceptance:** the local CA was absent
and a certificate warning was bypassed. Earlier functional observations do not
convert that into a trusted-HTTPS pass. Unused browser/device combinations are
not implied by the inventory. Restore outcomes were confirmed collectively;
exact messages and separate reload/login details were not recorded.

## Repeat the essential checks

Use disposable data and the isolated port-8443 stack, separate from production.
Test/production on the same host need separate browser profiles: cookies are
not isolated by port. Trust the public LAN CA; do not bypass TLS verification.

```sh
bash tool/evaluation/shared_updates/prepare_integrated_pi.sh
bash tool/evaluation/shared_updates/start_integrated_capture.sh
```

Keep generated fixture credentials private and recopy them after recreation.
Run from a controller with Node/Playwright and an installed Chrome channel:

```sh
node tool/evaluation/shared_updates/integrated_benchmark.cjs \
  --credentials /private/credentials.json --output /private/sse.json \
  --clients 1,3,5,10 --repetitions 3 --seconds 120 --writes 3 --channel chrome
```

Use the identical fixture/browser/workload and a verified pre-SSE Web image for
`--mode polling`. Record image identities; collect process CPU/RSS over all
windows without crossing restarts. The sampler uses `/proc` because this Pi's
Docker reported `MemoryLimit=false`. Fallback acceptance requires one conditional
read per 15 seconds and no data polling while SSE is healthy.

On actual browsers, check propagation, background/reconnect, drafts/conflicts,
uncertain writes, account revocation, safety-grant restore and natural expiry.
Keep workload metrics separate from device observations. Raw sanitized inputs,
original classifications and analysis commands are in the
[measurement archive](../../tool/evaluation/shared_updates/results/README.md).
