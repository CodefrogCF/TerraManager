# Toolchain and Quality-Gate Baseline

This document defines the current supported development and
continuous-integration baseline for TerraManager. A toolchain upgrade is a
deliberate maintenance change and must not happen implicitly during an
unrelated feature or release build.

## Supported baseline

| Component | Baseline | Source of truth |
|---|---|---|
| Flutter | 3.47.2, stable channel | `.github/workflows/quality-gates.yml` |
| Dart | Version bundled with Flutter 3.47.2; project range `>=3.13.0 <4.0.0` | Flutter SDK and `pubspec.lock` |
| Java | Eclipse Temurin 17 LTS | CI workflow and Android Java/Kotlin targets |
| Android Gradle Plugin | 9.1.1 | `android/settings.gradle.kts` |
| Gradle | 9.3.1 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Kotlin declaration | 2.4.20 | `android/settings.gradle.kts` |
| CI host | Ubuntu 24.04 | `.github/workflows/quality-gates.yml` |

Android `compileSdk`, `targetSdk`, `minSdk` and NDK values are obtained from
the pinned Flutter SDK. The application compiles Java and Kotlin source for
Java 17. Local Android development may use Windows 11, but it must reproduce
the same Flutter, Dart, Java, Gradle and dependency baseline before a release.

The October 2026 build-tool hardening update keeps the existing Gradle 9.3.1
and Java 17 baseline while moving the Kotlin Gradle Plugin to 2.4.20 and the
Android Gradle Plugin to the 9.1.1 patch release. Kotlin 2.4.20 is the minimum
project declaration accepted after the build-cache deserialization advisory;
strict Gradle lockfiles must be regenerated with the pinned Flutter 3.47.2 and
Java 17 toolchain whenever either declaration changes. Scanner findings that
exist only in Android build/test tooling are tracked separately from the
application runtime graph and are not hidden with broad version overrides.

Dart is distributed with Flutter. Do not install or select an unrelated Dart
SDK for this project.

## Dependency baseline

`pubspec.yaml` defines the allowed direct-dependency ranges. The committed
`pubspec.lock` records the exact resolved direct and transitive dependency
graph and is the authoritative dependency baseline for application builds.

Use:

```text
flutter pub get
```

Routine development and CI must not use `flutter pub upgrade` or
`flutter pub upgrade --major-versions`. CI fails if `flutter pub get` modifies
`pubspec.lock`. Dependency updates belong in a focused maintenance change with
formatting, analysis, complete automated tests and affected platform builds.

The message that newer incompatible package versions are available is
informational. It does not make the locked build invalid and is not a reason to
upgrade dependencies during release packaging.

### Android Gradle dependency locks

Android uses [Gradle dependency locking](https://docs.gradle.org/current/userguide/dependency_locking.html)
in strict mode for every repository build project. Gradle-generated files are
committed alongside the build configuration:

- `android/settings-gradle.lockfile` records the settings/plugin classpath,
  including the declared Android and Kotlin Gradle plugins;
- `android/app/gradle.lockfile` records the app's Debug, Profile, Release and
  test dependency configurations;
- `android/gradle-locks/<plugin>.lockfile` records each included Flutter Android
  plugin project's dependencies, and `android/gradle-locks/<plugin>-buildscript.lockfile`
  records a plugin buildscript when it resolves a classpath.

Flutter plugin projects live in the Pub cache; their lockfile locations are
redirected into this repository. The Android root project has no resolvable
external project dependencies, so Gradle does not produce an
`android/gradle.lockfile`. The Flutter Gradle plugin's included build belongs to
the pinned Flutter SDK rather than this repository. These lockfiles pin module
versions; they are not artifact checksum or signature verification.

Two narrowly scoped modules are excluded from project lockfiles:
`io.flutter:*` tracks the pinned Flutter engine revision, and Gradle can resolve
`org.jetbrains.kotlin:kotlin-stdlib-common` only after applying the otherwise
complete Kotlin lock state. The latter is a known
[Gradle locking inconsistency](https://github.com/gradle/gradle/issues/21396);
other Kotlin modules and plugin classpaths remain locked. Revisit both
exclusions during a coordinated Flutter/Gradle/Kotlin upgrade.

To refresh Android locks after an intentional dependency or toolchain change,
use the pinned Flutter and Java toolchain from the table above. From the
repository root:

```sh
flutter pub get
flutter build apk --config-only
cd android
./gradlew resolveAndroidDependencyLocks --write-locks
./gradlew :app:assembleDebug --write-locks
./gradlew :app:assembleDebug
```

On Windows, use `.\gradlew.bat` in place of `./gradlew`. The first Gradle task
resolves every currently included Android project; the Debug build also covers
configurations that Android Gradle Plugin resolves only during build tasks.
Review and commit all changed lockfiles together with any affected
`pubspec.lock` and build declarations. The final build omits `--write-locks`
so strict locking checks the committed state. Release signing is not needed
for this refresh. The signed Release build remains a separate release-owner
check.

## Automated quality gates

`.github/workflows/quality-gates.yml` runs for pushes, pull requests and manual
dispatches. Third-party actions are pinned to complete commit hashes. The job:

1. installs Temurin 17 and Flutter 3.47.2 stable;
2. resolves dependencies and verifies that `pubspec.lock` is unchanged;
3. generates localization output;
4. rejects formatting differences in `lib/` and `test/`;
5. runs `flutter analyze` and the complete test suite;
6. builds an Android Debug APK with strict Gradle locks, verifies the Android
   source and lockfiles are unchanged, and builds a Web Release bundle.

The separate `shared-care-server` job checks the server's Dart lockfile, builds
the ARM64 server image and smoke-tests administrator setup and health.

The Android CI build is intentionally Debug. Production APK and AAB builds
require the private TerraManager signing key and remain part of the authorized
local release workflow in [android-release-signing.md](android-release-signing.md).
No signing password or keystore is stored in GitHub Actions.

Run the equivalent checks locally before pushing:

```text
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release
```

## Kotlin and Gradle compatibility warnings

TerraManager's application module does not apply the Kotlin Gradle Plugin.
However, the currently resolved `file_saver`,
`flutter_image_compress_common` and `mobile_scanner` plugins still apply it.
Flutter therefore reports that those plugins must migrate before a future
Flutter version makes Built-in Kotlin mandatory.

Until compatible plugin releases are available:

- keep `android.builtInKotlin=false` and `android.newDsl=false` in
  `android/gradle.properties`;
- do not suppress or reinterpret the warning as a successful migration;
- check the three plugins during planned dependency upgrades;
- enable Built-in Kotlin only after all resolved plugins are compatible and
  Android builds and tests pass without the compatibility flags.

The current Flutter migration guidance explains that the compatibility flags
are temporary and that plugins which apply the Kotlin Gradle Plugin must be
updated separately:

- [Flutter application migration to Built-in Kotlin](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Flutter plugin migration to Built-in Kotlin](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)

Some local Android builds can also show a restricted `java.lang.System::load`
warning from Gradle's native-platform library when Gradle is run with a newer
host JDK. The supported CI and Android build runtime is Java 17. Do not hide
the warning with broad JVM access flags. First reproduce with Java 17; then
review it again as part of the next coordinated Flutter, Gradle or JDK upgrade.

## Upgrade procedure

For every proposed baseline update:

1. open a focused maintenance Issue;
2. update the pinned workflow version and this document together;
3. run `flutter pub outdated` and review direct and transitive changes;
4. update `pubspec.lock` and affected Android Gradle lockfiles intentionally;
5. regenerate localization and Drift output when affected;
6. run all quality gates and supported platform builds;
7. repeat backup, camera, scanner, media and physical Android regressions when
   their dependencies or platform toolchain changed;
8. record remaining warnings and the accepted decision in the Changelog.

Flutter's supported continuous-delivery guidance and the action sources used
by the workflow are available here:

- [Flutter continuous delivery](https://docs.flutter.dev/deployment/cd)
- [subosito/flutter-action](https://github.com/subosito/flutter-action)
- [actions/setup-java](https://github.com/actions/setup-java)
