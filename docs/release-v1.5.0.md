# v1.5.0 Release Validation

This document records the source and release-owner validation boundary for
TerraManager `1.5.0+60`. Version 1.5.0 completes the Overview Quick Actions
milestone delivered by Issues #114 and #115. Automated source checks are
recorded independently from signed artifacts, which are created only in the
release owner's protected environment.

## Release Highlights

- open localized Animal and Box overview actions by long press or secondary
  click
- create a feeding, rename, edit, archive or duplicate an active Animal
- rename, edit, duplicate or archive an active Box
- duplicate archived Animals from Animal History
- create duplicates as independent active records with new database identities
- generate a new permanent QR identifier for every duplicated Box
- copy reusable profile values and picture bytes into independent records
- omit lifecycle metadata and Animal feeding history from duplicates

## Compatibility Baseline

- Application Version: **1.5.0+60**
- Database Schema Version: **9**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.4.0 installation can be updated directly. Version 1.5.0
does not change the database schema, backup format, application ID, certificate
or storage paths. Existing Boxes, Animals, FeedingEvents, settings and media
remain available without migration.

Duplicated records are ordinary Schema Version 9 records. Backup Format Version
2 exports them and their independent MediaAssets without a special duplicate
marker. Current and legacy backup restore behavior remains unchanged. Backups
remain unencrypted and must be stored as sensitive files.

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

- [x] localization generation completed successfully
- [x] Dart formatting completed without changes
- [x] `flutter analyze --no-pub` reported no issues
- [x] complete automated v1.5.0 test suite passed
- [x] Schema Version 9 and Backup Format Version 2 remained unchanged
- [ ] final GitHub Actions **Quality gates** run passed on the release commit

Focused milestone coverage includes:

```text
flutter test test/core/database/repositories/duplication_repository_test.dart
flutter test test/features/backup/application/duplication_backup_test.dart
flutter test test/features/quick_actions/overview_context_menu_test.dart
flutter test test/l10n/localization_infrastructure_test.dart
flutter test test/platform/v1_5_release_documentation_test.dart
```

- [x] long-press and secondary-click activation passed
- [x] all active Animal and Box quick actions passed
- [x] archived-Animal duplication passed
- [x] independent IDs, Box QR identifiers and MediaAssets passed
- [x] active duplicate lifecycle and cleared archive metadata passed
- [x] excluded Animal feeding history passed
- [x] backup export of duplicated records and pictures passed

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
- [x] release APK reports Version `1.5.0` and Build `60`
- [x] release AAB reports Version `1.5.0` and Build `60`
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

- [x] open Animal and Box menus by long press on Android
- [x] open the same menus by secondary click on Web
- [x] complete every active quick action and confirm immediate overview refresh
- [x] duplicate active and archived Animals into an active Box
- [x] duplicate a Box and scan its new QR identifier independently
- [x] edit and delete duplicates without changing source pictures or records
- [x] create and restore a backup containing source and duplicated records
- [x] update a production-signed v1.4.0 Android installation without data loss

## Documentation and Publication

- [x] source version is `1.5.0+60`
- [x] `CHANGELOG.md` contains `[1.5.0] - 2026-09-15`
- [x] README, documentation index and roadmap describe Issues #114 and #115
- [x] data-model and architecture records document independent duplication
- [x] annotated `v1.5.0` tag identifies the release source commit
- [x] GitHub release is published with the final release description
- [x] release-owner artifact links and hashes are recorded

