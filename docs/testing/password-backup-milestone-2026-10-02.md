# Password backup milestone follow-up, 2026-10-02

This is diagnostic evidence from an isolated source copy, not release approval.
The primary checkout was left unchanged. The local Shared Care server and its
collection were disposable test instances bound to `127.0.0.1:8765`; the Galaxy
S22 reached it through `adb reverse`. No production server or user collection
was used for the Shared Care test.

## Checks completed

- Full `flutter analyze --no-pub`: no issues. Targeted encrypted-container,
  Shared Care portable-backup, standalone settings-backup and Shared Care
  settings tests: 15 passed. A broader test-suite attempt was stopped after
  309 passing cases when running it concurrently exhausted the host memory
  needed for the Android reference build. It is not a completed full-suite
  result.
- Both standalone and Shared Care Web release bundles built. A same-machine,
  pre-feature source copy was built for diagnostic size deltas. These builds
  used Flutter 3.47.0 rather than the release pin, Flutter 3.47.2.
- On the Galaxy S22, Chrome downloaded a password-protected Shared Care safety
  backup. The file began with the `TMBKENC!` version-1 header. A selected
  encrypted backup prompted for a password before its 264,457,033 bytes were
  read; the picker no longer preloads the whole file before that prompt.
- The 264,457,033-byte encrypted fixture contained a 264,436,791-byte portable
  ZIP, 12 Boxes and 84 images. Chrome authenticated and previewed it. A first
  restore attempt received HTTP 409 after the old safety-backup token expired;
  the server kept its one existing Box and zero media. A newly saved encrypted
  safety backup supplied a current token. The next restore completed with HTTP
  200. The server database then had 12 Boxes and 84 media assets, and the
  audit recorded `collection.restore` success. This exercises the Shared Care
  browser-to-server path and its atomic safety-token rejection.
- In the Codex in-app Chromium browser, a small Shared Care encrypted export
  and restore succeeded. A wrong password produced the combined
  password-or-damage message. This browser is useful diagnostic coverage, but
  is not one of the project's supported desktop-browser release targets.

## Device and memory observation

The connected Galaxy S22 reports `MemTotal: 7,445,796 KiB`, about 7.1 GiB.
It is not the approximately 4 GiB device required to prove a lower-memory
budget. During the successful large Chrome Shared Care import, package-wide
Chrome PSS was sampled with `adb shell dumpsys meminfo --package
com.android.chrome` about every 2.4 seconds. The trace began at 817,506 KiB,
peaked at 2,440,886 KiB (about 2,384 MiB), and therefore rose by 1,623,380
KiB (about 1,585 MiB). Samples cover 14:38:01 to 14:42:56 local time;
server audit recorded success at 14:42:19. This is a package-wide, sequential
observation, not an isolated encryption-codec overhead comparison. It confirms
that the current browser path still needs whole-archive buffering and cannot
be claimed to have bounded peak memory at the 256 MiB import limit.

## Size evidence

| Artifact | Pre-feature source | Current source | Delta |
| --- | ---: | ---: | ---: |
| Test-signed Release APK | 91,822,164 B | 76,189,122 B | -15,633,042 B |
| Test-signed Release AAB | 80,947,648 B | 72,935,298 B | -8,012,350 B |
| Standalone Web bundle | 48,396,793 B | 48,458,875 B | +62,082 B |
| Shared Care Web bundle | 48,619,255 B | 48,687,817 B | +68,562 B |

Both columns use the same local Flutter 3.47.0 / Java 22 toolchain and the
same disposable signing key. The pre-feature source is commit `11805b4` in a
separate temporary copy; the later source includes many unrelated changes.
The Android reference build needed a temporary 3 GiB Gradle heap and two
workers after an 8 GiB daemon ran out of native memory while a broad test run
was also active. Gradle lock files were refreshed in these disposable copies
only; the delivered lock state is the repository version. These deltas cannot
be attributed to encryption alone or used as final release sizes.

Against the Issue #118 baseline recorded in ADR-036, the current diagnostic
artifacts differ as follows. The source revisions and build setup differ, so
this is a size record rather than an acceptance result.

| Artifact | Issue #118 baseline | Current source | Difference |
| --- | ---: | ---: | ---: |
| Release APK | 91,272,456 B | 76,189,122 B | -15,083,334 B |
| Release AAB | 80,397,959 B | 72,935,298 B | -7,462,661 B |
| Standalone Web bundle | 48,224,404 B | 48,458,875 B | +234,471 B |
| Shared Care Web bundle | 48,618,652 B | 48,687,817 B | +69,165 B |

## Release gate

Keep password-protected backups unreleased. Web file selection, validation,
Shared Care request upload and some save fallbacks still have complete-archive
memory costs. The existing native paired 252 MiB result also exceeded the
proposed additional 64 MiB memory target. A physical approximately 4 GiB
Android device, supported desktop and mobile browser matrix, pinned release
toolchain, production signing and final APK/AAB/Web size comparison remain
unverified. The fixture and this diagnostic build do not replace those gates.
