# v1.4.0 Release Validation

This document records the source and release-owner validation boundary for
TerraManager `1.4.0+59`. Version 1.4.0 completes the Animal Profiles and Input
Quality milestone delivered by Issues #108–#113. Automated source checks are
recorded independently from signed artifacts, which are created only in the
release owner's protected environment.

## Release Highlights

- identify named Boxes in New Animal and Edit Animal assignment choices
- sort Box and Animal names with embedded numbers in natural order
- constrain humidity and temperature inputs to supported ranges
- add the localized Hermaphrodite / other sex value
- add five optional extended Animal characteristics in one expandable section
- omit empty characteristics from Animal details
- preserve the new values through Schema Version 9 and Backup Format 2
- display the complete GPL-3.0-or-later license offline in Settings

## Compatibility Baseline

- Application Version: **1.4.0+59**
- Database Schema Version: **9**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.3.x installation can be updated directly. The v8 to v9
migration adds nullable `originHabitat`, `weight`, `sheddingNotes`,
`restOrDormancyPeriods` and `temperatureZones` columns. Existing Boxes,
Animals, FeedingEvents, settings and media are preserved, and existing Animals
receive `null` for every new field.

Backup Format Version 2 remains the current export format. The five profile
fields are optional strings; missing keys in older Format 1 and Format 2
backups restore as `null`. Current exports and restores preserve populated
values. Backups remain unencrypted and must be stored as sensitive files.

## Automated Source Validation

Run from the repository root using the supported toolchain documented in
[toolchain-baseline.md](toolchain-baseline.md):

```text
flutter pub get
flutter gen-l10n
dart run build_runner build
dart run drift_dev make-migrations
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Recorded source result:

- [x] license integration adds no network or external-launcher dependency
- [x] localization generation completed successfully
- [x] Drift Schema Version 9 and migration helpers were regenerated
- [x] Dart formatting completed without changes
- [x] `flutter analyze --no-pub` reported no issues
- [x] complete automated test suite passed with 603 tests
- [ ] final GitHub Actions **Quality gates** run passed on the release commit

Focused milestone coverage includes:

```text
flutter test test/core/sorting/natural_string_comparator_test.dart
flutter test test/core/database/validation/animal_environmental_limits_test.dart
flutter test test/drift/app_database/animal_characteristics_migration_test.dart
flutter test test/features/animals/presentation/pages/animal_additional_characteristics_test.dart
flutter test test/features/backup/domain/backup_data_test.dart
flutter test test/features/backup/application/backup_validation_service_test.dart
flutter test test/features/settings/presentation/pages/license_page_test.dart
flutter test test/platform/license_asset_sync_test.dart
flutter test test/platform/v1_4_release_documentation_test.dart
```

- [x] named and unnamed Box assignment labels passed in both Animal forms
- [x] natural ascending and descending Box and Animal name sorting passed
- [x] humidity, temperature, range-order and repository validation passed
- [x] localized sex selection, persistence and stable backup codec passed
- [x] profile creation, edit, clearing and conditional details passed
- [x] populated v8 migration and full schema migration matrix passed
- [x] current profile backup round trip and older backup compatibility passed
- [x] offline license, Settings order, local references and large text passed

## Release-owner Builds

The following commands document the protected release-owner workflow. No
Android or Web release build was executed while preparing this source package.
Automated assistants must not create TerraManager release artifacts because
they do not have the authoritative signing environment.

```text
flutter build apk --debug --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
flutter build web --release --no-pub
```

Expected outputs:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
build/web
```

- [x] release owner produced and inspected the Android artifacts
- [x] release owner generated and inspected the Web artifact
- [x] release APK reports Version `1.4.0` and Build `59`
- [x] Google Play submission uses Version `1.4.0` and Build `59`

## Signature and Artifact Verification

Verify release-owner artifacts without rebuilding them. Follow
[android-release-signing.md](android-release-signing.md):

```powershell
$androidBuildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Directory |
  Sort-Object Name -Descending |
  Select-Object -First 1

& "$($androidBuildTools.FullName)\apksigner.bat" verify `
  --verbose `
  --print-certs `
  build\app\outputs\flutter-apk\app-release.apk

Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
```

```text
APK SHA-256: PENDING RELEASE-OWNER ARTIFACT
```

- [ ] APK signature verification succeeded
- [ ] APK certificate digest matches the permanent production certificate
- [ ] final APK SHA-256 was recorded above
- [x] no signing credential or private key entered this source package

## Upgrade, Profile and Backup Regression

- [x] migrate a populated Schema Version 8 database to Version 9
- [x] retain existing Animal fields and initialize all profile fields to null
- [x] create an Animal with all five optional characteristics
- [x] edit and clear every optional characteristic
- [x] display only non-empty characteristics on Animal details
- [x] export, validate and restore populated characteristics
- [x] restore older Format 1 and Format 2 backups without the new keys
- [x] reject present non-text profile values as invalid backup data
- [x] preserve Backup Format Version 2 and application identity

## License and Accessibility Regression

- [x] place License directly below Privacy Policy in Settings
- [x] load the authoritative root `LICENSE` as a bundled offline asset
- [x] display TerraManager, CodefrogCF and `GPL-3.0-or-later`
- [x] retain selectable Markdown, scrolling and normal Back navigation
- [x] keep references in the local document without external navigation
- [x] render without overflow under large accessibility text in widget coverage

## Manual Android and Web Validation

- [x] update a production-signed v1.3.x Android installation without data loss
- [x] create, edit, clear and inspect all five profile values on Android
- [x] repeat profile creation, details and backup restore on hosted Web
- [x] verify natural sorting and all environmental validation messages
- [x] open and read the complete License offline on Android and Web
- [x] confirm privacy, backup, scanner, media and navigation regressions

## Documentation and Publication

- [x] source version is `1.4.0+59`
- [x] `CHANGELOG.md` contains `[1.4.0] - 2026-09-14`
- [x] README and documentation index link this validation record
- [x] Roadmap records Issues #108–#113
- [x] Schema Version 9 and Backup Format 2 behavior are documented
- [x] legal-document and optional-profile decisions are recorded
- [x] release-owner build boundary is explicit
- [x] record the final release APK hash and completed manual checks
- [x] publish the annotated `v1.4.0` tag and GitHub release
- [x] submit Version `1.4.0` with Build `59` to Google Play
- [x] close Issues #112 and #113 after the final release commit succeeds
