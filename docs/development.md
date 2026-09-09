# Development Guide

## Requirements

Current development environment:

- Windows 11
- Flutter stable
- Dart
- Android Studio
- Visual Studio Code
- Git

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

Schema Version 5 adds the nullable Animal columns
`feedingReminderIntervalDays` and `feedingReminderBaseline`. Migration tests
must verify that Version 4 data is preserved and both fields are initialized to
`null` for existing Animals.

## Android Development

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

Generated APKs are located under:

```text
build/app/outputs/flutter-apk
```

## Web Development

TerraManager uses SQLite WASM through Drift on Web.

Required files:

```text
web/sqlite3.wasm
web/drift_worker.dart
web/drift_worker.dart.js
```

## Drift Worker

Source:

```text
web/drift_worker.dart
```

Compile the worker with:

```text
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
```

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

## Recommended Validation Before Closing an Issue

Run:

```text
flutter analyze
flutter test
```

If platform-related code changed, additionally validate the affected platform manually.

Examples:

- camera access
- gallery storage
- browser downloads
- printing
- image picker
- picture cropping after Camera and Gallery selection
- WebP encoding of confirmed crops on Android and Web
- maximum 1920-pixel longest edge without upscaling
- `.webp` filename and `image/webp` MediaAsset metadata
- visible processing feedback and disabled picture/save actions during encoding
- duplicate-tap protection for picture processing and form saving
- reminder controls disabled by default for new Animals
- positive whole-day validation when a reminder is enabled
- reminder interval and baseline persistence after an application restart
- reminder configuration retention across archive and restore
- current and legacy backup round trips for reminder configuration
- reminder calculation from the later of baseline and latest FeedingEvent
- exact due-boundary behavior with an injected clock
- recalculation after FeedingEvent creation, editing and deletion
- disabled and archived Animal exclusion from reminder results
- due ordering from most overdue to least overdue
- reminder calculation after restoring current backup data
- absence of a reminder summary when no active Animal is due
- non-modal due summary, due count and due markers in the Animal Overview
- most-overdue-first order and navigation to the correct Animal
- due and scheduled status cards with the calculated due timestamp on Animal
  details
- immediate refresh after FeedingEvent creation, editing and deletion
- Animal Overview refresh after a QR Quick Feeding submission
- English and German reminder counts and status labels
- absence of automatically opened dialogs or system-notification permission
  requests
- atomic replacement that retains the old picture after processing/save errors
- WebP and legacy image display in overview, detail and full-screen contexts
- unchanged display and backup behavior for existing JPEG and PNG pictures
- mixed PNG/JPEG and WebP backup export, validation and restore
- restored filename, MIME type and byte-for-byte media equality
- persistent database storage
- System, English and German language selection
- language persistence and unsupported-locale fallback
- language-setting backup and restore
- oldest/newest and natural ascending/descending Box Overview sorting
- Box sort-order persistence after an application restart
- contextual Box detail swiping in the currently visible order
- Box sort-order backup, restore and legacy-backup default behavior
- oldest/newest creation order and natural ascending/descending Animal sorting
- oldest/youngest Animal sorting with missing birth dates placed deterministically
- newest/oldest FeedingEvent sorting with never-fed Animals placed deterministically
- Animal sorting based on the currently selected common/Latin primary name
- Animal sort-order persistence after an application restart
- contextual Animal detail swiping in the currently visible order
- Animal sort-order backup, restore and legacy-backup default behavior
- one bulk latest-feeding lookup for Animal sorting and reminder summaries

For image-storage measurements, use the same source picture and equivalent crop
before and after optimization. Record:

- source file byte size and dimensions
- stored WebP byte size and dimensions
- `.tmbackup` size or the corresponding archive media-entry size
- percentage reduction: `(originalBytes - webpBytes) / originalBytes * 100`

Test at least one landscape and one portrait photo. Also confirm that an
existing JPEG or PNG still opens and survives backup restore without being
rewritten.

The completed real-world measurement used a data set containing 44 Boxes, 45
Animals, 20 FeedingEvents and 67 pictures. Its portable backup decreased from
approximately 140 MB to 22.7 MB after normalization: about 117.3 MB or 83.8%
smaller, and roughly 6.2 times smaller overall.

## Recommended Release Validation

Before a milestone release:

```text
flutter clean
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build web
```

Then perform manual regression testing on validated target platforms.

The completed v0.14.0 validation record and release notes are available in:

```text
docs/release-v0.14.0.md
```

The completed v0.13.0 validation record and release notes are available in:

```text
docs/release-v0.13.0.md
```

The completed v0.12.0 validation and release record is available in:

```text
docs/release-v0.12.0.md
```

The completed v0.11.0 validation remains available in:

```text
docs/release-v0.11.0.md
```

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

Generated build output should not be committed.

Web runtime assets required by the application, such as `sqlite3.wasm` and the compiled Drift worker, must be present according to the project's repository policy.
