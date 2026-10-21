# Issue #230: final integrated Shared Care acceptance

Date: **2026-10-21**. Status: **validation complete for the documented fixture,
workloads, accepted budgets and explicitly qualified browser scope; ready to
close the issue**. This document does not change the GitHub issue state.

## Measured implementation and matrix

The [matched .85 report](shared-care-integrated-matched-2026-10-19.md) records
the current integrated Dart API and Flutter release web image through Caddy on
the Raspberry Pi 5 B / 4 GB. The disposable fixture has 100 Animals, five Boxes
and 2,000 Feedings. The API/lab and SSE web images are identified as `2dee1f1`;
the comparison polling web image is `8e684ec`. Their immutable identities and
switch history remain in the original reports. Production port 443 was outside
the test; the fixture used port 8443.

- Both modes cover 1/3/5/10 logical clients, three repetitions, overview/details
  and idle/write workloads: 12 trials / 48 windows per mode.
- All 342 SSE write observations matched the expected value and changed capture
  region; all per-view/per-repetition five-client capture p95 values were
  423–1,029 ms, below two seconds.
- Idle data GET rates fell 100%, decoded API body-byte rates at least 99.976%,
  including in-window stream upkeep. This excludes HTTP/TLS/TCP overhead.
- The .85 terminal events have EOF/valid-JSON reader evidence and matching-text
  application parse observations. Identical concurrent bodies can make a
  particular request correlation ambiguous. The original .84 observations,
  outlier and unresolved event classifications remain unchanged.
- The separate instrumented frame probe observed no idle frames and frames
  after changes. Its drawFrame duration is elapsed wall time, not OS CPU/GPU
  usage or display presentation. Capture completion is a timing upper bound.

## Accepted resource limits

The operator accepted the scale-specific limits on **2026-10-19**. CPU percentages
refer to one core. These apply to the recorded fixture and workloads.

| Condition | Dart | Caddy |
| --- | ---: | ---: |
| Primary idle windows, 1/3/5/10 clients | 0.10% | 0.10% |
| Active writes, 1/3/5 clients | 1.50% | 0.25% |
| Active writes, 10 clients | 1.50% | 0.30% |
| Sampled process RSS | 256 MiB | 80 MiB |

All 108 main/supplementary-active process CPU upper bounds fit the accepted
limits. Main-matrix maximum sampled RSS was 183.70 / 51.30 MiB; the separate
longer-window follow-up was 183.16 / 52.64 MiB (Dart / Caddy).
The [budget review JSON](data/shared-care-integrated-budget-review-2026-10-19.json)
retains the original interval rows and the original 0.25% statuses alongside
the accepted decision. It does not reclassify the three original 90-second or
one supplementary 180-second inconclusive ten-client intervals against 0.25%.
The setup-only short idle windows are outside primary idle acceptance.

The [30-minute soak](shared-care-integrated-resources-2026-10-18.md) completed
118 actual reopen cycles. Initial/final warm median RSS was stable for Dart
and increased about 0.400% for Caddy. Stream writer source/tests establish the
bounded queue independently of sampled process RAM. The workload does not
prove instantaneous peaks, native-device memory or per-mode RAM savings.

## Physical-browser outcomes

The [physical report](shared-care-integrated-physical-checks.md) and
[structured operator evidence](data/shared-care-integrated-physical-2026-10-19.json)
retain the original replies and their limits.

| Case | Result |
| --- | --- |
| Foreground list/detail propagation | Operator-confirmed, no manual reload |
| Mobile background/resume | Operator-confirmed |
| Mobile network interruption/recovery | Operator-confirmed, roughly ten seconds estimated; not a latency percentile |
| Same-browser tabs | Operator-confirmed, no reload |
| Draft/conflict and disconnected writes | Operator-confirmed, conflict feedback and no unexpected overwrite |
| Caregiver deactivation/reactivation | Operator-confirmed |
| Stale safety-grant rejection and successful restore after fresh export | Collectively operator-confirmed; exact messages and separate reload/login details not supplied |
| Natural twelve-hour expiry | Automatic login screen without manual reload despite recent editing, confirmed 2026-10-21 |
| Renewed login and automatic updates after expiry | Collectively operator-confirmed 2026-10-21, following the requested procedure without manual reload |

The reported fresh login was **2026-10-20 21:19 Europe/Berlin**, with expected
expiry around **2026-10-21 09:19**. The exact transition second was not measured.
The requested expiry-test client was Windows Firefox; device/account details
were not individually restated in the final replies. No failed expiry case is
inferred from earlier activity while the session was still valid.

S25/Brave and Windows Chrome/Firefox/Edge were reported warning-free. S22/Firefox
had a bypassed certificate warning and lacked the local CA. At the operator's
request it remains **excluded from trusted-HTTPS acceptance**, not passed. Its
earlier functional observations retain that qualification. No Android CA or
Firefox trust setting was changed. Unused browser combinations are not implied
by the inventory.

## Delivery and closure

All planned acceptance work is complete within the stated scope. No application
fix was needed for the expiry observation. This final follow-up changes only
documentation/evidence relative to the preceding accepted-budget ZIP; previous
runtime/evaluation sources and raw measurements remain unchanged.

The final cumulative ZIP includes all earlier Issue #230 follow-up files and
this report. Primary checkout contents must be verified unchanged during
packaging. No Flutter suite, analyzer, build or performance capture is repeated
for this documentation-only update; earlier tool-test evidence is labelled as
such. The obsolete evening restart reminder was deleted after natural expiry
was confirmed. No automatic GitHub edit or issue closure is performed.
