# v1.6.1 Release Validation

This document records the source and release-owner validation boundary for
TerraManager `1.6.1+63`. Version 1.6.1 completes the UX Consistency &
Localization milestone delivered by Issues #122–#126. Automated source checks
are recorded independently from signed artifacts, which are created only in
the release owner's protected environment.

## Release Highlights

- display stored Animal pictures as 56 px thumbnails in Animal History
- retain the existing Animal fallback for missing or invalid archived media
- simplify PDF QR sizing to one accessible integer slider from 6 mm to 20 mm
- preserve the established 15 mm default and exact A4 PDF output
- accept and display multiline free-form Weight content
- bundle synchronized English and German privacy policies
- show localized licence information while retaining the complete unchanged
  English GPL-3.0-or-later text as authoritative
- replace paired sort-direction entries with one directional toggle per
  criterion
- retain all existing setting, database and backup values
- add no media, storage or network permission

## Compatibility Baseline

- Application Version: **1.6.1+63**
- Database Schema Version: **9**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.6.0 installation can be updated directly. Version 1.6.1
does not change the database schema, backup format, application ID, production
certificate or application storage paths. Existing Boxes, Animals,
FeedingEvents, settings and media remain available without migration.

Weight remains the same nullable text value in Database Schema Version 9 and
Backup Format Version 2; only the form presentation changes. Existing Box and
Animal sort enum strings remain unchanged in preferences and backups. The
privacy translation and authoritative licence are bundled application assets.
They require neither a network connection nor additional device permissions.

## Automated Source Validation

Run from the repository root using the supported toolchain documented in
[toolchain-baseline.md](toolchain-baseline.md):

```text
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Recorded source result:

- [x] dependency resolution completed without an unexpected lock-file change
- [x] localization generation completed successfully
- [x] Dart formatting completed without changes
- [x] `flutter analyze --no-pub` reported no issues
- [x] complete automated test suite passed with 653 tests
- [x] database schema and portable backup format remained unchanged
- [x] Android and iOS permission declarations remained unchanged
- [ ] final GitHub Actions **Quality gates** run passed on the release commit

Focused milestone coverage includes:

```text
flutter test test/features/animals/presentation/pages/animal_history_ui_test.dart
flutter test test/features/settings/presentation/box_qr_selection_dialog_test.dart
flutter test test/features/settings/presentation/pages/settings_qr_document_export_test.dart
flutter test test/features/animals/presentation/pages/animal_additional_characteristics_test.dart
flutter test test/features/settings/presentation/pages/privacy_policy_page_test.dart
flutter test test/features/settings/presentation/pages/license_page_test.dart
flutter test test/features/boxes/presentation/pages/boxes_page_test.dart
flutter test test/features/animals/presentation/pages/animals_page_test.dart
flutter test test/platform/privacy_policy_sync_test.dart
flutter test test/platform/v1_6_1_release_documentation_test.dart
```

- [x] archived pictures, fallback media, semantics and navigation passed
- [x] slider-only 6–20 mm PDF sizing and unchanged output behavior passed
- [x] multiline Weight create, edit, reopen and detail display passed
- [x] English, German and fallback legal asset selection passed
- [x] synchronized public privacy content and unchanged GPL asset passed
- [x] sort defaults, direction reversal, persistence and detail order passed
- [x] no new device or network permission passed

## Release-owner Builds

The following commands document the protected release-owner workflow. They are
not part of automated update-package preparation. Automated assistants must not
create TerraManager release artifacts because they do not have the
authoritative signing environment.

```text
flutter build apk --debug --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
flutter build web --release --no-pub
```

- [ ] release owner produced and verified the supported artifacts
- [x] release APK reports Version `1.6.1` and Build `63`
- [ ] release AAB reports Version `1.6.1` and Build `63`
- [ ] Web release completed from the same source commit

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

- [x] inspect pictured, unpictured and missing-media entries in Animal History
- [x] open an archived Animal through both its thumbnail and list entry
- [x] choose the smallest, default and largest PDF QR size using only the slider
- [x] confirm individual PNG and ZIP export remain unchanged
- [x] enter, reopen and inspect a multiline Weight value
- [x] switch system, English and German app language and inspect both legal pages
- [x] confirm the German licence view includes the complete English GPL text
- [x] inspect both legal pages with large accessibility text
- [x] select each overview sort criterion, then select it again to reverse order
- [x] open and swipe details to confirm they follow visible overview order
- [x] update a production-signed v1.6.0 Android installation without data loss

## Documentation and Publication

- [x] source version is `1.6.1+63`
- [x] `CHANGELOG.md` contains `[1.6.1] - 2026-09-15`
- [x] README, documentation index and roadmap describe Issues #122–#126
- [x] English and German bundled privacy policies match their public pages
- [x] licence documentation preserves the authoritative repository `LICENSE`
- [ ] annotated `v1.6.1` tag identifies the release source commit
- [ ] GitHub release is published with the final release description
- [ ] Google Play update is submitted with localized release notes
- [ ] release-owner artifact links and hashes are recorded
