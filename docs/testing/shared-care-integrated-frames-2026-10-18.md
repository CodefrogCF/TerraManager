# Supplementary Flutter frame observations

Date: 2026-10-18. One logical foreground client, trusted HTTPS to the existing
Pi fixture, isolated Chrome **155.0.8059.85**. This is supplementary rendering
evidence; the unchanged gateway release remains the network/performance baseline.

## Build and method

Built in the isolated source copy using Flutter **3.47.2 / Dart 3.13.2**:

```bash
flutter --no-version-check --suppress-analytics build web --no-pub \
  --no-wasm-dry-run --target tool/evaluation/shared_updates/flutter_probe.dart \
  --no-web-resources-cdn
```

The build passed. The existing resolved 3.47.2 package configuration was reused
only after checking identical dependency locks. The system SDK's Windows plugin
symlink setup was not needed for the Web build. No developer-mode setting was
changed. The Wasm dry run was explicitly skipped for this supplementary build.

`--probe-root` fulfills local static instrumented assets; authenticated API and
evaluation traffic still goes through the Pi gateway. The capture records build
asset hashes and tool hashes. `drawFrame` durations measure synchronous elapsed
wall time, including scheduling/preemption; they are not OS CPU, GPU time, widget
build counts, browser paint or physical presentation timestamps.

The [browser bundle manifest](data/shared-care-integrated-browser-bundle-2026-10-18.json)
identifies 267 files of the isolated .85 copy, which was launched and version
checked. This does not replace the system browser. The earlier full SSE matrix
used .84 and is retained with that version difference.

## Corrected probe

The [complete raw capture](data/shared-care-integrated-frame-2026-10-18.json) and
[derived JSON](data/shared-care-integrated-frame-summary-2026-10-18.json) /
[tables](data/shared-care-integrated-frame-summary-2026-10-18.md) record four
windows: 30 seconds idle and one name write in a 30-second slot for each view.

| View / workload | Observed drawFrame calls | Keepalives | Data GETs | Native name ms | Remote semantics ms | Capture upper bound ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Overview idle | 0 | 2 | 0 | — | — | — |
| Overview write | 3 | 2 | 3 | 475 | 496 | 707 |
| Detail idle | 0 | 2 | 0 | — | — | — |
| Detail write | 2 | 2 | 5 | 179 | 185 | 278 |

There were zero dropped frame samples, zero page errors, zero terminal request
failures and zero final server streams. Both writes changed the expected name
and decoded image region. Two native animation callbacks completed at +494 ms /
+186 ms. In this one-tab workload, idle stream upkeep produced no observed
Flutter frame; name changes produced data-dependent frames. This is not a full
multi-client rendering or physical-browser acceptance result. Frame sample counts
are small and not independent experimental repetitions.

The overview write-frame p95 was 238,600 microseconds
(three samples); the detail write p95 was 31,500 microseconds (two samples).
These are elapsed durations, not a causal observer-overhead estimate or a
general frame-time distribution. No current Pi resource input covers these
later windows yet; the derived probe summary makes no Pi CPU/RAM claim.

## Initial diagnostic limitation and correction

The [first probe](data/shared-care-integrated-frame-initial-2026-10-18.json)
completed valid frame windows, but its native overview timestamp was missing.
The helper expected the Animal name alone; real overview semantics merge the
name and other lines into one text node. The supervisor stopped before release
trials and the polling switch. A read-only check of the real row confirmed the
shape. The corrected helper recognizes the complete name at the beginning of
that row, rejects mere name prefixes, and verifies initial recognition in both
views before measurement. A browser regression test covers this case.

The first capture is preserved without filling the missing timestamp. Its
[frozen tool revision](../../tool/evaluation/shared_updates/frozen/README.md)
was checked against every recorded source hash. The current revision was then
used for the successful probe and [short production release check](data/shared-care-integrated-release-check-2026-10-18.json). The repeated
five-client release experiment remains a separate capture.

## Validation

- **20 Python analysis tests passed**, including missing versus zero frames,
  CPU uncertainty, overlap/restarts, soak medians and strict/subset comparison.
- **13 Node/browser tests passed**, including real complete/truncated/cancelled
  body reads, JSON `/changes` without retained queries, merged semantics text,
  argument/soak bounds and static-path confinement.
- Bash, embedded Python and local PowerShell syntax are checked separately;
  executing the guarded image switch on the Pi remains the next operator step.
