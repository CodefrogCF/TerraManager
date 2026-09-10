# v1.0.0 Release Validation

This document is the final validation and publication checklist for
TerraManager `1.0.0+39`.

Source and documentation preparation started on 2026-09-09. The complete local
regression, artifact verification and manual validation finished successfully
on the same day. The final GitHub Actions Quality gates run also passed on the
release commit.

Version 1.0.0 establishes the first stable TerraManager MVP baseline. It does
not introduce a new database schema or portable backup format beyond the
already validated pre-release builds.

## Release Highlights

- local-first Box, Animal and FeedingEvent management on Android and Web
- permanent Box QR identifiers, QR display, export, printing and scanning
- dedicated Feeding Mode with atomic single- and multi-Animal entries
- English and German interfaces with persistent language selection
- persistent appearance, Animal-name and overview-sorting preferences
- Animal archiving, history and contextual detail navigation
- optional per-Animal feeding reminders with non-modal due presentation
- Camera and Gallery picture selection, free-form cropping and bounded WebP
  normalization
- full-screen picture viewing and portable media-aware backups
- validated current and legacy `.tmbackup` restoration between Android and Web
- permanent `com.codefrog.terramanager` application identity
- production-signed Android releases with a stable update certificate
- GPL-3.0-or-later licensing and public privacy, support, security,
  installation and contribution documentation
- pinned continuous-integration quality gates and a documented toolchain
  baseline

## Compatibility Baseline

- Application Version: **1.0.0+39**
- Database Schema Version: **5** (unchanged)
- Portable Backup Format Version: **2** (unchanged)
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain prepared but unvalidated platforms.
- No database migration is required from `0.14.1+33` through `0.14.6+38`.
- Backup Format Version 1 remains supported for legacy restore.
- Backups remain unencrypted and must be stored as sensitive files.

Android releases through v0.14.1 used the temporary
`com.example.flutter_application_1` identity. Development build `0.14.2+34`
used the permanent identity with a debug certificate. Both require the
documented backup, uninstall, production install and restore transition.

Production-signed builds beginning with `0.14.3+35` use the permanent identity
and certificate and can update directly to `1.0.0+39`. Always create a current
backup before either update path.

## Automated Validation

Run from the repository root with the supported baseline from
[toolchain-baseline.md](toolchain-baseline.md):

On Windows, Flutter plugin builds require symbolic-link support. If
`flutter pub get` reports that symlink support is unavailable, run
`start ms-settings:developers`, enable **Developer Mode**, and repeat the
validation from `flutter pub get` before continuing.

```text
flutter clean
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/platform/toolchain_quality_gates_test.dart
flutter test test/platform/v1_release_documentation_test.dart
flutter test
```

Record the final result:

- [x] `flutter pub get` completed without unintended lock-file changes
- [x] Windows plugin symlink support is available after `flutter clean`
- [x] localization generation completed successfully
- [x] Dart formatting check completed without changes
- [x] `flutter analyze` reported no issues
- [x] toolchain and quality-gate regression tests passed
- [x] v1.0.0 release-documentation regression tests passed
- [x] complete automated test suite passed with 450 tests
- [x] the final GitHub Actions **Quality gates** run passed on the release commit

Dependency availability notices are informational. Do not update the locked
dependency graph during this release regression. The known future Built-in
Kotlin plugin warning and host-JDK warning are documented in
`toolchain-baseline.md` and are not hidden with unsafe flags.

## Release Builds

Create all supported artifacts from the same clean release commit:

```text
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

The two Release commands require the protected production signing
configuration from [android-release-signing.md](android-release-signing.md).
The public CI workflow deliberately builds only the Android Debug APK and Web
Release bundle.

Expected output paths:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
build/web
```

Record the result:

- [x] Android Debug APK completed successfully
- [x] production-signed Android Release APK completed successfully
- [x] production-signed Android App Bundle completed successfully
- [x] Web Release build completed successfully
- [x] the application reports Version `1.0.0` and Build `39`

## Android Signature and Artifact Verification

Verify the APK using the newest installed Android Build Tools version:

```powershell
$androidBuildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Directory |
  Sort-Object Name -Descending |
  Select-Object -First 1

& "$($androidBuildTools.FullName)\apksigner.bat" verify `
  --verbose `
  --print-certs `
  build\app\outputs\flutter-apk\app-release.apk
```

The reported signer certificate SHA-256 must exactly equal:

```text
f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748
```

Verify the App Bundle signature:

```powershell
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
```

Record SHA-256 hashes for both Android release artifacts:

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
Get-FileHash build\app\outputs\bundle\release\app-release.aab -Algorithm SHA256
```

Record the final values before publication:

```text
APK SHA-256: BA1852C6A5EBE5AF36A00E4929B45DD006CD2178720EB2599098A9A0EC9C6A21
AAB SHA-256: 59BD2A4DF3E84AB2403D51403BC25C619AD249ED764BE09B733406B877E8C6A6
```

- [x] APK signature verification succeeded
- [x] APK certificate digest matches the permanent production certificate
- [x] AAB signature verification succeeded
- [x] APK and AAB SHA-256 values were recorded from the final artifacts
- [x] no keystore, password or private backup entered version control

## Manual Android Regression

Use a physical Android device and the final production-signed APK.

### Installation, identity and settings

- [x] install or update the production build successfully
- [x] confirm TerraManager name, icon, Version `1.0.0` and Build `39`
- [x] confirm existing local data remains available after an in-place update
- [x] switch between System, English and Deutsch and restart the application
- [x] change theme, accent, Animal-name order and overview sort orders
- [x] confirm all selected settings persist after restart

### Boxes and QR workflows

- [x] create and edit a Box with optional dimensions
- [x] add, crop, replace, remove and open a Box picture full-screen
- [x] create a picture from Camera and select one from Gallery
- [x] display, export and print a Box QR code
- [x] scan a known Box QR code with the normal scanner
- [x] activate and deactivate the camera light where supported
- [x] confirm an invalid or unknown QR code produces a recoverable result
- [x] sort Boxes ascending and descending by natural Box number
- [x] swipe Box details in the visible overview order
- [x] confirm Add Animal is available for empty and populated Boxes

### Animals and reminders

- [x] create and edit an Animal with all relevant optional data
- [x] confirm exactly Male, Female and Unknown are offered
- [x] confirm localized birth-date-accuracy labels contain no raw enum values
- [x] add, crop, replace, remove and open an Animal picture full-screen
- [x] create a picture from Camera and select one from Gallery
- [x] sort Animals by creation, displayed name, age and latest feeding
- [x] switch Common-name-first and Latin-name-first and verify name sorting
- [x] swipe Animal details in the visible overview order
- [x] archive and restore an Animal while preserving history and settings
- [x] enable a reminder with and without existing FeedingEvents
- [x] confirm latest feeding and baseline fallback reminder calculation
- [x] confirm archived Animals do not appear in the due summary

### Feeding workflows

- [x] create, edit and delete a normal FeedingEvent
- [x] confirm reminder state refreshes after every FeedingEvent change
- [x] scan a Box in Feeding Mode and create a one-Animal feeding
- [x] create a multi-Animal feeding with optional notes
- [x] confirm saving returns immediately to a ready scanner
- [x] use **Scan a different Box** and confirm no unsaved event is created
- [x] activate and deactivate the Feeding Mode camera light where supported
- [x] confirm existing feeding history displays all newly created events

## Backup and Restore Regression

Never attach a real backup containing private Animal data or pictures to a
public Issue or release.

### Current format

- [x] export a fresh Backup Format Version 2 archive from Android
- [x] restore the current archive on Android
- [x] verify Boxes, Animals, FeedingEvents, pictures and settings
- [x] verify reminder configuration and both overview sort preferences
- [x] restore an Android backup on Web
- [x] export a current Web backup and restore it on Android
- [x] confirm a safety backup is created where supported

### Legacy paths

- [x] restore a known valid Backup Format Version 1 fixture
- [x] restore a pre-reminder Backup Format Version 2 fixture
- [x] confirm missing modern settings receive documented defaults
- [x] confirm legacy JPEG/PNG pictures display without forced conversion
- [x] confirm current WebP pictures survive export and restore
- [x] reject an invalid or corrupted archive without replacing current data

## Manual Web Regression

- [x] start or deploy the complete final `build/web` directory
- [x] confirm startup and local database persistence after reload
- [x] create, edit and delete representative Boxes, Animals and FeedingEvents
- [x] verify English and German interfaces and persistent settings
- [x] verify picture selection, crop, optimization and full-screen display
- [x] verify QR display, export and supported printing
- [x] verify current backup export and restore
- [x] confirm the browser origin and hosting limitations remain documented

## Documentation Review

- [x] version is `1.0.0+39` everywhere it represents the current build
- [x] `CHANGELOG.md` contains `[1.0.0] - 2026-09-09`
- [x] README identifies the stable MVP and validated platforms correctly
- [x] Roadmap records the final Issue #93 result
- [x] installation and update paths match the permanent identity and signature
- [x] privacy notice still matches actual permissions and data processing
- [x] support, security, contribution and GPL documentation remains linked
- [x] toolchain baseline matches the final CI workflow
- [x] final test, build, manual and artifact results are recorded here
