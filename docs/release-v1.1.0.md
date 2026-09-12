# v1.1.0 Release Validation

This document is the final validation checklist for TerraManager `1.1.0+50`.

Release preparation started on 2026-09-12. Result checkboxes remain open until
the corresponding command, artifact or manual workflow has actually been
verified. Do not create the release tag while a release-blocking item remains
unresolved.

The automated, migration, backup and Android/Web regression, supported builds,
release-artifact verification and final Quality gates run completed
successfully on 2026-09-12. Only tag and GitHub release publication remain
pending.

Version 1.1.0 completes the Detail & Workflow Polish milestone implemented by
Issues #94–#100. It advances the local database to Schema Version 6 for
optional Box notes while retaining Portable Backup Format Version 2.

## Release Highlights

- show current Animal thumbnails in Box assignment lists with a safe fallback
- place Box details and assigned Animals before the consolidated QR section
- retain QR PNG export while removing the impractical single-code Print action
- add optional multiline Box notes to create, edit, detail and backup workflows
- move Box deletion into a confirmed destructive action at the bottom of Edit
  Box
- make Latest Feeding a direct shortcut to the Animal's feeding history
- provide dedicated Feeding Reminder settings from active Animal details
- replace the Settings accent-color chip group with a compact localized
  dropdown
- show installed version, build number and developer information in About
  TerraManager
- allow the enabled-by-default pre-restore safety backup to be disabled for one
  Restore operation

## Compatibility Baseline

- Application Version: **1.1.0+50**
- Database Schema Version: **6**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain prepared but unvalidated platforms.
- The Version 5 to Version 6 migration preserves existing application data and
  initializes existing Box notes as empty.
- Current backups preserve optional Box notes without changing the portable
  format version.
- Backups created before Box notes remain restorable with empty notes.
- Backup Format Version 1 remains supported for legacy restore.
- Backups remain unencrypted and must be stored as sensitive files.

Production-signed builds beginning with `0.14.3+35` use the permanent identity
and certificate and can update directly to `1.1.0+50`. Builds using the former
application ID or a debug certificate require the documented backup, uninstall,
production install and restore transition.

## Automated Validation

Run from the repository root using the supported toolchain in
[toolchain-baseline.md](toolchain-baseline.md):

```text
flutter clean
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/platform/public_release_documentation_test.dart
flutter test test/platform/v1_1_release_documentation_test.dart
flutter test
```

On Windows, Flutter plugin builds require Developer Mode for symbolic-link
support. Dependency update notices are informational and are not a reason to
change the locked dependency graph during release validation.

Record the result:

- [x] `flutter pub get` completed without unintended lock-file changes
- [x] localization generation completed successfully
- [x] Dart formatting check completed without changes
- [x] `flutter analyze` reported no issues
- [x] public release-documentation tests passed
- [x] v1.1.0 release-documentation tests passed
- [x] complete automated test suite passed
- [x] final GitHub Actions **Quality gates** run passed on the release commit

## Focused Regression

The complete suite is authoritative. These focused commands are useful when a
failure must be isolated:

```text
flutter test test/drift/app_database/migration_test.dart
flutter test test/core/database/repositories/box_repository_test.dart
flutter test test/features/boxes/presentation/pages/new_box_page_test.dart
flutter test test/features/boxes/presentation/pages/box_edit_page_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_page_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_management_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_swipe_navigation_test.dart
flutter test test/features/animals/presentation/pages/animal_detail_page_test.dart
flutter test test/features/feedings/presentation/pages/feeding_reminder_settings_page_test.dart
flutter test test/features/settings/presentation/pages/settings_test.dart
flutter test test/features/settings/presentation/pages/settings_backup_test.dart
flutter test test/features/backup
flutter test test/l10n/localization_infrastructure_test.dart
```

- [x] Version 5 to Version 6 migration tests passed
- [x] Box note persistence and workflow tests passed
- [x] Box-detail layout, thumbnail, QR and deletion tests passed
- [x] Animal feeding-history and reminder-action tests passed
- [x] Settings About and accent-dropdown tests passed
- [x] optional safety-backup tests passed
- [x] current and legacy backup tests passed
- [x] English and German localization tests passed

## Release Builds

Create all supported artifacts from the same clean release commit:

```text
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

Android Release builds require the protected production signing configuration
described in [android-release-signing.md](android-release-signing.md).

Expected output paths:

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
- [x] the application reports Version `1.1.0` and Build `50`

## Signature and Artifact Verification

Follow [android-release-signing.md](android-release-signing.md) to verify the
APK and AAB. The APK and AAB must report the production certificate fingerprint
listed above. Record hashes from the final artifacts:

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
Get-FileHash build\app\outputs\bundle\release\app-release.aab -Algorithm SHA256
```

```text
APK SHA-256: E523032E398CBBCA832464E6A06474D23ED8345D20926D2BE217F52299FF65B1
AAB SHA-256: E42BA3C7149CDC32CB805A9E33A6EEC95486DD93038AC438A6DFDCA090EFD828
```

- [x] APK signature verification succeeded
- [x] APK certificate digest matches the permanent production certificate
- [x] AAB signature verification succeeded
- [x] APK and AAB SHA-256 values were recorded from the final artifacts
- [x] no keystore, password, private backup or other secret entered version
  control

## Manual Android Regression

Use a physical Android device and the final production-signed APK.

### Installation and general behaviour

- [x] install or update the final production build successfully
- [x] confirm the final artifact reports TerraManager, Version `1.1.0` and
  Build `50`
- [x] confirm existing local data survives an in-place production update
- [x] confirm navigation, language, appearance and overview ordering settings
  persist after restart
- [x] complete representative Box, Animal, FeedingEvent and QR workflows

### Box detail and edit workflows

- [x] assigned Animals with pictures show the correct thumbnail
- [x] assigned Animals without a usable picture show the fallback icon
- [x] tapping an assigned Animal still opens the correct Animal
- [x] Box information, notes and assigned Animals appear before the QR section
- [x] the QR section is last and shows the correct code and permanent identifier
- [x] QR PNG export still works and no Print action remains
- [x] create a Box with notes and confirm them on Box details
- [x] edit, clear and re-add Box notes and confirm persistence after restart
- [x] confirm Delete Box is absent from Box details
- [x] cancel deletion from Edit Box without changing data
- [x] delete an empty Box from Edit Box and return to the refreshed overview
- [x] confirm a Box with assigned Animals remains protected from deletion
- [x] confirm deletion behaves correctly after contextual Box-detail swiping

### Animal and reminder workflows

- [x] tap Latest Feeding and confirm the complete history opens
- [x] add, edit and delete a FeedingEvent and confirm history and reminder state
  refresh
- [x] open Feeding Reminder settings directly from an active Animal
- [x] enable, change and disable a reminder and confirm persistence
- [x] confirm ordinary Animal editing preserves reminder configuration
- [x] confirm archived Animals do not expose reminder configuration

### Settings and Restore

- [x] switch accent colors through the compact dropdown and confirm immediate
  persistent application
- [x] open About TerraManager and confirm Version `1.1.0`, Build `50` and
  developer `Codefrog`
- [x] start Restore and confirm the safety-backup option is enabled by default
- [x] restore with the option enabled and confirm a safety backup is created
- [x] restore an empty database with the option disabled and confirm no safety
  backup is created
- [x] cancel Restore without replacing current data

## Database and Backup Regression

- [x] update a Version 5 database and confirm all records and media remain
  available under Schema Version 6
- [x] confirm existing Boxes receive empty notes after migration
- [x] export a current Backup Format Version 2 archive containing Box notes
- [x] restore the current archive on Android and verify all data and settings
- [x] restore the current archive on Web and verify all data and settings
- [x] export a Web backup and restore it on Android
- [x] restore a pre-Box-notes Backup Format Version 2 archive with empty notes
- [x] restore a known valid Backup Format Version 1 archive
- [x] confirm legacy JPEG/PNG and current WebP pictures remain readable
- [x] reject an invalid archive without replacing current data
- [x] verify both enabled and disabled safety-backup paths

## Manual Web Regression

- [x] deploy or serve the complete final `build/web` directory
- [x] confirm startup and database persistence after reload
- [x] verify Box notes, assigned-Animal thumbnails and revised Box-detail order
- [x] verify QR display and PNG export without a Print action
- [x] verify Latest Feeding and dedicated Feeding Reminder navigation
- [x] verify the accent dropdown and About TerraManager information
- [x] verify Restore with the safety-backup option enabled and disabled
- [x] verify English and German interfaces
- [x] complete representative Box, Animal, FeedingEvent, media and backup
  workflows

## Documentation and Publication

- [x] version is `1.1.0+50` everywhere it represents the release candidate
- [x] `CHANGELOG.md` contains `[1.1.0] - 2026-09-12`
- [x] README and documentation index link this validation record
- [x] Roadmap records Issues #94–#100 and the pending Issue #101 validation
- [x] installation, platform, development, schema and backup documentation was
  reviewed for v1.1.0
- [x] automated and manual functional-regression results are recorded
- [x] final build, signature and artifact-hash results are recorded
- [x] Issue #101 is closed after all blocking validation succeeds
- [ ] annotated tag `v1.1.0` is created and pushed
- [ ] GitHub release `v1.1.0` is published with the verified APK
