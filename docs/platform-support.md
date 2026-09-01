# Platform Support

This document describes the current platform validation status of TerraManager.

## Status

| Platform | Status |
|---|---|
| Android | Validated |
| Web | Validated |
| iOS | Planned / not validated |

## Android

Android support has been validated on physical hardware.

Validated functionality includes:

- debug APK build
- release APK build
- application startup
- core navigation
- Drift/SQLite persistence
- box creation and persistence
- animal creation and persistence
- feeding history
- notes
- animal pictures
- QR display
- QR PNG generation
- QR image storage in the Android media gallery
- QR printing
- camera permission handling
- QR scanning
- invalid QR handling
- unknown QR handling

QR images saved on Android are stored through the platform media/gallery system so they remain accessible to the user outside the application.

## Web

Web support has been validated using a Chromium-based browser.

Validated functionality includes:

- Web build
- application startup
- navigation
- Drift database operation
- persistence across normal browser reloads
- box and animal workflows
- feeding data
- animal pictures
- QR display
- QR PNG download
- QR scanning
- camera permission handling
- QR printing

## Web Database

Web persistence uses Drift with SQLite WASM.

Required files:

```text
web/sqlite3.wasm
web/drift_worker.dart
web/drift_worker.dart.js
```

The Drift worker is compiled using:

```text
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
```

The `sqlite3.wasm` version must remain compatible with the `sqlite3` Dart package resolved by the project.

## Known Web Limitations

### Browser-managed storage

Application data is stored in browser-managed local storage.

Clearing site data may remove the TerraManager database.

Private/incognito browser modes may not provide reliable long-term persistence.

### Camera

QR scanning requires:

- browser camera support
- user camera permission
- a secure browser context

Camera access generally requires:

```text
https://
```

or:

```text
localhost
```

Behavior may vary between browsers and devices.

### Downloads

QR image downloads are controlled by the browser.

The final download location therefore depends on browser and operating-system settings.

### Printing

QR printing uses browser/system printing facilities.

Available printers and print options depend on the browser and operating system.

## iOS

TerraManager is intended to support iOS in the future.

iOS has not yet been validated because no macOS build environment or physical iOS test device is currently available.

The following therefore remain unverified:

- iOS compilation
- application startup
- SQLite persistence
- gallery/image persistence
- camera permissions
- QR scanning
- QR image storage
- QR printing

iOS must not currently be described as a validated platform.