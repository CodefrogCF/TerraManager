# Password backup device check

Use this protocol before closing the password-protected portable backup
milestone. Run it on a disposable standalone collection and a disposable Shared
Care server. Import replaces collection data. Keep personal backups and server
databases outside the test profile.

## Test files

The companion synthetic fixtures are `TerraManager-synthetic-252MiB.tmbackup`
and `TerraManager-synthetic-252MiB-protected.tmbackup`. Both contain 12 Boxes,
84 generated 1024 × 1024 PNG gallery pictures, no Animals, and no personal
data. The protected fixture's password is `TerraManager-Test-2026!`. Both
files are below the 256 MiB compressed import limit and were validated with
TerraManager's format-2 validator. Do not commit the fixtures to Git.

| Fixture | Bytes | SHA-256 |
| --- | ---: | --- |
| Plain | 264,436,791 | `EA3314E6BF673093E28FCFF05C33F0C4EA085FD54BF50F73FAA19A0923E21833` |
| Protected | 264,457,033 | `2BA25880AE0CA98F1F98B64345D21B16866572ECC3B4EDEA0895DE2BB76EE09C` |

Record the exact app build, Flutter version, device model, Android version,
browser version, available RAM, fixture SHA-256 hashes, and whether the test
used standalone or Shared Care. Close unrelated apps and browser tabs. Keep
the screen awake and use the same device state for the plain/protected pair.

### Galaxy S22 / S25 Ultra run

Start with the Galaxy S22, then repeat the protected import/export on the
Galaxy S25 Ultra. On each phone use Brave first; repeat any failure in Chrome
and Firefox, and run at least one successful protected import in each browser.
Record actual RAM and Android/browser versions rather than inferring them from
the model name. These phones do not by themselves establish performance on a
physical device with approximately 4 GiB RAM, which remains a separate release
check.

On Windows, connect the phone by USB, enable Developer options and USB
debugging, accept the phone's RSA prompt, then check the connection with
`adb devices -l`. If `adb` is not on `PATH`, use Android Studio's
`platform-tools/adb.exe`. If more than one device is connected, add
`-s <serial>` immediately after `adb` in each command. Use
`adb shell cat /proc/meminfo` to record `MemTotal`, and
`adb shell pm list packages` to identify the installed browser package names.
For example, filter the output in PowerShell with
`adb shell pm list packages | Select-String 'brave|chrome|mozilla'`.
Keep the full package name from the device rather than assuming it.

Transfer the fixture files to the phone's Downloads folder. Before import,
open a fresh/disposable TerraManager collection or Shared Care test server:
import replaces the current collection. Do not run the replacement test
against a personal collection. Capture the normal 40 MiB backup separately
as a sanity check, then use the synthetic 252 MiB pair for the stress run.

For standalone Web, serve the same complete build produced by CI. Compile
`web/drift_worker.dart` to `web/drift_worker.dart.js` before `flutter build
web`, and verify that the served `/drift_worker.dart.js` returns HTTP 200.
Check the browser console for a database in-memory fallback warning; if one
appears, correct the build before recording memory results. The fallback
changes both persistence and peak memory.

## Memory and time

For Android standalone, use Android Studio's Memory Profiler for
`com.codefrog.terramanager`. Start recording before picking the import file
or confirming export. Continue through validation, restore confirmation and
the completed restore/save. Record idle memory, peak memory and elapsed time.
As a second measurement, `adb shell dumpsys meminfo
com.codefrog.terramanager` reports `TOTAL PSS` in KiB on supported Android
versions. Sample it repeatedly during the operation; one sample after the
operation cannot establish the peak.

For large mobile-Web imports, record two times separately: from file selection
to the backup preview with its Restore button, and from restore confirmation
to the collection overview. Note whether the progress indicator animates and
the page responds during each interval. A successful eventual restore does
not establish that the UI remained responsive.

For Android Brave, Chrome and Firefox, close other tabs and sample
`adb shell dumpsys meminfo --package <browser-package>` in the same way,
substituting the package name reported by the phone. This includes browser
and renderer processes on the tested Galaxy S22. Sum the `TOTAL PSS` values
of all listed processes for each sample, and keep the raw output. Report
background tabs if present. A query without `--package` can measure only
the main browser process and miss the renderer. For desktop Chrome, use the browser
Task Manager (`Shift+Esc`) and record the `Memory footprint` of the
TerraManager tab. Keep one tab open and use the same browser profile for both
runs. Browser JS heap alone is not process memory.

For each operation, calculate `peak minus idle` separately for the plain
and protected run. Their difference is
`(protected peak - protected idle) - (plain peak - plain idle)`. Use the same
fixture and collection state. The proposed target is at most 64 MiB
**additional** peak memory for protected operations. Record the absolute peak
as well as the difference; an out-of-memory termination is a failure even if
the last sample was below the target. Repeat a surprising result after
restarting the app or browser.

| Platform / browser and build | Operation | Plain idle / peak MiB | Protected idle / peak MiB | Added MiB | Plain / protected seconds | Result |
| --- | --- | --- | --- | ---: | --- | --- |
| Android standalone | Import | | | | | |
| Android standalone | Export | | | | | |
| Desktop browser standalone | Import | | | | | |
| Desktop browser standalone | Export | | | | | |
| Mobile browser standalone | Import | | | | | |
| Mobile browser standalone | Export | | | | | |
| Desktop browser Shared Care | Import | | | | | |
| Desktop browser Shared Care | Export | | | | | |
| Mobile browser Shared Care | Import | | | | | |
| Mobile browser Shared Care | Export | | | | | |

## Functional run

1. In an empty standalone test collection, import the plain fixture. Verify
   12 Boxes and a gallery total of 84 images. Clear the test collection.
2. Import the protected fixture, enter its test password, and verify the same
   counts. Export this collection once without protection and once with a new
   test password. Re-import both exports into a cleared test collection.
3. Repeat steps 1–2 in standalone Web and on the disposable Shared Care server
   through desktop and mobile browsers. Shared Care requires an administrator;
   save the current safety backup when prompted. Do not use a production
   server for a replacement test.
4. With a small test collection already present, try a wrong password, a
   modified protected file, a truncated protected file, and cancellation.
   Confirm the old collection remains unchanged. Also test a failed or
   cancelled safety-copy save; replacement must not start.
5. Repeat protected and plain imports across clients: create an export in
   standalone and import it through Shared Care, then export from Shared Care
   and import it in standalone. Check format-1 and format-2 legacy ZIP fixtures
   separately if available.

Keep the raw measurements and screenshots with the release evidence. The
milestone remains open if any listed platform still materializes the full
archive during import or download, if a plaintext temporary archive is found,
or if the physical-device and signed-build checks are missing.

The first physical-device findings and the dart2js runtime correction are
recorded in [the Galaxy S22 test report](password-backup-s22-2026-09-30.md).
