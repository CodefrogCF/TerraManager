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

The completed v0.12.0 media and Android/Web regression is documented in
`release-v0.12.0.md`. The platform lists below include this validation.

The completed v0.13.0 Feeding Reminder regression and release-build validation
is documented in `release-v0.13.0.md`. The platform lists below include this
validation.

The completed v0.14.0 Pre-1.0 UX Polish regression and release-build validation
is documented in `release-v0.14.0.md`. The platform lists below include this
validation.

The completed v0.14.1 Post-release Fixes regression and release-build
validation is documented in `release-v0.14.1.md`. The platform lists below
include this validation.

The final Android and Web regression for release candidate `1.0.0+39` is
tracked in `release-v1.0.0.md`. Its result is not considered complete until the
automated checks, signed artifacts, backup paths and manual platform checklist
in that document have been confirmed.

Portable Backup Format Version 2 has been validated between the currently
supported platforms. Backup Format Version 1 remains supported for legacy restore:

```text
Android → Android
Web → Web
Android → Web
Web → Android
```

## Permanent Application Identity

Development build `0.14.2+34` adopts `com.codefrog.terramanager` as the
permanent application identifier. Android and Web remain the validated target
platforms. Matching identifiers and names in the prepared iOS, macOS, Linux and
Windows projects remove Flutter placeholders but do not constitute platform
validation.

Android releases through v0.14.1 used
`com.example.flutter_application_1`. Android installs the permanent-ID build as
a separate application. Users must create a `.tmbackup` with the old version,
restore it in the new application and verify their data before removing the old
installation.

## Android Production Signing

Development build `0.14.3+35` removes debug signing from the Android Release
build type. The build reads production credentials from the ignored
`android/key.properties` file or from `TERRAMANAGER_*` environment variables.
Debug builds do not require either source. Release builds stop before packaging
when configuration is missing, incomplete or points to a missing keystore.

The signing key itself is deliberately not part of the repository. Production
APK and AAB construction, certificate verification, secure key backup and the
physical-device transition were validated by the release owner. The complete
procedure remains documented in `android-release-signing.md`.

Build `0.14.2+34` already uses the permanent application ID but is signed with
the Android debug certificate. Android therefore cannot install the first
production-signed build as an update over it. Create and verify a `.tmbackup`,
uninstall the debug-signed application, install the production-signed build and
restore the backup. Future directly distributed builds must keep the same
production signing certificate.

## Android

Android support has been validated on physical hardware.

Validated functionality includes:

- debug APK build
- pre-production release APK builds through `0.14.2+34`
- production-signed APK and AAB builds from `0.14.3+35`
- APK Signature Scheme v2 verification with the expected RSA 4096-bit
  production certificate
- AAB signature and release-artifact checksum verification
- backup-based transition from the debug-signed permanent-ID build
- application startup
- permanent `com.codefrog.terramanager` application identity
- TerraManager application name and launcher icon
- core navigation
- Drift/SQLite persistence
- box creation and persistence
- natural ascending/descending Box Overview sorting, including migrated legacy
  ordering preferences
- persistent Box ordering and matching contextual detail navigation
- creation-time, displayed-name, age and latest-feeding Animal Overview sorting
- deterministic missing-data ordering, persistent Animal sorting and matching
  contextual detail navigation
- direct Animal creation from empty and populated Box details with the Box
  preselected
- Box editing and optional dimensions
- optional multiline Box notes in create, edit and detail workflows
- safe empty-Box deletion from the bottom of Edit Box with confirmation,
  assigned-Animal protection and return to the Box Overview
- persistent Box pictures
- Box picture persistence across normal application restarts
- full-screen Box picture viewing with zooming and panning
- Box and Animal overview thumbnails
- FeedingEvent editing and deletion
- dedicated QR Feeding Mode from the Box Overview
- active-Animal resolution for a scanned Box
- single- and multi-Animal quick feeding entries
- atomic grouped FeedingEvent creation and duplicate-submission protection
- scanner restart after saving or choosing Scan a different Box
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
- localized Animal sex and birth-date-accuracy controls without raw enum labels
- System / English / Deutsch language selection
- immediate language changes and persistence across application restarts
- portable `.tmbackup` creation
- user-selectable backup destination through the Android system file picker
- backup file selection
- backup validation
- optional pre-restore safety backup, enabled by default
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
- Box notes backup and backward-compatible restore
- appearance-, language-, Animal-name- and overview-sort-setting backup and
  restore
- restore compatibility for backups without a language setting
- restore of Web-created backups
- camera-light controls in the Box and Feeding Mode scanners
- Camera and Gallery picture selection for new and edited Boxes and Animals
- compact Add Picture and Change Picture actions
- recoverable picture-source cancellation and denied camera permission
- free-form Camera and Gallery picture cropping for new and edited Boxes and
  Animals
- source-orientation normalization for portrait and landscape pictures
- bounded WebP persistence for new and replaced pictures
- legacy and WebP display in overview, detail and full-screen views
- mixed legacy and WebP backup export and restore
- optional per-Animal feeding reminder configuration and persistence
- dedicated Feeding Reminder settings from active Animal details
- latest-FeedingEvent reminder reference with baseline fallback only for
  Animals without feeding history
- non-modal due summary, due markers and scheduled or due detail status
- direct reminder navigation to the existing feeding workflow
- Latest Feeding card navigation to complete feeding history
- immediate reminder refresh after normal and Quick Feeding changes
- archived-Animal reminder suppression with retained configuration
- schema Version 4 to Version 5 migration and reminder backup compatibility
- schema Version 5 to Version 6 migration and Box-notes backup compatibility
- English and German reminder configuration and presentation

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
- TerraManager page title, install metadata, theme color, icons and favicon
- navigation
- Drift database operation
- persistence across normal browser reloads
- box and animal workflows
- natural ascending/descending Box Overview sorting, including legacy backup
  order mapping
- creation-time, displayed-name, age and latest-feeding Animal Overview sorting
- persistent overview ordering and matching contextual detail navigation
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
- scanner restart after saving or choosing Scan a different Box
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
- optional pre-restore safety backup, enabled by default
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
- Box notes backup and backward-compatible restore
- appearance-, language-, Animal-name- and overview-sort-setting backup and
  restore
- restore compatibility for backups without a language setting
- restore of Android-created backups
- both QR scanners with camera-light controls hidden when unsupported
- compact Add Picture and Change Picture actions
- Gallery picture selection for new and edited Boxes and Animals
- disabled Camera source when browser capture is unsupported
- free-form Gallery picture cropping for new and edited Boxes and Animals
- source-orientation normalization for portrait and landscape pictures
- bounded WebP persistence for new and replaced pictures
- legacy and WebP display in overview, detail and full-screen views
- mixed legacy and WebP backup export and restore
- optional per-Animal feeding reminder configuration and persistence
- dedicated Feeding Reminder settings from active Animal details
- latest-FeedingEvent reminder reference with baseline fallback only for
  Animals without feeding history
- non-modal due summary, due markers and scheduled or due detail status
- direct reminder navigation to the existing feeding workflow
- Latest Feeding card navigation to complete feeding history
- immediate reminder refresh after normal and Quick Feeding changes
- archived-Animal reminder suppression with retained configuration
- schema Version 4 to Version 5 migration and reminder backup compatibility
- schema Version 5 to Version 6 migration and Box-notes backup compatibility
- English and German reminder configuration and presentation

WebP optimization for new and replaced pictures uses browser Canvas encoding
and has been validated as part of the v0.12.0 Web regression.

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

`settings.json` preserves theme mode, accent color, application language,
preferred Animal name order and the Animal and Box Overview sort orders.
Backups without the newer settings fields remain compatible and restore their
documented defaults.

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
- backup creation
- backup file selection
- backup restore

iOS must not currently be described as a validated platform.
