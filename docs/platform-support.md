# Platform Support

This document describes the current platform validation status of TerraManager.

## Status

| Platform | Status |
|---|---|
| Android | Validated |
| Web | Validated |
| iOS | Planned / not validated |

The completed v0.11.0 release validation is documented in
`release-v0.11.0.md`. The platform lists below include this regression.

The final Android/Web regression for the v0.12.0 release candidate is tracked
in `release-v0.12.0.md`. Platform claims are updated only after those checks
have completed.

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
- full-screen Box picture viewing with zooming and panning
- Box and Animal overview thumbnails
- FeedingEvent editing and deletion
- dedicated QR Feeding Mode from the Box Overview
- active-Animal resolution for a scanned Box
- single- and multi-Animal quick feeding entries
- atomic grouped FeedingEvent creation and duplicate-submission protection
- scanner restart after saving or cancelling a quick feeding
- preserved overview scroll position after detail navigation
- contextual horizontal swipe navigation between Box details
- contextual horizontal swipe navigation between Animal details from Active
  Animals, Animal History and Box-specific Animal collections
- first and last contextual navigation boundaries
- detail actions after swiping and Back navigation to the originating overview
- normal detail navigation without a swipe context
- animal creation and persistence
- feeding history
- notes
- persistent animal pictures
- animal picture persistence across application restarts
- full-screen Animal picture viewing with zooming and panning
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
- Common-name-first / Latin-name-first Animal presentation
- immediate Animal name-order changes and persistence across application
  restarts
- complete English and German interfaces
- System / English / Deutsch language selection
- immediate language changes and persistence across application restarts
- portable `.tmbackup` creation
- user-selectable backup destination through the Android system file picker
- backup file selection
- backup validation
- pre-restore safety backup
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
- appearance-, language- and Animal-name-setting backup and restore
- restore compatibility for backups without a language setting
- restore of Web-created backups
- camera-light controls in the Box and Feeding Mode scanners
- Camera and Gallery picture selection for new and edited Boxes and Animals
- compact Add Picture and Change Picture actions
- recoverable picture-source cancellation and denied camera permission

QR images saved on Android are stored through the platform media/gallery system
so they remain accessible to the user outside the application.

TerraManager backup files use the Android system file selection interface.
The user can therefore choose an accessible destination such as Downloads,
Documents or another available storage provider.

Box and Animal pictures are stored persistently through Drift in the
`MediaAssets` table. Animal `picturePath` values are retained only as a legacy
migration fallback.

New and edited Box and Animal forms expose one context-sensitive Add Picture or
Change Picture action. It opens a source menu for Camera and Gallery. The Camera
option is disabled if the active platform implementation reports that capture
is unsupported. Cancelling selection or denying access leaves the existing
picture unchanged and keeps the form usable.

After crop confirmation, Android encodes new and replaced pictures as WebP with
quality 82 and limits their longest edge to 1920 pixels without upscaling.
Existing pictures remain unchanged.

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
- full-screen Box picture viewing with zooming and panning
- Box and Animal overview thumbnails
- FeedingEvent editing and deletion
- dedicated QR Feeding Mode from the Box Overview
- active-Animal resolution for a scanned Box
- single- and multi-Animal quick feeding entries
- atomic grouped FeedingEvent creation and duplicate-submission protection
- scanner restart after saving or cancelling a quick feeding
- preserved overview scroll position after detail navigation
- contextual horizontal swipe navigation between Box details
- contextual horizontal swipe navigation between Animal details from Active
  Animals, Animal History and Box-specific Animal collections
- first and last contextual navigation boundaries
- detail actions after swiping and Back navigation to the originating overview
- normal detail navigation without a swipe context
- feeding data
- persistent animal pictures
- animal picture persistence across normal browser reloads
- full-screen Animal picture viewing with zooming and panning
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
- Common-name-first / Latin-name-first Animal presentation
- immediate Animal name-order changes and persistence across normal browser
  reloads
- complete English and German interfaces
- System / English / Deutsch language selection
- immediate language changes and persistence across normal browser reloads
- portable `.tmbackup` download
- backup file selection
- backup validation
- pre-restore safety backup
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
- appearance-, language- and Animal-name-setting backup and restore
- restore compatibility for backups without a language setting
- restore of Android-created backups
- both QR scanners with camera-light controls hidden when unsupported
- compact Add Picture and Change Picture actions
- Gallery picture selection for new and edited Boxes and Animals
- disabled Camera source when browser capture is unsupported

WebP optimization for new and replaced pictures is implemented through browser
Canvas encoding but remains pending manual Web milestone validation.

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

New picture bytes are normalized before persistence. Backup restore deliberately
does not recompress restored media, preserving compatibility and avoiding
generation loss.

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

`settings.json` preserves theme mode, accent color, application language and
preferred Animal name order. Backups without the newer settings fields remain
compatible and restore their documented defaults.

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
Animal pictures and local appearance and language settings.

Portable `.tmbackup` files stored outside the browser can be used to restore
data after such a loss.

Private/incognito browser modes may not provide reliable long-term persistence.

### Camera

QR scanning requires:

- browser camera support
- user camera permission
- a secure browser context

The scanner camera-light control is available only when the active camera and
platform report torch support. It remains hidden otherwise. The current Web
scanner dependency reports the torch as unavailable, so Web scanning continues
without this control.

Camera access generally requires:

```text
https://
```

or:

```text
localhost
```

Behavior may vary between browsers and devices.

Camera-based picture capture also depends on browser and device support. When
the browser does not expose it through the image picker, TerraManager disables
the Camera option in the source menu while keeping Gallery selection available.

### Downloads

QR images and TerraManager backup files are downloaded through browser
facilities.

The final download location therefore depends on browser and operating-system
settings.

### Printing

QR printing uses browser/system printing facilities.

Available printers and print options depend on the browser and operating
system.

### Application preferences

Appearance and language settings are stored locally through
`shared_preferences`.

Clearing browser site data may therefore reset both the TerraManager database
and locally stored application preferences.

Appearance and language settings are included in portable TerraManager backups.

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
