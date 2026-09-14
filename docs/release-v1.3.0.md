# v1.3.0 Release Validation

This document records TerraManager `1.3.0+55`. The release owner confirmed on
2026-09-14 that this version and build are current in GitHub and Google Play.
Automated source validation is recorded separately from signed artifacts,
which are created only in the release owner's protected environment.

Version 1.3.0 completes the Primary Page Navigation work delivered by Issue
#106 and the release regression, documentation and publication preparation
tracked by Issue #107. It also includes the related stale Animal Overview fix
found during this regression.

## Release Highlights

- swipe horizontally between Box Overview, Animal Overview and Settings
- keep the navigation selection synchronized with swipe and tap input
- retain primary-page scroll positions, sorting and Settings state
- offer localized navigation semantics and `Ctrl+Page Up` / `Ctrl+Page Down`
- preserve independent contextual Animal and Box detail swipes
- prevent vertical Settings gestures, dropdowns and pushed routes from
  triggering root navigation
- refresh Animal Overview immediately after direct creation from Box details

## Compatibility Baseline

- Application Version: **1.3.0+55**
- Database Schema Version: **8**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.2.0 installation can be updated directly. Version 1.3.0
does not change the database schema, backup format, application ID, certificate
or storage paths. Boxes, Animals, FeedingEvents, settings and media remain
available without migration.

Current Backup Format Version 2 and legacy Format 1 restore remain unchanged.
Backups continue to preserve Box and Animal media, overview sorting, lifecycle
metadata and all other supported settings. Backups remain unencrypted and must
be stored as sensitive files.

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
- [x] complete automated test suite passed with 562 tests
- [ ] final GitHub Actions **Quality gates** run passed on the release commit

The focused navigation regression includes:

```text
flutter test test/features/app_shell_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_swipe_navigation_test.dart
flutter test test/features/animals/presentation/pages/animal_detail_swipe_navigation_test.dart
flutter test test/features/settings/presentation/pages/settings_test.dart
flutter test test/features/media/presentation/pages/picture_crop_page_test.dart
flutter test test/l10n/localization_infrastructure_test.dart
flutter test test/platform/v1_3_release_documentation_test.dart
```

- [x] swipe, navigation-bar and keyboard page changes passed
- [x] navigation selection, semantics and first/last boundaries passed
- [x] Box Overview scroll and sort retention passed
- [x] vertical Settings scrolling and open-dropdown isolation passed
- [x] contextual Animal and Box detail swipes and Back behaviour passed
- [x] immediate Animal Overview refresh after Box-detail creation passed
- [x] migration and current/legacy backup regression remained green

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

Expected outputs:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
build/web
```

- [x] release owner produced the Google Play artifact
- [x] Google Play submission uses Version `1.3.0` and Build `55`
- [x] existing release APK reports Version `1.3.0` and Build `55`
- [x] GitHub and Google Play version state was confirmed by the release owner

## Signature and Artifact Verification

The existing Android Release APK produced by the release owner was inspected
without rebuilding it. Verification follows
[android-release-signing.md](android-release-signing.md). Its certificate
digest matches the permanent production certificate above.

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
APK SHA-256: 23E3E2233C5ADA9F7C3A8E2C91E3C19BB4A32383B1B072E5FEF4D15DAFAF1DD8
```

- [x] APK signature verification succeeded
- [x] APK certificate digest matches the permanent production certificate
- [x] APK SHA-256 was recorded from the release-owner artifact
- [x] signed Google Play artifact remains owned by the protected release
  environment
- [x] no signing credential or private key entered the release package

## Navigation and Upgrade Regression

- [x] navigate Boxes → Animals and Animals → Boxes by horizontal swipe
- [x] navigate Animals → Settings and Settings → Animals by horizontal swipe
- [x] keep the current bottom-navigation destination visibly selected
- [x] select all three destinations directly through navigation-bar taps
- [x] retain overview scroll offsets and persistent sort choices
- [x] keep vertical Settings scrolling and dropdown interaction independent
- [x] retain contextual detail swipe boundaries and source ordering
- [x] preserve platform Back behaviour for root and pushed detail pages
- [x] expose English and German primary-navigation semantics
- [x] refresh a previously loaded Animal Overview after Box-detail creation
- [x] preserve Schema Version 8 and Backup Format Version 2 compatibility

## Manual Android and Web Validation

- [x] update a production-signed v1.2.0 Android installation without data loss
- [x] swipe across all root pages on a physical Android device
- [x] verify vertical lists, Settings controls, dialogs, dropdowns and picture
  gestures on the physical device
- [x] create an Animal from Box details and confirm immediate overview display
- [x] verify contextual detail swipes and Android system Back
- [x] deploy the complete Web build to a test origin and repeat root navigation
- [x] confirm browser Back, keyboard shortcuts and pointer scrolling on Web

## Documentation and Publication

- [x] version is `1.3.0+55`
- [x] `CHANGELOG.md` contains `[1.3.0] - 2026-09-14`
- [x] README and documentation index link this validation record
- [x] Roadmap records Issues #106 and #107
- [x] navigation behaviour and architecture are documented
- [x] installation, platform, development, schema, backup, privacy, support and
  security documentation were reviewed for the release
- [x] release-owner build boundary, APK signature and APK hash are recorded
- [x] GitHub records Version `1.3.0+55`
- [x] Google Play received Version `1.3.0` with Build `55`
- [x] close Issues #106 and #107 after the final documentation commit succeeds
