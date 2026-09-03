# Platform Support

This document describes the current platform validation status of TerraManager.

## Status

| Platform | Status |
|---|---|
| Android | Validated |
| Web | Validated |
| iOS | Planned / not validated |

Portable Backup Format Version 2 has been validated between the currently
supported platforms. Backup Format Version 1 remains supported for legacy restore:

```text
Android → Android
Web → Web
Android → Web
Web → Android
```

## Android

Android support has been validated on physical hardware.

Validated functionality includes:

- debug APK build
- release APK build
- application startup
- core navigation
- Drift/SQLite persistence
- box creation and persistence
- Box editing and optional dimensions
- persistent Box pictures
- Box picture persistence across normal application restarts
- Box and Animal overview thumbnails
- FeedingEvent editing and deletion
- preserved overview scroll position after detail navigation
- animal creation and persistence
- feeding history
- notes
- persistent animal pictures
- animal picture persistence across application restarts
- QR display
- QR PNG generation
- QR image storage in the Android media gallery
- QR printing
- camera permission handling
- QR scanning
- invalid QR handling
- unknown QR handling
- animal lifecycle and archiving
- Animal History
- restoring archived animals
- permanent deletion of archived animals
- latest feeding display
- System / Light / Dark appearance selection
- accent color selection
- appearance-setting persistence across application restarts
- portable `.tmbackup` creation
- user-selectable backup destination through the Android system file picker
- backup file selection
- backup validation
- pre-restore safety backup
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
- appearance-setting backup and restore
- restore of Web-created backups

QR images saved on Android are stored through the platform media/gallery system
so they remain accessible to the user outside the application.

TerraManager backup files use the Android system file selection interface.
The user can therefore choose an accessible destination such as Downloads,
Documents or another available storage provider.

Box and Animal pictures are stored persistently through Drift in the
`MediaAssets` table. Animal `picturePath` values are retained only as a legacy
migration fallback.

## Web

Web support has been validated using a Chromium-based browser.

Validated functionality includes:

- Web build
- application startup
- navigation
- Drift database operation
- persistence across normal browser reloads
- box and animal workflows
- Box editing and optional dimensions
- persistent Box pictures
- Box picture persistence across normal browser reloads
- Box and Animal overview thumbnails
- FeedingEvent editing and deletion
- preserved overview scroll position after detail navigation
- feeding data
- persistent animal pictures
- animal picture persistence across normal browser reloads
- QR display
- QR PNG download
- QR scanning
- camera permission handling
- QR printing
- animal lifecycle and archiving
- Animal History
- restoring archived animals
- permanent deletion of archived animals
- latest feeding display
- System / Light / Dark appearance selection
- accent color selection
- appearance-setting persistence across normal browser reloads
- portable `.tmbackup` download
- backup file selection
- backup validation
- pre-restore safety backup
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
- appearance-setting backup and restore
- restore of Android-created backups

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

The `sqlite3.wasm` version must remain compatible with the `sqlite3` Dart
package resolved by the project.

Persistent Box and Animal pictures are stored as `MediaAssets` through the same
Drift database abstraction used by the rest of the application.

## Backup Portability

TerraManager Backup Format Version 2 is the current portable format and avoids
platform-specific storage identifiers. Version 1 remains supported for legacy
restore.

Portable backups contain:

```text
manifest.json
data.json
settings.json
media/
├── animals/
└── boxes/
```

Backups do not depend on:

- Android application filesystem paths
- Web Blob URLs
- raw SQLite database files
- internal MediaAsset IDs

Box and Animal pictures are exported as portable media files and restored into
the local `MediaAssets` persistence layer.

The following transfers have been manually validated:

```text
Android backup → Android restore
Web backup     → Web restore
Android backup → Web restore
Web backup     → Android restore
```

## Known Web Limitations

### Browser-managed storage

Application data is stored in browser-managed local storage.

Clearing site data may remove the TerraManager database, persistent Box and
Animal pictures and local appearance settings.

Portable `.tmbackup` files stored outside the browser can be used to restore
data after such a loss.

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

QR images and TerraManager backup files are downloaded through browser
facilities.

The final download location therefore depends on browser and operating-system
settings.

### Printing

QR printing uses browser/system printing facilities.

Available printers and print options depend on the browser and operating
system.

### Appearance preferences

Appearance settings are stored locally through `shared_preferences`.

Clearing browser site data may therefore reset both the TerraManager database
and locally stored appearance preferences.

Appearance settings are included in portable TerraManager backups.

## iOS

TerraManager is intended to support iOS in the future.

iOS has not yet been validated because no macOS build environment or physical
iOS test device is currently available.

The following therefore remain unverified:

- iOS compilation
- application startup
- SQLite persistence
- persistent MediaAssets
- image selection
- camera permissions
- QR scanning
- QR image storage
- QR printing
- backup creation
- backup file selection
- backup restore

iOS must not currently be described as a validated platform.
