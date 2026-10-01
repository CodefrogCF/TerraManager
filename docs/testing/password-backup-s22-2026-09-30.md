# Galaxy S22 password-backup test, 2026-09-30

This is an intermediate physical-device result for the password-protected
portable-backup milestone. The successful protected 252 MiB import, export,
and approximately 4 GiB physical-device checks are still outstanding.

## Setup

- Galaxy S22 (SM-S901B), Android 16, `MemTotal: 7445796 kB` (about 7.10 GiB).
- Brave 1.96.59, standalone Web release build served from a local test origin
  through `adb reverse`. The build contained the encrypted browser import and
  server-spool changes but preceded the dart2js frame-index fix below.
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

Repeat the protected import first with the small one-Box fixture, then with
the 252 MiB fixture on the corrected Web build. Compare the completed run
against a plain import from the same collection state, record the browser
version and background-tab state, verify that `drift_worker.dart.js` returns
HTTP 200 without the in-memory fallback warning, and run the negative-path
checks. The proposed 64 MiB additional-memory target has not been
demonstrated.
