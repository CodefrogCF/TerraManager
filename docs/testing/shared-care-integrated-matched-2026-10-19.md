# Complete matched polling comparison and SSE follow-up

Date: 2026-10-19. Raspberry Pi 5 Model B / 4 GB, Linux aarch64, disposable
100-Animal / five-Box / 2,000-Feeding fixture. Production port 443 was not used.
The pinned .85 matrix and separate CPU-resolution capture are complete.
Resource budgets were accepted on 2026-10-19. The [final acceptance report](shared-care-integrated-acceptance-2026-10-21.md)
records the completed physical checks on 2026-10-21, including natural expiry
and renewed login. The S22 trusted-HTTPS exclusion remains explicit.

## Matched inputs

The pinned Chrome executable reports **155.0.8059.85** on both sides. Its
SHA-256 is `de999bce6a1c954df71a8f15bf751b336172f55ac1a0325bb0580cbc2121268c`.
The runner and all three observer/asset modules match byte-for-byte. Both runs
use the gateway release build, read diagnostics, the native semantics observer,
120-second idle windows, three writes in 30-second slots and six quiet seconds
between windows. Five clients use five independent browser contexts, distributed
over the same three caregiver accounts. They are logical clients on one Windows
controller, not five physical devices.

| Capture | UTC start / completion | Trials | Windows |
| --- | --- | ---: | ---: |
| [Pinned SSE, five clients](data/shared-care-integrated-sse-five-pinned-2026-10-18.json) | Oct 18 20:48:24.411 / 21:12:36.378 | 3 | 12 |
| [Pinned polling, 5/1/3/10 clients](data/shared-care-integrated-polling-pinned-2026-10-18.json) | Oct 18 21:28:41.111 / 23:05:58.018 | 12 | 48 |

The server stayed on integrated fixture image `2dee1f1`, immutable image ID
`sha256:de08a8c1549cc9fa05469e5a3d92bf44198c59e703b2527dddfa3f742633f73f`.
The operator-confirmed gateway switch at **21:25:06 UTC** changed only the web
service from SSE `2dee1f1`
(`sha256:b7151972b3c6acaa525376c7800274ca6eb011dc9eceb24acbd7a980cfee12cb`)
to polling `8e684ec`
(`sha256:8eaec74469eff42162da2affc98265234993b40a95084d97e008ab337732608a`).
The private switch record is `web-switch-20261018T212506Z.json`.

This is a batched mode comparison with time/order and warm-up confounds. The
same unchanged current API serves both client versions; this does not recreate
the entire historical server release. Do not infer causal per-mode RAM savings.

## Five-client targets, each repetition retained

The [strict comparison JSON](data/shared-care-integrated-matched-five-2026-10-19.json)
and [full table](data/shared-care-integrated-matched-five-2026-10-19.md) report
`fiveClientNumericalTargetsMet: true`, `requestOrPageErrorEvidenceOpen: false`
and **`requiredMatrixComplete: false`** for that original subset check. It
explicitly selects five clients. The completed matrix below adds the remaining
.85 scales; the earlier full .84 SSE matrix is not silently matched against .85.

| Repetition | View | Idle data GETs, SSE / polling | Idle body bytes, SSE / polling | Write capture p95 ms, SSE / polling |
| ---: | --- | ---: | ---: | ---: |
| 1 | Overview | 0 / 120 | 1,080 / 4,519,600 | 813 / 14,777 |
| 1 | Detail | 0 / 400 | 1,080 / 8,885,049 | 988 / 3,506 |
| 2 | Overview | 0 / 120 | 1,080 / 4,519,600 | 1,029 / 14,241 |
| 2 | Detail | 0 / 400 | 1,080 / 8,774,040 | 423 / 3,480 |
| 3 | Overview | 0 / 120 | 1,080 / 4,519,600 | 762 / 13,194 |
| 3 | Detail | 0 / 400 | 1,080 / 8,774,040 | 445 / 3,482 |

All six idle comparisons reduce data GET rates by **100%** and decoded body
byte rates by approximately **99.976% overview / 99.988% detail**, including SSE
upkeep. Rates use each measured wall duration. These are decoded response-body
bytes, excluding headers, TLS/TCP overhead and requests unrelated to the app.
Each SSE idle window includes 40 keepalive events across the five clients.

All 90 expected five-client SSE write observations matched the changed name
and changed decoded screenshot region. Each of the six per-trial/view capture
p95 values is below two seconds. These are screenshot-completion upper bounds,
not physical display-presentation measurements; correlated clients observing
the same write are not independent repetitions. The complete polling matrix
also matched all expected observations. Both captures have zero page errors
and zero final retained server streams in every trial.

The SSE five-client capture contains 92 terminal request events, the full polling
capture 3,225. Each has actual EOF/valid-JSON reader evidence and a matching-text
application JSON-parse observation. Identical simultaneously outstanding body
texts can make that correlation ambiguous; it is not a guarantee of unique
request identity. The earlier .84 capture's 26 unclassified `/changes` events
retain their original classification.

## Resources and coverage

The [published input manifest](data/shared-care-integrated-matched-inputs-2026-10-19.json)
records exact byte lengths and hashes after checking for private fixture
usernames, passwords and identity. The extended 17:48 resource snapshot has a
new filename; the previously published partial snapshot remains unchanged.

| Resource input | Samples | First / last sample UTC | SHA-256 |
| --- | ---: | --- | --- |
| [Complete 17:48 snapshot](data/shared-care-integrated-pi-resources-2026-10-18T174803Z-complete.jsonl) | 2,602 | Oct 18 17:48:15.599012 / 21:25:00.598737 | `f8bfe7020a2d4548335ee0b8270477e0dd23e3767476d8da76876c822a7c69bc` |
| [Polling snapshot](data/shared-care-integrated-pi-resources-2026-10-18T212506Z.jsonl) | 2,880 | Oct 18 21:25:18.774716 / Oct 19 01:25:13.774397 | `447a7ee297dbe3dd691b332ad3815ed2a6fdca3b13e898a5cd04ab35e22b93e6` |

There are no trailing partial records. Every measured SSE-five and polling
window has surrounding process/clock probes. Dart start ticks remain
`1104844068`; Caddy changes from `1104844086` to `1107210374` at the web switch.
The analyzer does not bridge those identities or add absolute counters.

For the pinned five-client SSE capture, all **12/12 Dart and 12/12 Caddy CPU
intervals** are within the proposed bounds. Maximum conservative upper bounds
across its idle windows are **0.041664 / 0.049996% of one core**, and across its
write windows **0.544409 / 0.166658%** (Dart / Caddy). Highest sampled RSS is
**182.453125 / 50.078125 MiB**, below the proposed 256 / 80 MiB limits. Each
process/window has at least 18 probes; maximum gaps are 6.021 / 6.038 seconds.

The [SSE resource summary](data/shared-care-integrated-sse-five-summary-2026-10-19.json)
and [tables](data/shared-care-integrated-sse-five-summary-2026-10-19.md) retain
the complete intervals and sample counts. The [polling summary](data/shared-care-integrated-polling-summary-2026-10-19.json)
and [tables](data/shared-care-integrated-polling-summary-2026-10-19.md) report the
old client's higher idle activity. SSE absolute CPU budgets are reference
values for that baseline, not polling acceptance requirements. RSS is sampled
PID 1 memory, excluding tmpfs, native devices and the Windows browser controller.

## Completed pinned .85 matrix

The [remaining raw SSE capture](data/shared-care-integrated-sse-scale-pinned-2026-10-19.json)
ran **Oct 19 07:31:33.706–08:43:54.054 UTC**, adding nine trials / 36 windows
at 1/3/10 clients. Its browser executable, four measurement modules, diagnostics,
native observer, write density and window plan match the five-client SSE and
full polling captures. All 252 expected new write observations matched the
changed name and screenshot region. Every trial ended with zero retained
streams; there were no page errors.

The [composed SSE input](data/shared-care-integrated-sse-combined-2026-10-19.json)
retains all original trial objects and timestamps, with both source hashes,
plans and time spans. It is a union of **12 trials / 48 windows / 342 write
observations**, not one continuous run. The actual batch order was five-client
SSE on Oct 18, full polling on Oct 18, then 1/3/10-client SSE on Oct 19. This
order and the overnight gap remain possible confounds.

The [complete comparison](data/shared-care-integrated-matched-full-2026-10-19.json)
and [tables](data/shared-care-integrated-matched-full-2026-10-19.md) now report:

- `requiredMatrixComplete: true`;
- `fiveClientNumericalTargetsMet: true`;
- `requestOrPageErrorEvidenceOpen: false` for these matched .85 captures.

| Clients | Overview capture p95 ms, repetitions 1 / 2 / 3 | Detail capture p95 ms, repetitions 1 / 2 / 3 |
| ---: | --- | --- |
| 1 | 799 / 364 / 317 | 265 / 305 / 284 |
| 3 | 719 / 431 / 559 | 952 / 390 / 362 |
| 5 | 813 / 1,029 / 762 | 988 / 423 / 445 |
| 10 | 1,871 / 1,424 / 1,873 | 1,178 / 991 / 1,402 |

Every SSE idle window has zero data GETs and eight keepalives / 216 decoded
body bytes per client per 120 seconds. All matched scales reduce idle data
GET rates by 100% and body-byte rates by at least 99.976%. The two-second
numerical acceptance target is specified for five clients; the other scales
are reported separately. The .85 SSE captures contain 295 terminal events,
all with the EOF/parse correlation described above; the old .84 evidence is
not reclassified.

### New resource snapshot and verified image switch

The [new resource snapshot](data/shared-care-integrated-pi-resources-2026-10-19T073107Z-scale.jsonl)
contains 1,026 samples, **07:31:19.383376–08:56:44.383083 UTC**, SHA-256
`ff9ca81056bc1f2b37c26a4b959a9e650e0bb8a11bd5d0d2d7076c794aba88f9`.
This is a copied snapshot of the ongoing four-hour collector, not its full
eventual duration. It covers every new scale window and surrounding probes,
with no trailing partial records. The [scale-input manifest](data/shared-care-integrated-scale-inputs-2026-10-19.json)
preserves all published source hashes.

The copied [polling switch record](data/shared-care-integrated-switch-polling-2026-10-18.json)
and [SSE switch record](data/shared-care-integrated-switch-sse-2026-10-19.json)
verify an uninterrupted lab container and an exact gateway/container/image
chain. SSE was restored at **07:31:07.014705 UTC**. Dart start ticks remain
`1104844068`; the new Caddy identity is `1110846440`.

The [combined resource summary](data/shared-care-integrated-sse-combined-summary-2026-10-19.json)
and [tables](data/shared-care-integrated-sse-combined-summary-2026-10-19.md) use
the complete 17:48 input and the new 07:31 snapshot, without bridging process
identities or adding absolute counters. Across all 48 .85 windows:

- Dart CPU: **48/48 within** the proposed conservative bounds.
- Caddy CPU: **45/48 within; three inconclusive**, all ten-client detail writes.
- Highest sampled RSS: **183.703125 MiB Dart / 51.296875 MiB Caddy**.
- New scale capture maximum probe gaps: 6.028 / 6.059 seconds; at least 18
  valid process probes per window.

The new ten-client detail-write Caddy intervals are **0.155528–0.277728%**,
**0.155538–0.266637%** and **0.155550–0.288879%** of one core (see raw summary
for exact values). They straddle the proposed 0.25% budget. This is a resolution
limit, not an established pass or exceedance.

### CPU-resolution follow-up

Keep the same ten clients, fixture, executable, modules and 30-second write
spacing. Extend ordinary write windows from three to **six writes / 180 seconds**,
with three repetitions in both views. The supplementary capture uses 30-second
idle setup windows and is **not** merged into the original matched matrix.
The longer active windows reduce endpoint/tick uncertainty without padding
them with additional idle time or raising the 0.25% threshold during the run.
The [completed resolution report](shared-care-integrated-cpu-resolution-2026-10-19.md)
now records all six active windows: Dart passes the original bound in six,
Caddy in five; one Caddy interval remains inconclusive at 0.199986–0.261092%.
It also retains the supplementary overview 2,449-ms p95. The operator accepted
the separate budget of 0.30% Caddy for ten clients on 2026-10-19, keeping 0.25%
through five clients. All compared upper bounds fit those accepted budgets;
the original intervals and classifications remain unchanged.

## Reproduction and remaining work

```bash
python3 tool/evaluation/shared_updates/analyze_integrated.py \
  docs/testing/data/shared-care-integrated-sse-five-pinned-2026-10-18.json \
  --resources docs/testing/data/shared-care-integrated-pi-resources-2026-10-18T174803Z-complete.jsonl \
  --output-prefix sse-five-summary
python3 tool/evaluation/shared_updates/analyze_integrated.py \
  docs/testing/data/shared-care-integrated-polling-pinned-2026-10-18.json \
  --resources docs/testing/data/shared-care-integrated-pi-resources-2026-10-18T212506Z.jsonl \
  --output-prefix polling-summary
python3 tool/evaluation/shared_updates/compare_integrated.py \
  docs/testing/data/shared-care-integrated-sse-five-pinned-2026-10-18.json \
  docs/testing/data/shared-care-integrated-polling-pinned-2026-10-18.json \
  --clients 5 --output-prefix matched-five
python3 tool/evaluation/shared_updates/combine_integrated.py \
  docs/testing/data/shared-care-integrated-sse-five-pinned-2026-10-18.json \
  docs/testing/data/shared-care-integrated-sse-scale-pinned-2026-10-19.json \
  --output combined.json
python3 tool/evaluation/shared_updates/compare_integrated.py \
  combined.json \
  docs/testing/data/shared-care-integrated-polling-pinned-2026-10-18.json \
  --output-prefix matched-full
```

Analyze the composed input with both resource files above to reproduce all 48
CPU/RSS windows. The test gateway is back on the verified current SSE image.
The separate CPU-resolution assessment and ADR resource-budget decision are
complete. The separate natural physical-session expiry and relogin outcome
was confirmed on 2026-10-21.

The [original .84 matrix](shared-care-integrated-sse-matrix-2026-10-18.md)
retains its five-client 2,494-ms outlier and its ten-client observations. The
original three inconclusive ten-client Caddy CPU intervals remain unchanged.
The [30-minute/118-reopen workload](shared-care-integrated-resources-2026-10-18.md)
and [instrumented frame probe](shared-care-integrated-frames-2026-10-18.md)
provide separate evidence. The [physical report](shared-care-integrated-physical-checks.md)
records the confirmed lifecycle/restore outcomes and S22 trusted-HTTPS exclusion.
Natural expiry, renewed login and resumed automatic updates were subsequently
confirmed on 2026-10-21, completing the scoped acceptance.
