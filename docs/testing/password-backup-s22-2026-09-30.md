# Galaxy S22 password-backup test, 2026-09-30

This is an intermediate physical-device result for the password-protected
portable-backup milestone. The protected 252 MiB import succeeded on the
corrected persistent-Web build on 2026-10-01 in Brave, Chrome and Firefox.
Protected and plain exports, and the protected export's re-import, also
succeeded in Brave. Native Android debug and test-signed Release imports of
the plain and protected fixture also succeeded. The measured native Release
memory difference exceeds the proposed 64 MiB encryption-overhead target;
paired export measurements and approximately 4 GiB physical-device checks
are still outstanding.

## Setup

- Galaxy S22 (SM-S901B), Android 16, `MemTotal: 7445796 kB` (about 7.10 GiB).
- Brave 1.96.59, standalone Web release builds served from a local test origin
  through `adb reverse`. The initial build contained the encrypted browser
  import and server-spool changes but preceded the dart2js frame-index fix.
- The first local build accidentally omitted `drift_worker.dart.js`; the
  browser fell back to in-memory database storage. Its memory samples are
  diagnostic only and **do not count as the persistent-Web acceptance result**.
  The worker was compiled and served successfully before subsequent retests.
- Synthetic format-2 fixtures: 12 Boxes, 84 generated PNG pictures, no user
  data. Plain ZIP: 264,436,791 bytes. Protected file: 264,457,033 bytes.
- Samples used `adb shell dumpsys meminfo --package com.brave.browser`;
  `TOTAL PSS` was summed across the six reported browser processes at roughly
  1.7-second intervals. These values include other Brave activity and may miss
  a short-lived true peak. The operation start was inferred from the first
  sustained increase, not captured as an explicit marker.

| Run | Idle PSS | Highest sampled PSS | Sampled increase | Functional result |
| --- | ---: | ---: | ---: | --- |
| Plain import | 1,156.0 MiB | 2,179.6 MiB | 1,023.6 MiB | Succeeded; 12 Boxes visible |
| Protected import, before fix | 1,308.8 MiB | 2,643.9 MiB | 1,335.1 MiB | Failed with generic restore message |

The browser console identified the protected failure as
`Unsupported operation: Uint64 accessor not supported by dart2js.` The
container wrote the frame index with `ByteData.setUint64`, which dart2js
compiles but cannot execute. The operation failed before successful validation
and data replacement, so the protected peak above cannot establish the final
memory overhead of a completed encrypted import. The missing database worker
is a second reason to repeat both runs before drawing a memory conclusion.

## Correction and next evidence

Frame indices are now written as eight explicit big-endian bytes. The
existing 252 MiB protected fixture still decrypts byte-for-byte to the
original ZIP on the Dart VM. The encryption unit tests and a headless Chrome
dart2js round trip passed. A Chrome runtime check was added to CI so this
unsupported accessor does not silently pass static analysis again.

## Corrected persistent-Web build, 2026-10-01

The user applied the runtime fix and pushed local commit `d0f1ca8`. The Web
build served `/drift_worker.dart.js` with HTTP 200, and Chrome DevTools showed
an active `drift worker` target. The earlier in-memory fallback is therefore
not the basis for these runs. The small protected fixture imported first and
showed one Box. The protected 252 MiB fixture then imported with the test
password and showed 12 Boxes. A following import of the plain 252 MiB fixture
also gave an explicit success message and showed 12 Boxes without a page
reload. The user initially identified the first large import as plain but
corrected this before the raw traces were labelled.

| Run | Start PSS | Highest sampled PSS | Sampled increase | Brave process count (start / peak / end) | Functional result |
| --- | ---: | ---: | ---: | --- | --- |
| Protected import from one-Box collection | 1,820.8 MiB | 2,892.6 MiB | 1,071.7 MiB | 7 / 7 / 7 | Succeeded; 12 Boxes visible |
| Plain import from 12-Box collection | 2,386.4 MiB | 3,630.2 MiB | 1,243.8 MiB | 7 / 5 / 3 | Explicit success; 12 Boxes visible; no reload |

`adb shell dumpsys meminfo --package com.brave.browser` was sampled at roughly
1.5–2-second intervals, summing `TOTAL PSS` for all reported Brave processes.
The measurement includes any other Brave tabs or processes; their state was
not recorded. The collection state differed between the two starts, and Brave
reduced its process count during the plain run. The difference between these
two sampled increases is therefore **not** evidence that the protected path
meets the proposed 64 MiB additional-memory target. Absolute sampled peaks
were high enough that a lower-memory device still needs a separate test.

The raw traces are kept as
[protected import](evidence/brave-worker-encrypted-first-import-s22.csv) and
[plain import](evidence/brave-worker-plain-second-import-s22.csv). A 15-minute
recording intended for a protected repeat from the 12-Box state ended before
the user performed the import. The user then repeated the protected 252 MiB
import successfully and again saw 12 Boxes, but that run has no sampled peak
and is excluded from the result table.

The same 12-Box collection was exported with the test password through Brave.
The app reported success and downloaded a 264,526,955-byte `.tmbackup` file,
below the 256 MiB import limit. Its first eight bytes were
`54 4d 42 4b 45 4e 43 21` (`TMBKENC!`), confirming the encrypted container
header. Across three Brave processes, sampled PSS rose from 1,608.9 MiB to
1,993.8 MiB (increase 385.0 MiB); the
[raw trace](evidence/brave-worker-protected-export-s22.csv) is retained. The
file copied back from the S22 matched its device SHA-256
`1f90d7239b79c0d338b43b6295603f42e3f83fe69f9c043e533270a5bbf8cbf8`.
Independent Dart decryption and backup validation produced a 264,506,693-byte
ZIP with 12 Boxes and 84 media files.

The user then accidentally created a second protected export before producing
the intended plain export. Both succeeded, and the later plain file was
264,506,693 bytes with the ZIP header `50 4b 03 04`. The
[combined raw trace](evidence/brave-worker-two-exports-s22.csv) is retained.
The highest samples near completion of the second protected and plain
downloads were 1,765.0 MiB and 1,775.3 MiB, respectively, inferred from file
modification times. Because the operations were back to back without a settled
idle baseline or explicit start markers, this trace cannot establish their
additional-memory difference. The proposed 64 MiB target remains unverified.

The user re-imported the first self-created protected file through Brave with
the test password, received a success result, and saw 12 Boxes. The user
reported that the delay before the backup preview and Restore button made the
page appear frozen; restoring after confirmation also took a while. The
[raw re-import trace](evidence/brave-worker-own-export-reimport-s22.csv) started at
1,416.8 MiB, peaked at 3,451.7 MiB across three Brave processes, and ended at
1,433.8 MiB. The 2,034.8 MiB sampled increase is an absolute-memory concern
for a lower-RAM device, even though this S22 run completed. The Web path reads
the picked file as one byte buffer and validates the archive on the UI isolate;
this source behavior is consistent with the reported pause, but no per-stage
timing was captured to attribute the entire delay to one operation.

With the 12-Box collection in place, four negative-path checks preserved it:
the correct small encrypted file with a wrong password, a ciphertext byte
changed in that file with the correct password, a copy truncated by 64 bytes
with the correct password, and cancellation at the valid file's preview before
Restore. The first three produced errors; after each check, 12 Boxes remained
visible. The cancellation also left 12 Boxes visible. This verifies the
standalone Web path on Brave, not the Shared Care server or a native build.

After this observation, a follow-up change painted a visible "Processing
backup" message before large-file validation and yielded to the event loop
between groups of decryption frames. On the isolated source copy, full
`flutter analyze --no-pub`, 11 focused tests, a compiled dart2js encryption
round trip in headless Chrome, and `flutter build web --release --no-pub`
passed. The follow-up S22 result is recorded below. ZIP validation still runs
synchronously, so responsiveness during every validation stage is unverified.

## Web retest with lazy media, 2026-10-01

The first rebuild on a fresh local origin could not be used: Brave displayed
icons but no text. Its console reported HTTP 404 for Roboto and fallback font
files. That attempt made no import and its PSS trace is excluded. The existing
`assets/fonts/NotoSans-Regular.ttf` was registered in `pubspec.yaml` and used
for the Web theme. On a second fresh origin, the font asset and
`drift_worker.dart.js` both returned HTTP 200. A
[S22 browser screenshot](evidence/s22-web-font-ready.png) confirmed readable
German text and the onboarding dialog.

The Web import was also changed to validate from an `InputMemoryStream` and
read media lazily after checking the archive, rather than retaining all 84
media byte arrays alongside the picked ZIP. The actual 252 MiB protected
export was decrypted and validated with this memory-backed mode on the Dart
VM: 12 Boxes and 84 media paths were found, no media buffers were retained,
and media could be read repeatedly afterward. The focused backup tests (17)
passed, full `flutter analyze --no-pub` found no issues, and the Web release
build succeeded. This still holds the complete picked archive in browser
memory and still validates the ZIP synchronously.

On the font-corrected build, the protected 252 MiB fixture imported into a
fresh collection successfully and showed 12 Boxes. The user saw the new
processing message and reported that the page responded while preparing the
preview. Across five Brave processes, sampled PSS started at 2,058.6 MiB,
peaked at 2,807.7 MiB, and ended at 2,659.2 MiB (sampled increase 749.1 MiB).
Other Brave activity and a different starting collection prevent a controlled
comparison with the earlier 1,071.7 MiB increase.

The user then completed a plain import followed by a protected import of the
same synthetic 252 MiB archive, both from a 12-Box collection on this build.
Both displayed an explicit success message and left 12 Boxes visible. The
older local TerraManager tabs had been closed; Brave reported three processes
throughout both measurements. The raw
[plain](evidence/brave-lazy-font-plain-from12-s22.csv) and
[protected](evidence/brave-lazy-font-protected-from12-s22.csv) traces were
sampled every roughly 1.5–2 seconds.

| Run | Start PSS | Highest sampled PSS | Sampled increase | End PSS | Process count |
| --- | ---: | ---: | ---: | ---: | --- |
| Plain import from 12 Boxes | 1,292.3 MiB | 2,411.0 MiB | 1,118.6 MiB | 1,512.6 MiB | 3 / 3 / 3 |
| Protected import from 12 Boxes | 1,512.6 MiB | 3,132.1 MiB | 1,619.5 MiB | 1,563.7 MiB | 3 / 3 / 3 |

The observed difference between sampled increases is **500.9 MiB**, above
the proposed 64 MiB additional-memory target. The second run started 220.3
MiB higher after the first completed, and the traces include all Brave
processes, so this pair does not isolate encryption overhead precisely.
There were no explicit operation markers or timing observations. Repeat with
browser restarts and matched idle states before treating the difference as a
stable benchmark. The 3,132.1 MiB absolute peak still supports a separate
low-RAM device check. The first successful protected run on this build has its
own [raw trace](evidence/brave-lazy-font-protected-import-s22.csv).

The same build was opened on a fresh local origin in Chrome 153.0.8010.53 and
Firefox 156.0.1 on the S22. Both displayed the UI text, imported the protected
252 MiB fixture with an explicit success message, and showed 12 Boxes. These
are functional cross-browser checks, each from a fresh collection, without a
matching plain-import run.

| Browser | Start PSS | Highest sampled PSS | Sampled increase | End PSS | Process count |
| --- | ---: | ---: | ---: | ---: | --- |
| Chrome | 622.9 MiB | 1,298.9 MiB | 676.1 MiB | 1,188.4 MiB | 3 / 3 / 3 |
| Firefox | 826.1 MiB | 1,882.8 MiB | 1,056.6 MiB | 1,294.0 MiB | 6 / 5 / 5 |

The [Chrome](evidence/chrome-lazy-protected-import-s22.csv) and
[Firefox](evidence/firefox-lazy-protected-import-s22.csv) traces include all
processes reported for their packages. Firefox reduced its process count
during the run. These figures should not be compared across browsers as a
measure of encryption overhead because their baseline state and process
models differ.

The native Android results below follow these browser checks. Shared Care,
a physical device with about 4 GiB RAM, paired export measurements, a
production-signed size comparison, and failed/cancelled safety-backup saves
remain to be checked. The full browser archive buffer and synchronous ZIP
validation remain unresolved memory and responsiveness limits.

## Native Android retest, 2026-10-01

The initial isolated debug build failed to resolve locked Gradle dependencies
because the local test shell had an invalid proxy. With that proxy removed,
the build succeeded. Its first installation crashed on startup because the
Windows host did not regenerate the ignored Flutter plugin registrant after
`flutter pub get` stopped on the missing Developer Mode symlink permission.
Copying the generated registrant into the **isolated test build only** and
rebuilding made the app start. This was a local test-build setup problem, not
an observed backup-runtime failure. The debug build was installed only on the
user-authorized expendable S22 test app.

Each large native import started from an empty app collection, selected the
same synthetic 12-Box/84-picture fixture through Android DocumentsUI, and
disabled the optional safety copy. Both reached the 12-Box/84-picture preview,
completed restore, and showed Box 12 with its thumbnail. No crash or app
restart was observed. `adb shell dumpsys meminfo --package
com.codefrog.terramanager` sampled the one app process at roughly 1.2–1.4
second intervals. The raw [debug plain](evidence/native-s22-debug-plain-import-2026-10-01.csv)
and [debug protected](evidence/native-s22-debug-protected-import-2026-10-01.csv)
traces include picker and dialog idle time.

| Debug run | Start PSS | Highest sampled PSS | Sampled increase | End PSS |
| --- | ---: | ---: | ---: | ---: |
| Plain import | 330.2 MiB | 1,150.9 MiB | 820.7 MiB | 537.4 MiB |
| Protected import | 424.4 MiB | 1,861.9 MiB | 1,437.5 MiB | 631.5 MiB |

The debug baselines differ by 94.2 MiB, so this pair is diagnostic only. A
test-signed Release APK from the same isolated source was then built and
installed after removing the debug app. It is AOT compiled and **not** signed
with the project's production key. The APK measured 92,600,700 bytes. Again,
each run began from an empty app collection and ended with 12 Boxes and image
thumbnails. The [Release plain](evidence/native-s22-release-plain-import-2026-10-01.csv)
and [Release protected](evidence/native-s22-release-protected-import-2026-10-01.csv)
traces use the same package-wide PSS sampler.

| Release run | Start PSS | Highest sampled PSS | Sampled increase | End PSS |
| --- | ---: | ---: | ---: | ---: |
| Plain import | 133.4 MiB | 686.3 MiB | 553.0 MiB | 405.7 MiB |
| Protected import | 130.5 MiB | 1,136.9 MiB | 1,006.4 MiB | 443.9 MiB |

The starting PSS values differ by only 2.9 MiB. In this first Release pair,
the protected run's sampled increase was **453.4 MiB** above the plain run's;
its absolute peak was 450.6 MiB higher. The peaks occurred in different phases
(plain during restore, protected during validation), so their difference does
not isolate cipher memory. It nevertheless exposed avoidable frame copies.

The native reader was then changed to use the newly allocated byte arrays
returned by `RandomAccessFile.readSync` and `DartAesGcm.decryptSync` directly.
During the required full-file authentication pass, each decrypted frame is
zeroed immediately after its tag is checked. A fresh test-signed Release build
with this change again restored the protected fixture from an empty collection
and displayed Box 12 with its thumbnail. Its raw
[protected no-copy trace](evidence/native-s22-release-protected-import-no-copy-2026-10-01.csv)
had 137.2 MiB starting PSS, 854.5 MiB highest sampled PSS, 717.2 MiB sampled
increase, and 468.4 MiB end PSS. Compared with the original protected Release
run, the sampled peak fell by 282.4 MiB and the sampled increase by 289.2 MiB.
Compared with the plain Release run, the optimized protected increase remains
**164.2 MiB higher** (168.2 MiB higher absolute peak), above the proposed
64 MiB target. The plain run used the immediately preceding Release build;
its import path was unchanged by this copy-removal change. This comparison is
useful evidence, but it is one run of each variant with manual operation
boundaries, not a stable benchmark. PSS sampling can miss a shorter peak, and
the build is locally test-signed. The functional result on this 7.10 GiB
device does not establish success on an approximately 4 GiB device.

After the first debug protected restore, Android's file-picker cache still
contained a 264,457,033-byte copy of the selected encrypted file. The new
import cleanup calls the picker's supported temporary-file cleanup after the
validated backup is disposed, including when the user cancels a preview.
After installing the corrected debug APK, opening the small protected backup
and cancelling its preview left `cache/file_picker` empty; the earlier large
copy was removed too. The test-signed Release build also contains this fix,
but its private cache could not be inspected with `run-as` because Release is
not debuggable. The selected file remains in the picker cache during an
active operation, and Android can still retain it if the process is killed
before cleanup. No plaintext temporary ZIP was observed in the debug cache.

Validation of these changes: full `flutter analyze --no-pub` reported no
issues after both edits; 162 backup/settings tests passed before the frame
copy change, and its nine targeted encryption/file tests passed afterward.
Debug and test-signed Release APKs built. The tests do not assert the Android
plugin's cache behavior; the S22 cancel-preview check above provides that
device evidence.

The milestone remains open. Next: investigate the native and browser
protected-import memory peaks, repeat paired exports with operation markers,
test on an approximately 4 GiB physical Android device, exercise Shared Care
cross-client restore, and compare a production-signed build's size against a
recorded pre-feature baseline. The browser full-archive buffer and synchronous
ZIP validation remain separate unresolved limits.
