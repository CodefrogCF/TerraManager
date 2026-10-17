# Android Built-in Kotlin migration: 2026-10-17

Issue: #212. Baseline: `d918cc4e7d32fbcc6eb28e94c391a7992ebafca4`, with
the user's existing toolchain/readiness documentation overlaid. Implementation
and validation use an isolated copy; the primary checkout is preserved.

## Accepted scope

The user accepted: "Built-in Kotlin now; new DSL later." The Android build
explicitly enables `android.builtInKotlin=true`, removes the external Android
Kotlin plugin declaration, and retains `android.newDsl=false`. The latter is
the remaining part of the original issue, so its original full acceptance
criteria must not be marked complete.

The application uses the public `ApplicationExtension` DSL and named release
build type. Flutter's Gradle plugin and several upstream libraries still
require legacy Android extensions. No Flutter SDK or Pub-cache source is
patched. No global dependency-version override is introduced.

## Toolchain and dependencies

| Component | Validated selection |
|---|---|
| Flutter | 3.47.2 stable, `d3b14c876900e553bc736ca19295fc09e3853e8e` |
| Dart | 3.13.2, bundled with that Flutter SDK |
| Java | Eclipse Temurin 17.0.20.1+1 |
| Gradle | 9.3.1 |
| Android Gradle Plugin | 9.1.1 |
| AGP-hosted app Kotlin compiler | 2.4.20, selected on the settings buildscript classpath |
| Java/Kotlin app bytecode targets | 17 / JVM 17 |

The Kotlin Gradle Plugin artifact remains on AGP's classpath as the supported
mechanism for selecting its compiler version; the external Android Kotlin
plugin is not applied. This preserves the existing compiler security baseline.

Intentional Pub changes:

- `file_saver`: 0.4.0 -> 0.7.0, supporting Built-in Kotlin;
- `mobile_scanner`: 7.4.0 -> 7.4.2, supporting Built-in Kotlin;
- `meta`: 1.18.3 -> 1.19.0, required by `file_saver`;
- remove the no-longer-required `dio` and `dio_web_adapter` transitives.

`flutter_image_compress` 2.5.1 and its Android implementation
`flutter_image_compress_common` 1.1.1 remain unchanged. The implementation
already conditionally selects built-in compilation.

## Effective Kotlin plugin state

`./gradlew verifyAndroidBuiltInKotlin` checks the explicit opt-in, rejects
`org.jetbrains.kotlin.android` and `kotlin-android` in all included Android
application/library projects, and requires the app's Kotlin extension.
It succeeded for **12 Android modules** and is included in the CI workflow.
The compiled app `MainActivity.class` is produced under AGP's
`intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes/` directory;
its class-file major version is **61 (Java 17)**.

Flutter still prints a source-based KGP warning for
`flutter_image_compress_common`: its Groovy build file contains a conditional
legacy fallback. The actual plugin-state check confirms that fallback is not
applied in this build. This warning and the `android.newDsl=false` deprecation
are documented remaining upstream warnings.

## Executed checks

- `flutter pub get`: passed with the supported isolated SDK.
- `flutter gen-l10n`: passed.
- `dart format --output=none --set-exit-if-changed lib test`: passed;
  529 files checked, zero changes.
- `flutter analyze --no-pub`: passed, no issues found.
- `flutter test --no-pub --concurrency=1 --reporter expanded`: passed;
  **1,201 passed, one planned skip, zero failures**, in 24m 41s. The skipped
  external download-link test is opt-in via `RUN_DOWNLOAD_LINK_CHECK=true`.
- `./gradlew resolveAndroidDependencyLocks --write-locks`: passed; all
  repository-managed project/buildscript configurations were refreshed.
- `./gradlew :app:assembleDebug --write-locks`: passed, 272 tasks; the initial
  Debug APK was built successfully.
- `flutter build apk --debug --no-pub`: passed without `--write-locks`;
  all 22 managed lockfiles remained unchanged.
- `flutter build apk --release --no-pub`: passed with the existing external
  production signing credentials.
- `flutter build appbundle --release --no-pub`: passed with the same production
  signing identity.
- The strict Debug APK, Release APK and AAB builds preserved all 22 managed
  Gradle lockfiles without `--write-locks`.
- `./gradlew verifyAndroidBuiltInKotlin`: passed, 12 Android modules.
- `dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js`:
  passed.
- `flutter build web --release --no-pub`: passed for standalone, including
  Flutter's default Wasm compilation dry run.
- `flutter build web --release --no-pub --target lib/main_shared.dart
  --output build/web-shared`: passed for Shared Care, including its Wasm
  compilation dry run.
- The CI browser-encryption runtime probe compiled with `dart compile js -O2`
  and ran in local headless Chrome: **Web encryption round trip passed**.
  It encrypts and decrypts 150,000 bytes and compares every decoded byte.
  Windows process execution explicitly waited for Chrome before reading its
  output; the Linux CI workflow remains unchanged for this existing gate.

## Release identity, signing and permissions

The release APK has application ID `com.codefrog.terramanager`, version name
`1.15.3` and version code `90`. APK verification with Android `apksigner`
succeeded (v2 scheme). AAB verification with JDK `jarsigner -verify` succeeded.
Both artifacts match the documented production certificate SHA-256:

```text
f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748
```

The AAB verifier also reports the self-signed certificate, absent timestamp,
ZIP attributes and a difference between `JarFile` and `JarInputStream`
verification. The generated bundle places `META-INF/MANIFEST.MF` last (entry
374 of 375, zero based). `JarInputStream` only recognizes a manifest at the
start of its stream. A separate verification read every payload entry to EOF
with `JarFile(..., true)` and confirmed that all **372 payload entries** have
exactly one signer matching the production certificate. The ZIP CRC and
duplicate-entry checks also passed. These checks establish signature integrity;
Google Play upload acceptance was not tested.

`aapt dump permissions` reports:

- `android.permission.CAMERA`;
- `android.permission.WRITE_EXTERNAL_STORAGE`, limited to `maxSdkVersion=28`;
- the app-scoped `com.codefrog.terramanager.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.

There is no `INTERNET`, `ACCESS_NETWORK_STATE` or `READ_EXTERNAL_STORAGE`
permission in the release APK. The app manifests and the upgraded plugins'
Android manifests are unchanged; the app runtime dependency lock is unchanged.
This source/dependency comparison and the compiled permission list show no
permission addition from the migration. No pre-migration release binary was
available for a binary-to-binary comparison.

The signing-properties copy used inside the isolated app was removed after
the release builds. Signing properties and keystores are excluded from the
delivery.

## Locked dependency and advisory comparison

All 20 Flutter-plugin project/buildscript lockfiles, the app lockfile and the
settings lockfile were regenerated. Five currently differ: the settings lock
and the project/buildscript locks for `file_saver` and `mobile_scanner`.
Unchanged generated locks remain byte-for-byte identical to the baseline.

The app dependency lock is unchanged. Across all plugin production
Debug/Profile/Release compile/runtime classpaths, no new module/version is
introduced. `file_saver` drops its old Kotlin stdlib 2.1.0 selection and uses
the existing 2.4.20 selection. Scanner test dependencies change with its
upstream release; those changes do not affect the production runtime graph.
The settings classpath drops the external Android Kotlin plugin marker while
retaining the selected compiler artifacts.

The public OSV batch API was queried on 2026-10-17 for locked hosted Pub and
Maven component versions in both graphs:

- 1,014 baseline and 894 updated component/version entries;
- 1,053 unique component/version queries across both graphs;
- no newly introduced package/advisory pair;
- no reported finding in the hosted Pub graph or the Android production
  compile/runtime lock configurations;
- 24 affected component/version entries remain in Android build/test scopes,
  covering 52 distinct advisory identifiers.

The remaining entries include Netty 4.1.93.Final / 4.1.110.Final in internal
Unified Test Platform configurations and Bouncy Castle 1.79 in UTP/buildscript
configurations (plus bcprov 1.81 in image-picker unit tests). Other existing
build/test findings include Commons Compress/Lang, HttpClient, jose4j, JDOM
and upstream-declared older Kotlin Gradle Plugin artifacts. An unapplied
Android plugin can still have a locked buildscript artifact; the effective
plugin check does not claim to eliminate those advisories.

These results compare known version advisories and lockfile scopes. They are
not a source audit, APK binary scan, secret scan, device test or assertion that
the build/test toolchain has no vulnerabilities. No global Netty, Bouncy Castle
or Kotlin resolution override is added to suppress findings.

## Validation boundaries

The supported Flutter/Java toolchain is installed only for this isolated
validation; the user's global SDK and settings are unchanged. Windows desktop
support is disabled only in that temporary Flutter configuration to avoid
requiring host Developer Mode for unrelated desktop symlinks. Android and Web
remain enabled.

Before the final build checks, the isolated SDK/JDK were reinstalled outside
Windows Temp after files disappeared from the first temporary installation.
The Flutter commit, engine, Dart version and Java release remained identical.

Local tests use `--concurrency=1`. The Android validation process limits
Gradle to a 3 GiB heap and two workers to stay within the host's available
memory. Flutter/AGP may still create their own Kotlin compiler daemons. These are temporary
process settings; the repository's existing JVM configuration is preserved.

Physical Android checks for camera/scanner, photo compression, file saving,
cancellation and backup/restore require a device. Automated tests and successful
builds do not establish those device results. The Web builds and focused
encryption probe are not end-to-end UI checks of either Web application.
GitHub-hosted Ubuntu CI and the separate Docker ARM64 Shared Care server job
were not executed here and remain distinct gates.

## References

- [Flutter application migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Flutter plugin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)
- [AGP built-in Kotlin migration](https://developer.android.com/build/migrate-to-built-in-kotlin)
- [AGP 9 release notes and compiler version selection](https://developer.android.com/build/releases/agp-9-0-0-release-notes)
- [Java manifest placement and stream signature verification](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/jar/JarInputStream.html)
