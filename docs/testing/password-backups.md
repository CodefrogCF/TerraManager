# Password-protected backup acceptance

Issues #118 and #203-#207; evidence recorded 2026-09-30 through 2026-10-02.
The feature ships with a documented large-file memory limitation (ADR-036).

| Acceptance area | Recorded result / outstanding check |
| --- | --- |
| Authentication and compatibility | Container round trips, wrong password, modified/truncated header/ciphertext, fresh salt/nonce, plain formats 1/2 and atomic failed restore are covered by automated tests. |
| Large native Android import | Galaxy S22 Debug/test-signed Release restored the synthetic 252 MiB, 12-Box/84-picture fixture with previews and thumbnails. Native protected export still needs recorded release-candidate evidence. |
| Mobile standalone Web | S22 Brave protected export/restore; Chrome/Firefox protected restore. |
| Shared Care | S22 Chrome protected safety export/large restore; stale safety token rejected without replacement, fresh safety copy allowed restore. |
| Supported desktop browsers | The diagnostic Chromium run is not supported-desktop release evidence; candidate run remains outstanding. |
| Temporary files / passwords | Protected native/server spools use ciphertext; S22 Debug cancellation cleanup left picker cache empty and no plaintext ZIP was observed. Final candidate inspection remains required; killed processes can interrupt cleanup. |
| Final sizes / manuals | Diagnostic builds used Flutter 3.47.0 / Java 22 and test signing, so they do not replace a pinned, production-signed size comparison or guide/PDF review. |

## Memory result

The optimized S22 native protected import reached **854.5 MiB sampled PSS**.
Its peak-minus-idle increase remained **164.2 MiB above the plain comparison**,
exceeding the proposed 64 MiB target. The S22 had approximately 7.1 GiB RAM;
this does not establish behavior on a 4 GiB device. A separate large Shared Care
Chrome import reached about 2,384 MiB package-wide PSS; that is not an isolated
encryption-overhead measurement.

File-backed paths/frame-copy reductions help, but browser fallbacks and validation
still have complete-archive costs. Bounded-memory work and approximately 4 GiB
testing are separate follow-ups. Functional success, sampled process memory and
cryptographic integrity are different claims.

## Minimal repeat protocol

1. Use disposable standalone/Shared Care collections. Record build/toolchain,
   device/browser, RAM, fixture hash and plain/protected mode.
2. With the same synthetic media-rich fixture near 256 MiB, exercise export,
   preview and restore; record duration, UI responsiveness, starting/peak sampled
   memory and resulting record/picture counts.
3. Test wrong password, tampering/truncation, cancellation and failed safety save;
   confirm original data/settings remain unchanged.
4. Inspect passwords/logs and handled temporary-file cleanup. Compare final signed
   APK/AAB and both Web sizes using the pinned toolchain; finish candidate/device
   rows above before claiming release acceptance.

Use package-wide browser PSS/process memory, not JavaScript heap alone. Preserve
sampling/operation boundaries; one final sample is not a peak. The historic plain
and protected fixtures were 264,436,791 / 264,457,033 bytes. Original sanitized
traces are in the [measurement archive](../../tool/evaluation/shared_updates/results/README.md).
The [format reference](../backup-format.md) defines encryption and replacement;
the [release checklist](../release-checklist.md) owns publication gates.
