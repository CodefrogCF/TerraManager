# v1.6.0 Release Validation

This document records the source and release-owner validation boundary for
TerraManager `1.6.0+62`. Version 1.6.0 completes the Batch QR Export milestone
delivered by Issues #116 and #117. Automated source checks are recorded
independently from signed artifacts, which are created only in the release
owner's protected environment.

## Release Highlights

- reuse one active and archived Box checklist for all three Settings exports
- save selected Box QR codes as individual PNG images
- save the selected PNG images together in one ZIP archive
- generate labeled, paginated A4 PDF sheets entirely on-device
- choose vector QR sizes from 6 mm to 20 mm
- provide 6, 10, 15 and 20 mm size presets
- identify printed codes with a safe Box name and stable Box number
- prevent partial ZIP or PDF output and false success after save cancellation
- add no broad storage, media or network permission

## Compatibility Baseline

- Application Version: **1.6.0+62**
- Database Schema Version: **9**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.5.0 installation can be updated directly. Version 1.6.0
does not change the database schema, backup format, application ID, certificate
or application storage paths. Existing Boxes, Animals, FeedingEvents, settings
and media remain available without migration.

Generated PNG, ZIP and PDF output remains derived data and is excluded from
portable backups. The permanent Box QR payload remains unchanged. ZIP and PDF
files are generated locally before the operating-system save dialog opens. The
Android manifest and iOS property list add no storage, media or network
permission for this workflow.

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
- [x] complete automated test suite passed with 643 tests
- [x] permission manifests remained unchanged
- [ ] final GitHub Actions **Quality gates** run passed on the release commit

Focused milestone coverage includes:

```text
flutter test test/features/settings/application/box_qr_batch_export_service_test.dart
flutter test test/features/settings/application/box_qr_archive_export_service_test.dart
flutter test test/features/settings/application/box_qr_pdf_export_service_test.dart
flutter test test/features/settings/presentation/box_qr_selection_dialog_test.dart
flutter test test/features/settings/presentation/pages/settings_qr_export_test.dart
flutter test test/features/settings/presentation/pages/settings_qr_document_export_test.dart
flutter test test/platform/qr_document_export_privacy_test.dart
flutter test test/platform/v1_6_release_documentation_test.dart
```

- [x] shared selection of active and archived Boxes passed
- [x] select-all, clear, individual opt-out, empty and cancellation passed
- [x] individual PNG, ZIP and PDF Settings integration passed
- [x] ZIP entries retain complete QR payloads and safe filenames
- [x] exact A4 bounds, automatic pagination and safe labels passed
- [x] 6 mm vector output decoded at a simulated 600 DPI print resolution
- [x] generation failures save no incomplete ZIP or PDF file
- [x] no additional device or network permission passed

## Release-owner Builds

The following commands document the protected release-owner workflow. Automated
assistants must not create TerraManager release artifacts because they do not
have the authoritative signing environment.

```text
flutter build apk --debug --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
flutter build web --release --no-pub
```

- [x] release owner produced and verified the supported artifacts
- [x] release APK reports Version `1.6.0` and Build `62`
- [x] release AAB reports Version `1.6.0` and Build `62`
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

- [x] select active and archived Boxes for each export type
- [x] save selected QR codes as individual images and confirm exact selection
- [x] inspect ZIP contents and scan representative extracted codes
- [x] print A4 PDF pages at 100% scale and measure selected QR sizes
- [x] scan 6 mm and 20 mm printed codes on representative Android hardware
- [x] verify labels, long names, pagination and repeated Box selections
- [x] cancel the system save dialog without a false success message
- [x] repeat individual, ZIP and PDF export in the supported Web browser
- [x] update a production-signed v1.5.0 Android installation without data loss

## Documentation and Publication

- [x] source version is `1.6.0+62`
- [x] `CHANGELOG.md` contains `[1.6.0] - 2026-09-15`
- [x] README, documentation index and roadmap describe Issues #116 and #117
- [x] architecture and privacy records document local document generation
- [x] annotated `v1.6.0` tag identifies the release source commit
- [x] GitHub release is published with the final release description
- [x] Google Play update is submitted with localized release notes
- [x] release-owner artifact links and hashes are recorded
