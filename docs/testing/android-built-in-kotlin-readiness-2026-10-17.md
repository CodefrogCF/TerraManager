# Android Built-in Kotlin readiness: 2026-10-17

Issue: #212. Inspected TerraManager revision: `d918cc4`.

Historical assessment before implementation. The user subsequently accepted
the staged scope: enable Built-in Kotlin now and defer the new Android DSL.
The implementation and executed checks are recorded in
[the migration validation report](android-built-in-kotlin-migration-2026-10-17.md).
The statements below about unchanged build files describe this assessment,
not the subsequent implementation.

## Result

The complete issue cannot yet be accepted against the pinned Flutter 3.47.2
baseline: enabling AGP's new DSL removes the legacy Android extension that
Flutter's Gradle plugin still uses. Built-in Kotlin and the new Android DSL
are separate switches. Migrating Kotlin while retaining `android.newDsl=false`
is a possible staged scope, but does not satisfy the original acceptance
criterion that both legacy opt-outs be removed.

No production build configuration, Pub dependency version, Gradle lockfile,
application ID, signing configuration or Android permission was changed for
this assessment. No Pub-cache or Flutter SDK source was patched.

## Published Flutter plugin support

The latest stable versions were queried directly from the official Pub package
API. Their release archives were downloaded into an isolated inspection
directory and checked against Pub's `archive_sha256` values.

| Package | Locked version | Latest stable checked | Published Android behavior |
|---|---|---|---|
| `file_saver` | 0.4.0 | 0.7.0 | Built-in Kotlin migration shipped in 0.5.0. The 0.7.0 Android module no longer applies `kotlin-android`; it uses `kotlin.compilerOptions` and Java/Kotlin 17. |
| `flutter_image_compress` | 2.5.1 | 2.5.1 | Already depends on the compatible Android implementation below. |
| `flutter_image_compress_common` | 1.1.1 | 1.1.1 | Applies `kotlin-android` only when built-in Kotlin is not active. It checks the AGP version, the property and the Kotlin extension after applying the Android plugin. |
| `mobile_scanner` | 7.4.0 | 7.4.2 | Since 7.4.1, the Kotlin DSL build applies `kotlin-android` only when built-in Kotlin is disabled. 7.4.2 retains this behavior. |

The available plugin releases therefore remove the original unconditional-KGP
blockers, subject to resolving and building the updated graph. A warning based
on the presence of a conditional `kotlin-android` application is insufficient
evidence that the built-in path is incompatible.

Archive SHA-256 values:

| Archive | SHA-256 |
|---|---|
| `file_saver-0.7.0.tar.gz` | `fdb82a10b134b6bd03c48599268eb4ca04d5424029d73b30733327f4957c4037` |
| `flutter_image_compress-2.5.1.tar.gz` | `98a48c05a7add6869c6838270e862124a4d571f9dd5d0cf209ed03a71b20ea84` |
| `flutter_image_compress_common-1.1.1.tar.gz` | `76869e4d5f3d65f3431e7edff0b2d8ad1eea68b49c6a37772fdb1ae6016da9ed` |
| `mobile_scanner-7.4.2.tar.gz` | `5a51ea79f0cf8293f616a5d08baae185b59b5e6bb24df01f2a63037ade0bade0` |

`file_saver` 0.5.0 also changes its HTTP API from Dio to `package:http`, replaces
`dioClient` with `httpClient`, and removes `transformDioResponse`. The existing
TerraManager call sites use local bytes, paths or streams rather than these
HTTP customization arguments. Updating the dependency still requires the save,
backup, cancellation and platform regression gates.

The inspected `file_saver` 0.4.0 and 0.7.0 Android manifests contain the same
permission declarations. This source comparison is not a merged-manifest or
APK permission verification.

## Flutter new-DSL blocker

The official Flutter 3.47.2 Gradle plugin source still:

- imports and casts the Android extension to
  `com.android.build.gradle.AbstractAppExtension` in `FlutterPlugin.kt`;
- calls `getLegacyAndroidExtension(project)` and accesses legacy variants;
- implements that helper using
  `project.extensions.findByType(BaseExtension::class.java)!!`;
- adds `android.newDsl=false` automatically when the property is absent.

Consequently, deleting both properties is not a durable opt-in: the Flutter
migrators add the disabled defaults again. An explicit Kotlin migration must
set `android.builtInKotlin=true`. Enabling the new DSL also requires a Flutter
release whose Gradle plugin has completed its public-API migration.

### Executed diagnostic

The local executable reports Flutter 3.47.0 / Dart 3.13.0, while the repository
requires Flutter 3.47.2. Gradle reports Oracle Java 22.0.2 for its launcher and
daemon, rather than the supported Temurin Java 17 runtime. The following
diagnostic was run in an isolated copy using the existing locked dependency
graph and Gradle 9.3.1:

```powershell
cd android
.\gradlew.bat help -Pandroid.builtInKotlin=true -Pandroid.newDsl=true --offline --console=plain --stacktrace --no-daemon
```

Result: configuration failed before APK packaging while applying
`dev.flutter.flutter-gradle-plugin`:

```text
ClassCastException: ApplicationExtensionImpl$AgpDecorated_Decorated
cannot be cast to com.android.build.gradle.AbstractAppExtension
at com.flutter.gradle.FlutterPlugin.addFlutterTasks(FlutterPlugin.kt:354)
```

The command-line properties left the checked-in `gradle.properties` unchanged.
This is a diagnostic on the installed SDK, not a successful or failed
acceptance build under the pinned Flutter 3.47.2 / Java 17 toolchain. The
3.47.2 source inspection above independently confirms that its Gradle plugin
retains the same legacy-extension dependency.

The related upstream issue is Flutter #191703; its report concerns add-to-app,
so it is supporting context rather than a claim that TerraManager uses
add-to-app. The TerraManager diagnostic failed at its own normal app plugin
application, as shown above.

## Lockfiles and security boundary

No new dependency graph was resolved and no locks were regenerated after the
new-DSL configuration failure. The existing repository locks record:

- KGP 2.4.20 in `android/settings-gradle.lockfile`;
- Netty 4.1.93.Final and 4.1.110.Final in internal unified-test-platform
  configurations, including `netty-codec-http` and `netty-handler`;
- Bouncy Castle 1.79 in Android build classpaths and internal test-result
  listener configurations.

These configuration names classify the current findings as build/test paths;
they do not constitute a fresh vulnerability scan or prove the contents of a
new APK. A future Kotlin migration must preserve the project's deliberate
Kotlin 2.4.20 minimum using AGP's supported buildscript-classpath declaration,
without applying the external Android Kotlin plugin. It must regenerate and
review every managed lockfile and repeat the runtime/build/test dependency
comparison and security scan. Global Netty or Bouncy Castle version overrides
are not part of this assessment.

## Remaining work and acceptance

If the issue retains its original combined scope, keep #212 open until a
supported Flutter release permits removing `android.newDsl=false`. Then:

1. Align the actual local SDK with the deliberately selected CI baseline and
   use Java 17.
2. Resolve the compatible published plugin releases without Pub-cache patches
   or dependency forks.
3. Remove the redundant external Android Kotlin plugin declaration, retain the
   supported Kotlin compiler version, and enable built-in Kotlin explicitly.
4. Remove the new-DSL opt-out only when Flutter and every resolved plugin
   support the new DSL.
5. Regenerate all Gradle locks and compare runtime and build/test graphs.
6. Run formatting, analysis, the complete Flutter test suite and repository
   quality gates.
7. Build the Android Debug APK and production-signed Release APK/AAB, checking
   the existing application ID, production certificate and merged permissions.
8. Repeat the dependency/security scan and physical Android camera, scanner,
   picture, export and backup regressions.

No Debug APK, signed Release APK/AAB, complete test-suite run or fresh security
scan is claimed by this readiness assessment.

## Sources

- [Flutter app migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Flutter plugin migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)
- [Android Built-in Kotlin migration](https://developer.android.com/build/migrate-to-built-in-kotlin)
- [AGP runtime Kotlin dependency and version selection](https://developer.android.com/build/releases/agp-9-0-0-release-notes#runtime-dependency-on-kotlin-gradle-plugin)
- [Flutter 3.47.2 FlutterPlugin.kt](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt)
- [Flutter 3.47.2 FlutterPluginUtils.kt](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt)
- [Flutter 3.47.2 new-DSL migrator](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter_tools/lib/src/android/migrations/disable_new_dsl_migration.dart)
- [Flutter public-API migration plan](https://github.com/flutter/flutter/blob/main/docs/platforms/android/Migrating-Flutter-Gradle-Plugin-to-AGP-public-API.md)
- [Flutter #191703](https://github.com/flutter/flutter/issues/191703)
- [file_saver changelog](https://pub.dev/packages/file_saver/changelog)
- [flutter_image_compress_common package](https://pub.dev/packages/flutter_image_compress_common)
- [mobile_scanner changelog](https://pub.dev/packages/mobile_scanner/changelog)
