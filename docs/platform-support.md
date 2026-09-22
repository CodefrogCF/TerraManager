# Platform Support

This document describes the current platform validation status of TerraManager.

## Status

| Platform | Status |
|---|---|
| Android | Validated |
| Web | Validated |
| iOS | Planned / not validated |

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

Official Android releases use the permanent application identity
`com.codefrog.terramanager` and the established production signing
configuration.

The authoritative signing, credential and certificate-verification procedure is
maintained in:

[Android release signing](android-release-signing.md)

User-facing installation and update guidance is maintained in:

[Installation and updates](installation-and-updates.md)

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
- adjacent horizontal swipe navigation across Box Overview, Animal Overview and
  Settings with synchronized navigation selection
- retained primary-page scroll positions, sorting and Settings state
- keyboard-compatible primary-page navigation and localized semantics
- Drift/SQLite persistence
- box creation and persistence
- natural ascending/descending Box Overview sorting, including migrated legacy
  ordering preferences
- alphabetical Box ordering with unnamed Boxes last in both directions
- calculated-volume Box ordering with incomplete dimensions last
- persistent Box ordering and matching contextual detail navigation
- creation-time, displayed-name, age and latest-feeding Animal Overview sorting
  in flat and category-grouped views
- an independent persistent category-view toggle with localized category and
  conditional subcategory headings, deterministic ordering and matching
  contextual detail navigation
- plural English and German taxonomy headings in grouped Animal views
- direct Animal creation from empty and populated Box details with the Box
  preselected
- immediate Animal Overview refresh after direct creation from Box details
- long-press quick actions for active Animal and Box overview entries
- independent Animal and Box duplication with copied picture media
- new permanent QR identifiers for Box duplicates
- Box editing and optional dimensions
- Box-owned multiline temperature-zone notes in create, edit and details
- deterministic legacy Animal-value transfer during Schema Version 11 migration
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
- optional bounded nighttime temperature with Schema Version 13 migration and
  portable backup compatibility
- feeding history
- notes
- persistent animal pictures
- animal picture persistence across application restarts
- full-screen Animal picture viewing with zooming and panning
- QR display
- QR PNG generation
- QR image storage in the Android media gallery
- shared active and archived Box selection for batch QR export
- selected Box QR export as individual PNG images and one ZIP archive
- paginated A4 PDF export with labeled 6–20 mm vector QR codes
- ZIP and PDF destination selection through the operating-system save dialog
- camera permission handling
- QR scanning
- invalid QR handling
- unknown QR handling
- animal lifecycle and archiving
- Animal History
- restoring archived animals
- permanent deletion of archived animals
- latest feeding display
- active due feeding reminders above the Animal picture and Latest Feeding
  directly below the Animal names
- accessible assigned-Box navigation from Animal details
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
- pre-restore safety backup
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
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
- latest-FeedingEvent reminder reference with baseline fallback only for
  Animals without feeding history
- non-modal due summary, due markers and scheduled or due detail status
- direct reminder navigation to the existing feeding workflow
- immediate reminder refresh after normal and Quick Feeding changes
- archived-Animal reminder suppression with retained configuration
- schema Version 4 to Version 5 migration and reminder backup compatibility
- English and German reminder configuration and presentation
- optional Big Picture Mode in Box, flat Animal and grouped Animal overviews
- local Big Picture Mode persistence and portable backup restore
- due-feeding indication on the primary Animals navigation item
- optional next-upcoming-feeding summary with unchanged due-reminder behavior
- timestamped Animal shedding history with create, edit and confirmed delete
  actions
- Schema Version 14 to Version 15 migration with deterministic legacy
  shedding-note conversion
- symmetric Animal History and Box History presentation
- archive sorting by date and displayed name in both directions
- persistent local archive sorting
- direct Restore and Duplicate actions from archive context menus
- removal of an existing birth date together with its accuracy
- per-Animal Weight and Shedding detail visibility
- Schema Version 15 to Version 16 migration with enabled visibility defaults
- portable backup round trips for shedding history, detail visibility, Big
  Picture Mode and the next-feeding summary
- local QR Rehouse Mode from Edit Animal
- active destination validation and atomic Animal reassignment
- rejection of unknown, archived and current destination Boxes
- Animal details that omit unset or Unknown sex information

QR images saved on Android are stored through the platform media/gallery system
so they remain accessible to the user outside the application.

QR ZIP archives and A4 PDF sheets are generated completely on-device and use
the operating-system save dialog. This does not require unrestricted storage,
media-library or network access.

QR Rehouse Mode reuses the existing scanner and camera permission. Box
resolution, destination validation and Animal reassignment remain local. The
workflow requires no additional storage, media-library, network, notification
or background permission.

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
- adjacent horizontal swipe navigation across Box Overview, Animal Overview and
  Settings with synchronized selection
- retained primary-page scroll positions, sorting and Settings state
- keyboard-compatible primary-page navigation and localized semantics
- Drift database operation
- persistence across normal browser reloads
- box and animal workflows
- immediate Animal Overview refresh after direct creation from Box details
- long-press and secondary-click quick actions for active Animal and Box
  overview entries
- independent Animal and Box duplication with copied picture media
- new permanent QR identifiers for Box duplicates
- natural ascending/descending Box Overview sorting, including legacy backup
  order mapping
- creation-time, displayed-name, age and latest-feeding Animal Overview sorting
  in flat and category-grouped views
- an independent persistent category-view toggle with localized category and
  conditional subcategory headings and matching contextual detail navigation
- Box editing and optional dimensions
- Box-owned multiline temperature-zone notes in create, edit and details
- deterministic legacy Animal-value transfer during Schema Version 11 migration
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
- shared active and archived Box selection for batch QR export
- selected Box QR export as individual PNG images and one ZIP archive
- paginated A4 PDF export with labeled 6–20 mm vector QR codes
- ZIP and PDF destination selection through the browser/system save dialog
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
- pre-restore safety backup
- full backup restore
- Box and Animal picture backup and restore
- Box dimension backup and restore
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
- latest-FeedingEvent reminder reference with baseline fallback only for
  Animals without feeding history
- non-modal due summary, due markers and scheduled or due detail status
- direct reminder navigation to the existing feeding workflow
- immediate reminder refresh after normal and Quick Feeding changes
- archived-Animal reminder suppression with retained configuration
- schema Version 4 to Version 5 migration and reminder backup compatibility
- English and German reminder configuration and presentation
- optional Big Picture Mode in Box, flat Animal and grouped Animal overviews
- local Big Picture Mode persistence and portable backup restore
- due-feeding indication on the primary Animals navigation item
- optional next-upcoming-feeding summary with unchanged due-reminder behavior
- timestamped Animal shedding history with create, edit and confirmed delete
  actions
- Schema Version 14 to Version 15 migration with deterministic legacy
  shedding-note conversion
- symmetric Animal History and Box History presentation
- archive sorting by date and displayed name in both directions
- persistent local archive sorting
- direct Restore and Duplicate actions from archive context menus
- removal of an existing birth date together with its accuracy
- per-Animal Weight and Shedding detail visibility
- Schema Version 15 to Version 16 migration with enabled visibility defaults
- portable backup round trips for shedding history, detail visibility, Big
  Picture Mode and the next-feeding summary
- local QR Rehouse Mode from Edit Animal
- active destination validation and atomic Animal reassignment
- rejection of unknown, archived and current destination Boxes
- Animal details that omit unset or Unknown sex information

WebP optimization for new and replaced pictures uses browser Canvas encoding
and has been validated as part of the v0.12.0 Web regression.

QR Rehouse Mode uses the same browser camera access as the existing Box and
Feeding Mode scanners. It introduces no additional browser permission and sends
no QR identifier or Animal data to a remote service.

## Web Database

Web persistence uses Drift with SQLite WASM.

Repository-managed files:

```text
web/sqlite3.wasm
web/drift_worker.dart
```

The Drift worker is compiled before a Web build using:

```text
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
```

The generated worker JavaScript, dependency list and source map are ignored by
Git and are included in the generated Web build output by this step.

The `sqlite3.wasm` version must remain compatible with the `sqlite3` Dart
package resolved by the project.

Persistent Box and Animal pictures are stored as `MediaAssets` through the same
Drift database abstraction used by the rest of the application.

Schema Version 12 stores ordered Animal and Box picture histories through
owner-specific association tables. Gallery viewing, primary selection and
individual deletion are local database operations. Adding an image reuses the
existing explicit Camera or Gallery selection flow and introduces no additional
storage, media, network or background permission.

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

Current Version 2 backups also preserve timestamped shedding history,
per-Animal Weight and Shedding detail visibility, category-view presentation,
Big Picture Mode and the optional next-feeding summary.

Missing visibility fields from older backups default to enabled. Missing Big
Picture Mode and next-feeding-summary settings default to disabled. Animal and
Box archive sort preferences remain local to the current installation and are
not replaced during restore.

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

QR images, QR ZIP archives, A4 QR PDF sheets and TerraManager backup files are
saved through browser and operating-system facilities.

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
- QR ZIP and A4 PDF export
- backup creation
- backup file selection
- backup restore

iOS must not currently be described as a validated platform.
