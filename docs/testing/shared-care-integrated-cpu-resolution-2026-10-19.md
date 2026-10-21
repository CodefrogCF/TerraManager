# Ten-client CPU resolution and budget review

Date: 2026-10-19. Raspberry Pi 5 B / 4 GB, the unchanged integrated fixture and
gateway release images. This supplements the [matched .85 matrix](shared-care-integrated-matched-2026-10-19.md).
The automated captures are complete. The operator accepted the scale-specific
resource budgets on 2026-10-19. Physical expiry/relogin checks completed on
2026-10-21; see the [final acceptance report](shared-care-integrated-acceptance-2026-10-21.md).
S22 Firefox remains explicitly excluded from trusted HTTPS acceptance.

## Workload and provenance

The [raw capture](data/shared-care-integrated-sse-cpu-resolution-2026-10-19.json)
ran **08:58:55.116–09:24:35.742 UTC**. Ten independent browser contexts observed
six synthetic Animal-name writes, spaced 30 seconds apart, per overview/detail
window. Each active window lasted 180.003–180.013 seconds; there were three
repetitions. The 30-second idle windows are setup, not replacements for the
main matrix's 120-second idle windows. This plan is not merged into the matched
matrix or its latency percentiles.

The pinned Chrome executable (.85), all four measurement-module hashes,
diagnostics, native observer, current gateway artifact and server fixture match
the preceding SSE scale capture. Dart and Caddy retain start ticks `1104844068`
and `1110846440`. The controller also performed evidence publication/document
work during this supplementary run; it was not a dedicated latency controller.
That does not establish a cause for any individual slow observation.

All **360** expected write observations matched the new value and changed
screenshot region. There were zero page errors and zero final streams in every
trial. The 274 terminal request events have actual EOF/valid-JSON reader evidence
and matching-text application parse observations, with the same identical-body
correlation limitation as the primary captures.

## Resource coverage

The [updated resource snapshot](data/shared-care-integrated-pi-resources-2026-10-19T073107Z-cpu.jsonl)
contains **1,394 samples**, **07:31:19.383376–09:27:24.383085 UTC**, SHA-256
`299aeda755888672babd62e94606850746c7beed255bc9e1f00e0873b69c5c7a`.
It is a copied snapshot of the ongoing collector. The earlier `-scale.jsonl`
snapshot remains unchanged. No partial trailing records occur. All active
windows have surrounding clock/process probes and at least 36 process samples.
Maximum gaps are 6.016 seconds Dart / 6.048 seconds Caddy.

Highest sampled RSS: **183.156250 MiB Dart / 52.640625 MiB Caddy**, below the
proposed 256 / 80 MiB limits. These are sampled process values, excluding tmpfs,
the Windows controller and native devices; they do not establish continuous
memory peaks or per-mode savings.

## Original proposed CPU limits

The [summary JSON](data/shared-care-integrated-sse-cpu-resolution-summary-2026-10-19.json),
[tables](data/shared-care-integrated-sse-cpu-resolution-summary-2026-10-19.md) and
[active-window assessment](data/shared-care-integrated-sse-cpu-resolution-assessment-2026-10-19.json)
retain the original 1.50 / 0.25% of one core limits. All six Dart active windows
are within 1.50%; five of six Caddy active windows are within 0.25%.
**One remains inconclusive.** There is no established exceedance of 0.25%, and
the value is not confirmed in every repetition.

| Repetition | View | Dart CPU lower–upper % of one core | Caddy CPU lower–upper % | Original Caddy 0.25% status | Capture p95 ms |
| ---: | --- | --- | --- | --- | ---: |
| 1 | Overview | 0.777765–0.949984 | 0.149998–0.205552 | Within | 2,449 |
| 1 | Detail | 0.616646–0.766641 | 0.183327–0.244436 | Within | 1,231 |
| 2 | Overview | 0.772188–0.944402 | 0.155549–0.205546 | Within | 1,662 |
| 2 | Detail | 0.616622–0.772166 | 0.188875–0.249982 | Within, very close | 1,036 |
| 3 | Overview | 0.766645–0.949974 | 0.149996–0.205550 | Within | 1,644 |
| 3 | Detail | 0.655508–0.805497 | 0.199986–0.261092 | Inconclusive | 1,119 |

The 2,449-ms overview result is retained. The two-second numerical target is
specified for five clients; this supplementary ten-client result neither
replaces nor disappears into the primary latency comparison. No new five-client
test is inferred from it. The original 90-second Caddy intervals also retain
their inconclusive classifications.

## Accepted resource budgets (operator decision, 2026-10-19)

The original same-limit-at-every-scale proposal is too tight to confirm at ten
clients with this five-second / 100-Hz process-counter method. The operator
explicitly accepted the following scale-specific engineering budgets. Original
intervals and their original classifications are retained:

| Condition | Dart | Caddy |
| --- | ---: | ---: |
| Primary 120-second idle windows, 1/3/5/10 clients | 0.10% | 0.10% |
| Active writes, 1/3/5 clients | 1.50% | 0.25% |
| Active writes, 10 clients | 1.50% | **0.30% accepted** |
| Sampled process RSS | 256 MiB | 80 MiB |

CPU percentages refer to **one core**. The ten-client allowance is 0.075% of
the four-core machine's aggregate capacity. It is an engineering budget change,
not proof that the original 0.25% limit passed. The workload doubles from five
to ten simultaneous consumers; the accepted change adds 0.05 percentage points only
at that larger scale. It covers the main matrix's highest conservative Caddy
upper bound (0.288879%) and the longer-window maximum (0.261092%), while keeping
the five-client limit, idle limits and RSS limits unchanged. It does not claim
an instantaneous CPU peak or coverage of more than ten clients.

The [review JSON](data/shared-care-integrated-budget-review-2026-10-19.json)
retains each original limit/status and separately compares the same interval
with the accepted budgets: 96 main-matrix process/window entries plus 12
supplementary active entries, all upper bounds within the accepted limits.
The supplementary 30-second setup-idle windows are excluded from that review,
as defined before the run. **Resource budgets are accepted in the ADR. The
separate physical lifecycle checks completed on 2026-10-21.**

## Reproduction

```bash
python3 tool/evaluation/shared_updates/analyze_integrated.py \
  docs/testing/data/shared-care-integrated-sse-cpu-resolution-2026-10-19.json \
  --resources docs/testing/data/shared-care-integrated-pi-resources-2026-10-19T073107Z-cpu.jsonl \
  --output-prefix cpu-resolution-summary
```

The review comparison uses the original interval unchanged and tests its upper
bound against 0.30% for Caddy ten-client write windows; every other primary limit
is unchanged. The original assessment remains false for “all active bounds
within the original proposed budgets.” The separate accepted-budget result is
recorded explicitly. Natural physical-session expiry, renewed login and
automatic updates were confirmed on 2026-10-21; the S22 trusted-HTTPS exclusion
remains documented.
