# Issue #230 tool preparation — local validation

Date: 2026-10-18. Baseline: `195341013b6e58b020704e5c5ee395cfe4ed044e`.

## Delivered scope

The [runbook](shared-care-integrated-acceptance.md) prepares real Flutter
measurements on the Pi 5 B with 4 GB RAM. The isolated `tm230-acceptance` project
uses the installed production web image, current production API/SSE handlers and
temporary synthetic data. Production library source and dependencies are
unchanged. Only test/evaluation code and documentation are delivered.

Issue #230 remains open: this preparation has not demonstrated the Pi performance
targets, matched repeated polling comparison, physical browser lifecycle matrix
or the 30-minute/100-reconnect memory/connection bound. ADR budgets remain
proposed until those measurements exist.

## Local checks

Environment: Windows x64, Flutter 3.47.2 / Dart 3.13.2, Chrome 155.0.8059.84,
Caddy 2.11.4. ARM64 container build and runtime remain Pi gates.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub test/shared_server/shared_integrated_evaluation_test.dart test/shared_server/shared_updates_evaluation_test.dart test/architecture/shared_care_boundaries_test.dart --reporter expanded` | 14 tests passed |
| `node --test tool/evaluation/shared_updates/test_integrated_benchmark.cjs` | 4 tests passed |
| `docker compose -f tool/evaluation/shared_updates/compose.integrated.yaml config --quiet` with explicit test variables | Passed; configuration only |
| Bash `-n` on both Pi scripts | Passed; syntax only |
| `dart build cli --target=tool/evaluation/shared_updates/lab_server.dart --output=...` | AOT bundle and SQLite native asset generated |
| `flutter build web --no-pub --target tool/evaluation/shared_updates/flutter_probe.dart --no-web-resources-cdn` | Web build and Wasm dry run passed |
| Production release Flutter UI through local Caddy HTTPS | One logical client; overview/detail idle/write windows completed |
| Supplementary probe UI through local Caddy HTTPS | Three logical tabs in one browser context; all four windows completed |

The locked dependencies resolved offline. This Windows installation still reports
the pre-existing plugin symlink/Developer Mode prerequisite at the end of `pub get`;
validation used the resolved graph with `--no-pub`. No dependency lock was changed.
The full application test suite was not rerun for this tools-only preparation.

The release UI artifact's Dart library sources were byte-compared with the
baseline and matched. The local gateway preserved the API reverse proxy's
automatic event-stream flushing, used an explicit disposable CA for Node, and a
test-certificate SPKI pin restricted to loopback in Chrome. It did not change a
system certificate store or disable TLS verification globally. The LAN health
endpoint was separately readable through the existing trusted LAN CA.

## Sanitized local observations

The [machine-readable evidence](data/shared-care-integrated-tool-smoke-2026-10-18.json)
contains the successful captures. These were short local validation trials with
ten-second idle windows and one write per view, not a Pi latency distribution.

- Four synthetic name writes produced eight correlated client observations.
  All showed the expected semantics and a changed decoded pixel region.
- Neither successful capture recorded a terminal API request failure or page error.
- Live delivered body bytes included the observable SSE upkeep events. Chrome's
  encoded chunk counter sometimes stayed zero while decoded bytes arrived; that
  diagnostic counter is explicitly excluded from total-byte comparisons.
- The release build correctly reports no frame instrumentation (`null`).
- In the three-tab probe, each overview write window recorded three Flutter
  drawFrame durations, and each detail write window recorded two. The short idle
  windows recorded zero drawFrame calls. No frame samples were dropped.
- Both trials ended with zero retained production SSE streams after client closure.

The first development capture was incomplete because its test edit omitted
required display flags. The helper now preserves the full editable profile and
revision; a regression test and the two successful real-UI captures validate that
correction. An incomplete capture is never presented as an acceptance pass.

Frame CPU covers synchronous Flutter build/layout/paint. It does not count
individual widget builds, GPU raster, browser paint or physical screen
presentation. Screenshot completion is an upper bound after expected semantics
and two animation callbacks. The resource budgets, wider client/device matrix,
restore/expiry/outage tests and memory soak require the subsequent Pi evidence.

## Repository-relative delivery paths

Changed:

```text
docs/testing/shared-care-sse-implementation-issues.md
tool/evaluation/shared_updates/lab_server.dart
```

New:

```text
docs/testing/data/shared-care-integrated-tool-smoke-2026-10-18.json
docs/testing/shared-care-integrated-acceptance.md
docs/testing/shared-care-integrated-tool-validation-2026-10-18.md
test/shared_server/shared_integrated_evaluation_test.dart
tool/evaluation/shared_updates/compose.integrated.yaml
tool/evaluation/shared_updates/flutter_probe.dart
tool/evaluation/shared_updates/integrated_benchmark.cjs
tool/evaluation/shared_updates/prepare_integrated_pi.sh
tool/evaluation/shared_updates/start_integrated_capture.sh
tool/evaluation/shared_updates/test_integrated_benchmark.cjs
```
