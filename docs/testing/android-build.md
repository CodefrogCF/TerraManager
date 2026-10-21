# Android build migration acceptance

Issue #212; validation recorded 2026-10-17. The accepted scope enables Built-in
Kotlin now and defers the new Android DSL.

| Requirement | Result |
| --- | --- |
| Effective compilation | `android.builtInKotlin=true`; external Android Kotlin plugin not applied. `verifyAndroidBuiltInKotlin` passed for 12 modules; app bytecode is Java 17. |
| Pinned toolchain | Flutter 3.47.2 / Dart 3.13.2, Temurin 17, AGP 9.1.1, Gradle 9.3.1, hosted Kotlin 2.4.20. |
| Automated checks | Analysis/format passed; 1,201 tests passed, one opt-in network test skipped. |
| Artifacts / locks | Debug, production-signed APK/AAB and both Web builds passed; 22 managed Gradle locks stayed unchanged in strict builds. APK/AAB signatures matched the established certificate. Browser encryption runtime probe passed. |
| Dependency/security comparison | OSV batch check on 2026-10-17 compared locked Pub/Maven versions: 1,014 baseline and 894 updated entries, 1,053 distinct queries. No new package/advisory pair; no reported hosted-Pub or Android production compile/runtime finding. |

Existing build/test scopes retained **24 affected component/version entries and
52 advisory IDs**, including Netty/Bouncy Castle. This is a version-advisory
comparison, not a source, APK, secret or device security audit. No broad overrides
were used to hide findings.

`file_saver` 0.4.0 -> 0.7.0 and `mobile_scanner` 7.4.0 -> 7.4.2 support built-in
compilation. The `flutter_image_compress_common` source warning refers to its
conditional legacy fallback; the effective-plugin check confirms it is not applied.

## Remaining work and repetition

Keep `android.newDsl=false` until Flutter/upstream dependencies support removal;
migrate any required remaining legacy DSL at that time. Device camera/scanner,
compression, saving/cancellation and backup checks are separate from build results.
Play upload acceptance was not established by signature verification.

Use the commands in [Toolchain](../toolchain-baseline.md),
[Signing](../android-release-signing.md) and [Release](../release-checklist.md).
Repeat advisory checks after dependency/toolchain changes; findings are dated.
