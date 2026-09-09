# Toolchain and Quality-Gate Baseline

This document defines the supported development and continuous-integration
baseline for the TerraManager v1.0.0 preparation cycle. A toolchain upgrade is
a deliberate maintenance change and must not happen implicitly during an
unrelated feature or release build.

## Supported baseline

| Component | Baseline | Source of truth |
|---|---|---|
| Flutter | 3.47.2, stable channel | `.github/workflows/quality-gates.yml` |
| Dart | Version bundled with Flutter 3.47.2; project range `>=3.13.0 <4.0.0` | Flutter SDK and `pubspec.lock` |
| Java | Eclipse Temurin 17 LTS | CI workflow and Android Java/Kotlin targets |
| Android Gradle Plugin | 9.1.0 | `android/settings.gradle.kts` |
| Gradle | 9.3.1 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Kotlin declaration | 2.4.0 | `android/settings.gradle.kts` |
| CI host | Ubuntu 24.04 | `.github/workflows/quality-gates.yml` |

Android `compileSdk`, `targetSdk`, `minSdk` and NDK values are obtained from
the pinned Flutter SDK. The application compiles Java and Kotlin source for
Java 17. Local Android development may use Windows 11, but it must reproduce
the same Flutter, Dart, Java, Gradle and dependency baseline before a release.

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

## Automated quality gates

`.github/workflows/quality-gates.yml` runs for pushes, pull requests and manual
dispatches. Third-party actions are pinned to complete commit hashes. The job:

1. installs Temurin 17 and Flutter 3.47.2 stable;
2. resolves dependencies and verifies that `pubspec.lock` is unchanged;
3. generates localization output;
4. rejects formatting differences in `lib/` and `test/`;
5. runs `flutter analyze` and the complete test suite;
6. builds an Android Debug APK and a Web Release bundle.

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
4. update `pubspec.lock` intentionally;
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
