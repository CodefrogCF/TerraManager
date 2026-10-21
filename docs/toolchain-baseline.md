# Toolchain and Quality-Gate Baseline

| Component | Pinned baseline | Declaration |
| --- | --- | --- |
| Flutter | Flutter 3.47.2 stable | `.github/workflows/quality-gates.yml` |
| Dart | Bundled 3.13.2; project range `^3.13.0` | `pubspec.yaml` |
| Java | Eclipse Temurin 17 | Workflow and Android JVM targets |
| Android Gradle Plugin | 9.1.1 | `android/settings.gradle.kts` |
| Gradle | 9.3.1 | `android/gradle/wrapper/gradle-wrapper.properties` |
| AGP-hosted Kotlin compiler | 2.4.20; JVM target 17 | Settings buildscript / app build |
| CI | Ubuntu 24.04 | Quality Gates workflow |

Android SDK/NDK defaults come from the pinned Flutter SDK. Use its bundled Dart.

## Dependency locks

`pubspec.lock` fixes application dependencies; `deploy/server/pubspec.lock` fixes
the standalone server build. Routine resolution uses `flutter pub get` without
upgrading. Newer-package notices are informational.

Android uses strict dependency locking in `android/settings-gradle.lockfile`,
`android/app/gradle.lockfile` and `android/gradle-locks/`. Plugin locks live in the
repository rather than the Pub cache. `io.flutter:*` follows the pinned engine;
the narrowly excluded `kotlin-stdlib-common` handles the existing Gradle locking
inconsistency. Locks fix versions, not artifact authenticity.

After an intentional dependency change, refresh with the pinned toolchain:

```sh
flutter pub get
flutter build apk --config-only
cd android
./gradlew resolveAndroidDependencyLocks --write-locks
./gradlew :app:assembleDebug --write-locks
./gradlew :app:assembleDebug
```

Use `.\gradlew.bat` on Windows. Review and commit all affected declarations and
locks together. Repeat advisory checks for the resolved Pub/Maven versions;
separate application runtime findings from build/test tooling. Record date,
scanner, new findings and remaining findings without blanket overrides.

## Built-in Kotlin

Issue #212 enables `android.builtInKotlin=true` and removes application of
`org.jetbrains.kotlin.android` / `kotlin-android`. The Kotlin compiler artifact
stays on AGP's classpath for version selection. Verify effective plugin state:

```sh
cd android
./gradlew verifyAndroidBuiltInKotlin
```

`file_saver` and `mobile_scanner` use compatible releases.
`flutter_image_compress_common` retains a conditional legacy fallback in its
source; the task checks that this fallback is not applied.
`android.newDsl=false` remains required by Flutter 3.47.2. Removing it and remaining
legacy DSL dependencies is separate follow-up work. See the
[migration results](testing/android-build.md).

## CI and upgrades

Quality Gates resolves locked dependencies, generates localizations, checks
formatting, analyzes, runs tests and the browser encryption probe, builds an
Android Debug APK, verifies Built-in Kotlin/locks, and builds standalone and
Shared Care Web. The server job checks its lockfile, builds ARM64 and smoke-tests
administrator setup/health. Actions use full commit hashes.

Production APK/AAB signing uses the private TerraManager signing key and stays
outside public CI. Follow [release signing](android-release-signing.md).
Upgrade SDKs/dependencies in a focused change, update this table and CI together,
then rerun automated gates, affected builds and device checks.
