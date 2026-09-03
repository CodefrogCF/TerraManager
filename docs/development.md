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
- persistent database storage

## Recommended Release Validation

Before a milestone release:

```text
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build web
```

Then perform manual regression testing on validated target platforms.

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
