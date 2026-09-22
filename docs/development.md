# Development Guide

## Requirements

Supported toolchain baseline:

- Windows 11
- Flutter 3.47.2 stable
- the Dart SDK bundled with Flutter 3.47.2
- Java 17
- Android Studio
- Visual Studio Code
- Git

On Windows, enable **Developer Mode** so Flutter can create the symbolic links
required by plugin builds:

```powershell
start ms-settings:developers
```

Enable **Developer Mode** in the opened Windows settings page before running
`flutter pub get` or rebuilding after `flutter clean`.

The complete Flutter, Android, Java, dependency and CI baseline is maintained
in [toolchain-baseline.md](toolchain-baseline.md). Use a separate maintenance
change for upgrades; do not change the toolchain implicitly while closing a
feature or release Issue.

## Initial Setup

Clone the repository and install dependencies:

```text
flutter pub get
```

Run static analysis:

```text
flutter analyze
```

Run tests:

```text
flutter test
```

The same core checks and Android Debug/Web Release builds run in GitHub Actions
for every push and pull request. Production Android signing remains a local,
protected release task and is never required by the public quality-gate job.

## Public Project Documentation

The public repository must keep these root documents current:

- `LICENSE` — GPL-3.0-or-later licence text
- `PRIVACY.md` — local data, permissions, exports and Web-hosting boundaries
- `SUPPORT.md` — supported platforms and useful issue reports
- `SECURITY.md` — private-first vulnerability reporting
- `CONTRIBUTING.md` — contribution and copyright policy

User-facing installation and update guidance is maintained in
`docs/installation-and-updates.md`. A release change affecting persistence,
permissions, platform services, distribution, signing, network behaviour or
support must review these documents before the issue is closed.

### GitHub Pages homepage

GitHub Pages publishes the `docs/` directory at the project path
`https://codefrogcf.github.io/TerraManager/`. Repository Pages settings must
use the `main` branch and `/docs` source directory. Publication remains a
repository-owner action after the source change has been reviewed and merged.

The localized homepage has one shared structure:

- `docs/index.md` selects German at `/`
- `docs/en/index.md` selects English at `/en/`
- `docs/_layouts/home.html` contains the semantic page structure and metadata
- `docs/_data/home.yml` contains both localized content sets
- `docs/assets/` contains only bundled styles and media

Keep internal links and assets behind Jekyll's `relative_url` or `absolute_url`
filters so direct navigation continues to work below `/TerraManager/`. Do not
add analytics, trackers, cookie-dependent functionality, external scripts or
remote web fonts. The public Privacy Policy and GPL license must remain locally
reachable, and changes to either authoritative legal document must keep its
published copy synchronized.

TerraManager is licensed under GPL-3.0-or-later. Do not copy code, artwork,
translations or documentation from an incompatible or unknown source. The
current contribution policy requires prior agreement for substantial external
contributions so that copyright ownership remains suitable for a possible
future commercial dual-licensing model.

## Localization Generation

English and German source messages are stored in:

```text
lib/l10n/app_en.arb
lib/l10n/app_de.arb
```

After changing either catalog, regenerate the Flutter localization classes:

```text
flutter gen-l10n
```

Generated files in `lib/l10n/generated/` must not be edited manually.

## Drift Code Generation

When Drift tables, converters or database definitions change:

```text
dart run build_runner build
```

Generated files such as:

```text
lib/core/database/app_database.g.dart
```

must not be edited manually.

When the Drift schema changes, also update generated migration steps with:

```text
dart run drift_dev make-migrations
```

Migration output must be reviewed and covered by schema migration tests.

## Android Development

TerraManager uses the permanent Android namespace and application ID:

```text
com.codefrog.terramanager
```

The main Activity is located at:

```text
android/app/src/main/kotlin/com/codefrog/terramanager/MainActivity.kt
```

Do not change the application ID after v1.0. Android uses it as part of the
installed application's identity, storage isolation and update path.

List available devices:

```text
flutter devices
```

Run on Android:

```text
flutter run
```

Build debug APK:

```text
flutter build apk --debug
```

Build release APK:

```text
flutter build apk --release
```

Build release Android App Bundle:

```text
flutter build appbundle --release
```

Generated Android artifacts are located under:

```text
build/app/outputs/flutter-apk
build/app/outputs/bundle/release
```

## Web Development

TerraManager uses SQLite WASM through Drift on Web.

Repository-managed Web assets:

```text
web/sqlite3.wasm
web/drift_worker.dart
```

The compiled Drift worker is generated locally and in CI before a Web build.
The generated JavaScript, dependency list and source map are intentionally not
committed because they contain bundled dependency and Dart runtime code.

## Drift Worker

Source:

```text
web/drift_worker.dart
```

Compile the worker with:

```text
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
```

Run this command after `flutter pub get` and before `flutter build web`.

## SQLite WASM

`sqlite3.wasm` must match the compatible version of the resolved Dart `sqlite3` package.

Check the current dependency version with:

```text
flutter pub deps
```

After upgrading `sqlite3`, verify whether the Web WASM asset also needs to be updated.

Run Web Application:

```text
flutter run -d chrome
```

Build Web Application:

```text
flutter build web
```

## Current Regression Coverage

Changes to current Animal and archive workflows should preserve tests for:

- Version 14 to Version 15 migration and deterministic conversion of compatible
  legacy shedding notes
- shedding-history ordering, creation, editing, deletion, archiving and backup
  round trips
- Version 15 to Version 16 migration with both Animal detail sections enabled
- per-Animal Weight and Shedding visibility persistence and backup defaults
- birth-date removal together with birth-date-accuracy cleanup
- Big Picture Mode in Box, flat Animal and grouped Animal overviews
- Big Picture Mode persistence and portable backup restore
- next-feeding-summary calculation, persistence and backup compatibility
- unchanged due-reminder calculation and primary-navigation indication
- Animal and Box archive sorting and local preference persistence
- direct Restore and Duplicate archive actions
- QR Rehouse validation for active, archived, unknown and current Boxes
- atomic Animal reassignment and rollback on failure
- successful Rehouse navigation without duplicate route removal
- omission of unset or Unknown sex information from Animal details

Documentation tests must verify stable public links and required semantic
content. They must not require one exact application version or build number,
because release identifiers change independently from the documented contract.

## Recommended Validation Before Closing an Issue

Run:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

If platform-specific behaviour changed, validate the affected platform manually.
For public-documentation changes also run:

```text
flutter test test/platform/public_documentation_test.dart
```

For CI or toolchain changes also run:

```text
flutter test test/platform/toolchain_quality_gates_test.dart
```

Release validation is maintained separately in
[release-checklist.md](release-checklist.md).

## Git Workflow

Recommended workflow:

```text
Issue
  ↓
Implementation
  ↓
Tests
  ↓
Manual validation
  ↓
Commit
  ↓
Push
  ↓
Close issue
```

Use focused commits where practical.

Generated build output should not be committed. This includes
`web/drift_worker.dart.js`, `web/drift_worker.dart.js.deps` and
`web/drift_worker.dart.js.map`; the quality-gate workflow regenerates them
before building the Web release.

Web runtime assets required by the application, such as `sqlite3.wasm` and the
compiled Drift worker, must be present in the generated Web build output.
