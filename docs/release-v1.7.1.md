# v1.7.1 Release Validation

This document records the source and release-owner validation boundary for
TerraManager `1.7.1+65`. Version 1.7.1 completes the enclosure-note migration
and QR Settings refinements prepared after v1.7.0. Automated source checks are
recorded independently from signed artifacts, which are created only in the
release owner's protected environment.

## Release Highlights

- move the optional temperature-zone note from Animal forms and details to the
  owning Box
- place the multiline field directly above ordinary Notes on New Box and Edit
  Box and show it on Box details only when populated
- preserve Box temperature zones through editing, duplication and portable
  backup
- advance the database through an explicit Schema Version 10 to 11 step
- transfer the first non-empty legacy assigned-Animal value by Animal ID to an
  empty Box during database migration and backup restore
- retain the released Schema Version 10 snapshot without retroactive changes
- shorten the individual Box QR export description
- separate PNG, ZIP and PDF export actions with standard Settings dividers
- add no storage, media, network or other device permission

## Compatibility Baseline

- Application Version: **1.7.1+65**
- Database Schema Version: **11**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.7.0 installation follows the direct v10 to v11
migration. A v1.6.x installation follows the ordered v9 to v10 taxonomy step
and then v10 to v11. Both paths preserve existing Boxes, Animals,
FeedingEvents, settings and media.

Schema Version 11 adds nullable `Box.temperatureZones`. The migration considers
legacy `Animal.temperatureZones` values in ascending Animal ID order and copies
the first non-empty trimmed value to its assigned Box when that Box has no
value. Boxes without an eligible source remain empty, and foreign-key
relationships remain valid. The legacy Animal column stays readable for
database and backup compatibility but is no longer used by current Animal UI or
repository writes.

Portable Backup Format Version 2 remains current. Current exports write the
authoritative value on the Box. Format 1 and older Format 2 backups without the
Box key restore safely, and a legacy assigned-Animal value can seed an empty
Box. Restore never replaces a populated Box value.

## Automated Source Validation

Run from the repository root using the supported toolchain documented in
[toolchain-baseline.md](toolchain-baseline.md):

```text
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev make-migrations
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Recorded source result:

- [x] the released Schema Version 10 snapshot was restored unchanged
- [x] the Schema Version 11 snapshot and ordered migration helper were generated
- [x] Dart formatting completed without changes
- [x] `flutter analyze --no-pub` reported no issues
- [x] 67 focused migration tests passed
- [x] the complete automated suite passed with 691 tests
- [x] Android and iOS permission declarations remained unchanged
- [ ] final GitHub Actions **Quality gates** run passed on the release commit

Focused patch coverage includes:

```text
flutter test test/drift/app_database/box_temperature_zones_migration_test.dart
flutter test test/drift/app_database/animal_taxonomy_migration_test.dart
flutter test test/drift/app_database/migration_test.dart
flutter test test/features/backup/application/box_lifecycle_backup_test.dart
flutter test test/features/backup/application/backup_export_service_test.dart
flutter test test/features/backup/application/backup_restore_service_test.dart
flutter test test/features/boxes/presentation/pages/new_box_page_test.dart
flutter test test/features/boxes/presentation/pages/box_edit_page_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_page_test.dart
flutter test test/features/settings/presentation/pages/settings_qr_document_export_test.dart
flutter test test/platform/v1_7_release_documentation_test.dart
flutter test test/platform/public_release_documentation_test.dart
```

- [x] direct populated v10 to v11 migration passed
- [x] deterministic first-value selection and whitespace trimming passed
- [x] empty Boxes and foreign-key integrity passed
- [x] Box create, edit, detail and duplication behavior passed
- [x] backup export, validation, restore and legacy fallback passed
- [x] PNG, ZIP and PDF Settings actions retain their shared selection workflow
- [x] migration tests avoid a hard-coded current schema-number assertion
- [x] no new device or network permission passed

## Release-owner Builds

Signed Android and hosted Web artifacts remain release-owner work. No release
build was created during source or documentation package preparation.

- [x] release owner produced and verified the supported artifacts
- [x] release APK reports Version `1.7.1` and Build `65`
- [x] release AAB reports Version `1.7.1` and Build `65`
- [x] Web release completed from the same source commit

## Signature and Artifact Verification

Verification follows
[android-release-signing.md](android-release-signing.md). Record only artifacts
created in the release owner's protected environment.

```text
APK SHA-256: PENDING RELEASE-OWNER ARTIFACT
AAB SHA-256: PENDING RELEASE-OWNER ARTIFACT
Web archive SHA-256: PENDING RELEASE-OWNER ARTIFACT
```

- [ ] APK signature verification succeeded
- [ ] certificate digest matches the permanent production certificate
- [ ] final artifact hashes were recorded
- [x] no signing credential or private key entered the source package

## Manual Android and Web Validation

- [x] update a populated production-signed v1.7.0 installation
- [x] update a populated production-signed v1.6.x installation
- [x] confirm Animals, Boxes, feeding history, settings and media remain present
- [x] confirm a legacy Animal temperature-zone value appears on its assigned Box
- [x] confirm an empty Box remains empty when no legacy value exists
- [x] add, edit, clear and display a Box temperature-zone note
- [x] duplicate a Box and confirm its temperature-zone note is copied
- [x] export and restore a current backup containing Box temperature zones
- [x] restore an older backup containing only an Animal temperature-zone value
- [x] inspect the PNG, ZIP and PDF Settings action layout and shared selection
- [x] confirm no new device permission request appears

## Documentation and Publication

- [x] source version is `1.7.1+65`
- [x] `CHANGELOG.md` contains `[1.7.1] - 2026-09-15`
- [x] README, documentation index and roadmap describe the patch
- [x] Schema Version 10 history and Schema Version 11 behavior are separated
- [x] Backup Format Version 2 compatibility and permission boundaries are
  documented
- [x] annotated `v1.7.1` tag identifies the release source commit
- [x] GitHub release is published with the final release description
- [x] Google Play update is submitted with localized release notes
- [ ] release-owner artifact links and hashes are recorded
