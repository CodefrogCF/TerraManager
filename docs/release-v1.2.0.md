# v1.2.0 Release Validation

This document records the final validation of TerraManager `1.2.0+54`.
Release preparation completed on 2026-09-13. The annotated tag and GitHub
release are created only after the final source commit and its Quality gates
run succeed.

Version 1.2.0 completes the Box Lifecycle & History milestone delivered by
Issues #102–#104 and validated by Issue #105.

## Release Highlights

- add optional Box names and persistent Box lifecycle metadata
- archive empty active Boxes with a required reason and optional archive note
- keep assigned Animals protected from accidental Box archive
- provide an Archived Boxes overview ordered by newest archive date
- retain pictures, notes, dimensions and permanent QR identifiers in history
- restore archived Boxes into every active workflow
- explain archived QR scans in the Box and Feeding Mode scanners
- restrict permanent Box deletion to archived details after confirmation
- align Box Overview icons and move Animal archive into Edit Animal

## Compatibility Baseline

- Application Version: **1.2.0+54**
- Database Schema Version: **8**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.1.x installation can be updated directly. The Version 6
to Version 7 migration adds optional Box names, and the Version 7 to Version 8
migration adds lifecycle columns without replacing existing records. Existing
Boxes remain active with empty archive metadata. Boxes, Animals, FeedingEvents,
settings and media remain available after the upgrade.

Current Backup Format Version 2 archives preserve Box names and lifecycle
metadata. Older Format 1 and Format 2 archives remain restorable; missing names
remain empty and missing lifecycle fields restore as active Boxes. Backups
remain unencrypted and must be stored as sensitive files.

## Automated Validation

Run from the repository root using the supported toolchain documented in
[toolchain-baseline.md](toolchain-baseline.md):

```text
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Release result:

- [x] dependency resolution completed without a lock-file change
- [x] localization generation completed successfully
- [x] Dart formatting completed without changes
- [x] `flutter analyze` reported no issues
- [x] complete automated test suite passed with 554 tests
- [ ] final GitHub Actions **Quality gates** run passed on the release commit

The focused regression includes:

```text
flutter test test/drift/app_database/migration_test.dart
flutter test test/core/database/repositories/box_lifecycle_repository_test.dart
flutter test test/features/backup/application/box_lifecycle_backup_test.dart
flutter test test/features/boxes/presentation/pages/box_lifecycle_ui_test.dart
flutter test test/features/boxes/presentation/pages/box_lifecycle_integration_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_management_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_swipe_navigation_test.dart
flutter test test/features/animals/presentation/pages/animal_lifecycle_ui_test.dart
flutter test test/features/animals/presentation/pages/animal_detail_swipe_navigation_test.dart
flutter test test/l10n/localization_infrastructure_test.dart
flutter test test/platform/v1_2_release_documentation_test.dart
```

- [x] Version 6 to Version 7 and Version 7 to Version 8 migrations passed
- [x] current and legacy backup validation and round trips passed
- [x] Box lifecycle repository and concurrency checks passed
- [x] archive, Box History, restore and permanent-deletion widget tests passed
- [x] archived QR behaviour passed in both scanners and languages
- [x] Animal assignment and archive interaction tests passed

## Release Builds

Create supported artifacts from the same release source state:

```text
flutter build apk --debug --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
flutter build web --release --no-pub
```

Expected outputs:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
build/web
```

- [x] Android Debug APK completed successfully
- [x] production-signed Android Release APK completed successfully
- [x] production-signed Android App Bundle completed successfully
- [x] Web Release build completed successfully
- [x] packaged artifacts report Version `1.2.0` and Build `54`

## Signature and Artifact Verification

The Android artifacts were verified using the process in
[android-release-signing.md](android-release-signing.md). The APK certificate
digest must match the permanent production certificate above. The AAB must
carry a valid JAR signature.

```powershell
$androidBuildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Directory |
  Sort-Object Name -Descending |
  Select-Object -First 1

& "$($androidBuildTools.FullName)\apksigner.bat" verify `
  --verbose `
  --print-certs `
  build\app\outputs\flutter-apk\app-release.apk

jarsigner -verify -verbose -certs `
  build\app\outputs\bundle\release\app-release.aab

Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
Get-FileHash build\app\outputs\bundle\release\app-release.aab -Algorithm SHA256
```

```text
APK SHA-256: 023B1FC6A3D946A966047F90ACD5F6197D331C5C0A6898907F05606D8F86A918
AAB SHA-256: 6AE57E75620225C0D580CEB4577B8C1C5ED6304C29B9E4F9552174C558C24875
Web ZIP SHA-256: FC50BB2D0B270697C206ADEF6E09ED77611B16D0468C0698207029B734A00A25
```

- [x] APK signature verification succeeded
- [x] APK certificate digest matches the permanent production certificate
- [x] AAB signature verification succeeded
- [x] APK, AAB and Web ZIP hashes were recorded from the final artifacts
- [x] no signing credential or private key entered the release package

## Lifecycle and Upgrade Regression

- [x] update a representative v1.1.x database without data loss
- [x] preserve existing Boxes as active during the Schema Version 8 migration
- [x] archive only Boxes without assigned active Animals
- [x] list blocking Animals without modifying their lifecycle
- [x] show Box History empty and populated states in English and German
- [x] show retained Box data and archive metadata in archived details
- [x] keep archived Boxes out of active overviews and assignment controls
- [x] explain archived QR scans without opening active workflows
- [x] restore a Box with the same QR identity and clear archive metadata
- [x] remove a restored Box from history and return it to the active overview
- [x] permanently delete only archived Boxes after explicit confirmation
- [x] retain current and legacy backup compatibility across Android and Web

The release owner completed the physical Android lifecycle and archived-QR
checks recorded in Issue #105. Automated tests cover equivalent Android/Web
application behaviour where platform plugins are not involved.

## Documentation and Publication

- [x] version is `1.2.0+54`
- [x] `CHANGELOG.md` contains `[1.2.0] - 2026-09-13`
- [x] README and documentation index link this validation record
- [x] Roadmap records Issues #102–#105
- [x] installation, platform, development, schema and backup documentation was
  reviewed for the Box lifecycle release
- [x] build, signature and artifact hashes are recorded above
- [x] final release commit is pushed and its Quality gates run succeeds
- [x] annotated tag `v1.2.0` is created from the final release commit and pushed
- [x] GitHub release `v1.2.0` is published with the verified APK
- [x] Issue #105 is closed after publication succeeds