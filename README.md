# TerraManager

TerraManager is a cross-platform, local-first application for managing terrarium boxes, animals and feeding records.

The application is developed with Flutter and currently supports Android and Web.

iOS support is planned, but has not yet been validated because no macOS build environment or physical iOS test device is currently available.

## Project Status

Current completed release milestone:

**v0.13.0 – Feeding Reminders**

Active development milestone:

**v0.14.0 – Pre-1.0 UX Polish**

Current development build:

**v0.13.1+28**

Implemented milestones in the current source state:

- v0.1.0 – Foundation
- v0.2.0 – User Interface
- v0.3.0 – QR Code
- v0.4.0 – Android and Web Platform Support
- v0.5.0 – Usability & Settings
- v0.6.0 – Backup & Restore
- v0.7.0 – Editing & Overview
- v0.7.1 – Maintenance
- v0.8.0 – Contextual Navigation
- v0.9.0 – Feeding Workflow & Media
- v0.10.0 – Localization
- v0.11.0 – Personalization & Capture
- v0.12.0 – Media Optimization
- v0.13.0 – Feeding Reminders

Android and Web are currently validated platforms.

The v0.13.0 implementation, automated regression, Android/Web validation and
release builds are complete. The validation record and release notes are
available in `docs/release-v0.13.0.md`.

Development of v0.14.0 is in progress. Its first update replaces raw enum text
in Animal sex and birth-date-accuracy controls with consistent English and
German labels and removes the duplicate Unknown sex option.

The completed v0.12.0 validation record remains available in
`docs/release-v0.12.0.md`.

Portable backup and restore has been validated:

- Android → Android
- Web → Web
- Android → Web
- Web → Android

TerraManager provides complete English and German interfaces. The language can
follow the operating system or be selected explicitly as English or Deutsch in
Settings. Manual selections are applied immediately and persist across normal
application restarts.

## Implemented Features

### Boxes

- box overview
- box creation
- automatic unique QR ID generation
- box detail screen
- permanent QR identifiers
- QR code display
- QR code export as PNG
- local QR image storage
- QR code printing
- QR code scanning
- optional camera-light controls in the Box and Feeding Mode scanners
- unknown and invalid QR handling
- assigned animal list on box detail
- navigation from box to assigned animal
- optional width, height and depth
- persistent Box pictures
- Add/Change Picture action with Camera and Gallery source selection for Box
  pictures
- free-form cropping before a selected or captured Box picture is applied
- WebP optimization with a maximum 1920-pixel longest edge for new and replaced
  Box pictures
- full-screen Box picture viewing with zooming and panning
- Box editing while keeping the QR identifier immutable
- human-readable local labels (`Box N`)
- Box thumbnails in the overview
- preserved Box overview scroll position after detail navigation
- contextual swipe navigation through the Box Overview ordering
- safe deletion of empty boxes
- deletion protection for boxes containing active animals

### Animals

- active animal overview
- animal creation
- animal detail screen
- animal editing
- box assignment
- common and Latin names
- localized Male, Female and Unknown sex values without duplicate options
- birth date
- birth date accuracy
- localized Exact, Month known and Year known birth-date-accuracy values
- preferred temperature range
- preferred humidity range
- optional picture
- Add/Change Picture action with Camera and Gallery source selection for Animal
  pictures
- free-form cropping before a selected or captured Animal picture is applied
- WebP optimization with a maximum 1920-pixel longest edge for new and replaced
  Animal pictures
- full-screen Animal picture viewing with zooming and panning
- notes
- active and archived lifecycle states
- archive reasons, dates and optional archive notes
- dedicated Animal History view
- restore archived animals
- permanent deletion of archived animals
- preserved feeding history while archived
- Animal thumbnails in the overview
- preserved Animal overview scroll position after detail navigation
- contextual swipe navigation through Active Animals, Animal History and
  Box-specific Animal collections
- optional per-Animal feeding reminder configuration
- positive whole-day reminder intervals
- reminder baselines set when reminders are enabled
- reminder configuration retained while an Animal is archived
- due timestamps calculated from the later of reminder baseline and latest
  feeding
- disabled and archived Animals excluded from active reminder results
- non-modal overview summary listing currently due Animals
- visible due markers in the Animal Overview
- most-overdue-first reminder ordering
- due or scheduled status with calculated date on Animal details
- direct navigation from reminder entries to the Animal and feeding workflow
- immediate reminder refresh after normal and Quick Feeding changes

### Feeding

- feeding event history
- feeding timestamps
- optional feeding notes
- FeedingEvent editing
- FeedingEvent deletion with confirmation
- latest feeding lookup
- latest feeding displayed directly on animal details
- automatic refresh after feeding edits and deletions
- efficient bulk lookup of reminder state without one feeding query per Animal
- deterministic due-state calculation at exact timestamp boundaries
- automatic reminder rescheduling from current history after feeding creation,
  editing or deletion
- dedicated QR Feeding Mode from the Box Overview
- scanned Box resolution to its currently assigned active Animals
- empty state for Boxes without active Animals
- one- and multi-Animal quick feeding selection
- current date and time pre-filled for quick feeding entries
- optional shared quick-feeding notes
- atomic creation of one FeedingEvent per selected Animal
- duplicate-submission protection
- immediate return to scanning after saving or cancelling

### Settings

- System theme mode
- Light theme mode
- Dark theme mode
- predefined accent colors
- immediate appearance changes
- persistent appearance settings
- selectable Common name first or Latin name first Animal presentation
- immediate and persistent Animal name-order changes
- System language mode
- explicit English and German language selection
- immediate language changes without an application restart
- persistent language selection
- portable `.tmbackup` backup creation
- backup file selection and validation
- pre-restore backup information
- destructive restore confirmation
- automatic safety backup before restore
- full local data restore
- appearance, language and Animal name-order setting backup and restore

### Backup & Restore

- versioned portable `.tmbackup` archive format
- Backup Format Version 2 for current exports
- backward-compatible restore of Backup Format Version 1
- backup format version independent from database schema version
- Box export and restore, including dimensions and pictures
- Animal export and restore
- FeedingEvent export and restore
- Box and Animal picture export and restore
- mixed legacy PNG/JPEG and normalized WebP picture backups
- centralized archive-extension and restored MIME-type mapping
- appearance, language and Animal name-order setting export and restore
- backward-compatible restore of backups without language or Animal
  name-order settings
- per-Animal feeding reminder configuration export and restore
- backward-compatible restore of backups without reminder fields, with
  reminders disabled
- permanent Box QR identifiers preserved
- backup validation before destructive operations
- relationship and lifecycle validation
- archive path safety validation
- pre-restore safety backup
- explicit destructive restore confirmation
- transactional database replacement
- Android and Web portability
- Android → Web restore validation
- Web → Android restore validation
- generated QR images excluded from backups

A real-world backup containing 44 Boxes, 45 Animals, 20 FeedingEvents and 67
pictures decreased from approximately 140 MB to 22.7 MB after picture
normalization. This is a reduction of about 83.8%, or roughly 6.2 times smaller.

### Platform Support

Validated:

- Android
- Web

Not yet validated:

- iOS

### Localization

TerraManager supports:

- English (`en`)
- German (`de`)

The default `System` setting follows the operating-system language. If the
system language is not supported, TerraManager falls back to English.

Settings also provides explicit `English` and `Deutsch` selections. A manual
selection is applied immediately, stored through `shared_preferences`, and
restored the next time the application starts.

The selected language is included in newly created `.tmbackup` files. Restoring
a backup also restores its language setting. Backups created before language
selection was introduced remain compatible and use `System` when the language
field is absent.

Settings also controls whether an Animal's common name or Latin name is shown
first. The preference is applied immediately to Animal overviews, history,
details, Box assignments and Quick Feeding Mode. It is stored locally and
included in newly created `.tmbackup` files. Older backups default to common
name first.

### Contextual Detail Navigation

Animal and Box detail pages can receive a `DetailNavigationContext` containing:

- the ordered record IDs from the source collection
- the currently displayed record ID
- the source of the navigation
- the source Box ID when navigating through Animals assigned to one Box

Supported sources are:

- Active Animals
- Animal History
- Animals assigned to one Box
- Box Overview

Horizontal swipes move only within this source-specific ordering. The first and
last records form navigation boundaries, so swiping cannot leave the original
collection.

The detail route remains open while the displayed record changes. Editing and
other actions therefore continue to target the currently displayed record, and
Back returns to the overview from which the route was opened.

Detail pages can still be opened without a navigation context. In that case,
they behave as normal non-swipe detail pages.

### Picture Selection and Cropping

New and edited Box and Animal forms share one picture-selection flow. After the
user selects a Gallery picture or captures a new photo, a dedicated cropping
screen opens before the form preview changes.

The crop frame can be moved and resized freely. The underlying picture can also
be panned and zoomed. Applying the crop returns the resulting image bytes to the
form, while cancelling keeps the previous picture and form state unchanged.

Source orientation is normalized before cropping. Cropped pictures continue to
use the existing persistent `MediaAssets` and portable backup flow.

After confirmation, a crop is resized without upscaling so its longest edge is
at most 1920 pixels. It is then encoded as WebP with quality 82. The stored
filename uses `.webp` and the MIME type is `image/webp`.

The form shows a processing indicator while the confirmed crop is normalized.
During that time, further picture actions and saving are disabled. The handlers
also reject repeated calls, so rapid taps cannot start parallel processing or
create duplicate media records.

Existing stored JPEG, PNG and other supported pictures are deliberately not
rewritten automatically. They remain readable and portable; selecting a
replacement moves that record to the optimized WebP flow. When an existing
picture is replaced, the new MediaAsset, the Box or Animal update and removal
of the superseded MediaAsset are committed in one transaction. A processing or
save failure therefore leaves the previously stored picture intact.

### Full-Screen Pictures

Box and Animal pictures shown on their detail pages can be opened in a dedicated
full-screen viewer.

The viewer:

- displays the complete picture against a dark background
- supports zoom levels from 1x to 5x
- supports panning while zoomed
- closes through its close button or normal platform Back navigation

Because the viewer uses its own route, gestures inside the picture do not change
the contextual Animal or Box detail record underneath it.

### QR Feeding Mode

The Box Overview provides a dedicated Feeding Mode that is separate from normal
Box-detail scanning.

After a valid Box QR code is scanned, TerraManager displays only the active
Animals currently assigned to that Box. All displayed Animals are selected by
default, allowing a single-Animal Box to be recorded with one save action after
scanning. The selection can be changed for individual or grouped feedings.

The feeding timestamp defaults to the current date and time and can be adjusted.
One optional note is applied to every FeedingEvent created by the operation.

Saving creates one normal FeedingEvent for every selected Animal inside a single
database transaction. If one insert fails, none of the grouped feeding remains.
While the transaction is running, repeated submissions are ignored.

After saving or cancelling, the scanner resumes so the next Box can be scanned
immediately. Newly created entries are available through the existing Animal
feeding history and latest-feeding display.

Both the normal Box scanner and the Feeding Mode scanner provide a camera-light
control when the active camera reports torch support. The control is omitted on
unsupported cameras and platforms.

## Concept

The core concept is based on physical terrarium boxes identified by permanent QR codes.

Each box receives a unique QR identifier when it is created.

The QR code does not contain animal or terrarium data. It contains only the permanent box identifier.

Example:

```text
Physical Box
    │
    │ QR Code
    ▼
TM:BOX:<UUID>
    │
    ▼
Database
    │
    └── Box
          │
          ├── Animal
          ├── Animal
          └── ...
```

The QR identifier remains stable even when animals or other application data change.

Scanning the QR code resolves the identifier through the local database and opens the corresponding box.

## Local-First Architecture

TerraManager is designed as a local-first application.

Core functionality does not require an internet connection.

Application data is stored locally on the current device or browser profile.

```text
UI
 │
 ▼
Repository
 │
 ▼
Drift
 │
 ▼
Local Database
```

There is currently no cloud synchronization.

This means that data stored on one device is not automatically available on another device.

Portable `.tmbackup` files can be used to manually transfer TerraManager data
between supported devices and platforms.

Backup transfer is not automatic synchronization. A restore replaces the current
local TerraManager state with the selected backup.

## Data Model

The current database structure is:

```text
Box
 │
 ├──── 0:1 ──── MediaAsset
 │
 └──── 1:n ──── Active Animal
                   │
                   ├──── 1:n ──── FeedingEvent
                   │
                   └──── 0:1 ──── MediaAsset

Archived Animal
 │
 ├── no active box assignment
 ├──── 1:n ──── FeedingEvent
 └──── 0:1 ──── MediaAsset
```

### Box

```text
Box
├── id
├── qrId
├── widthCm
├── heightCm
├── depthCm
├── pictureMediaId
├── createdAt
└── updatedAt
```

`qrId` is unique and permanently identifies the box. Width, height and depth are optional.
`pictureMediaId` optionally references persistent image data stored in `MediaAssets`.

The QR format is:

```text
TM:BOX:<UUID-v4>
```

### Animal

```text
Animal
├── id
├── boxId
├── status
├── commonName
├── latinName
├── sex
├── birthDate
├── birthDateAccuracy
├── tempMin
├── tempMax
├── humidityMin
├── humidityMax
├── picturePath
├── pictureMediaId
├── notes
├── archiveReason
├── archivedAt
├── archiveNotes
├── createdAt
└── updatedAt
```

Active animals are assigned to a box.

Archived animals have no active box assignment. Their animal data, picture and
feeding history remain stored until the animal is explicitly deleted permanently.

`pictureMediaId` references persistent image data stored in `MediaAssets`.

`picturePath` is retained only for migration and compatibility with pictures
created by earlier TerraManager versions. New pictures are stored through
`MediaAssets`.

### MediaAsset

```text
MediaAsset
├── id
├── fileName
├── mimeType
├── data
├── createdAt
└── updatedAt
```

Box and Animal pictures are stored persistently as binary data in the local Drift
database.

This avoids relying on temporary or platform-specific paths returned by image
selection APIs.

The same persistence model is used on Android and Web and allows Box and Animal
pictures to be included in portable TerraManager backups.

### FeedingEvent

```text
FeedingEvent
├── id
├── animalId
├── fedAt
└── notes
```

An animal can have multiple feeding events.

The latest feeding is derived from the feeding history and is not stored separately.

## QR Architecture

QR functionality is separated into reusable components.

```text
Box.qrId
    │
    ├── BoxQrCode
    │
    ├── QrExporter
    │       │
    │       ▼
    │    PNG bytes
    │       │
    │       ├── QrStorage
    │       └── QrPrinter
    │
    └── QR Scanner
            │
            ▼
       QR validation
            │
            ▼
       BoxRepository
```

The QR image itself is not stored in the database.

It is generated from the permanent qrId when needed.

## Technology Stack

### Application

- Flutter
- Dart
- Material 3
- flutter_localizations
- intl
- shared_preferences
- archive
- file_picker
- package_info_plus

### Database

- Drift
- SQLite
- SQLite WASM on Web

### QR and Media

- qr_flutter
- mobile_scanner
- uuid
- image_picker
- crop_your_image
- flutter_image_compress
- image
- file_saver
- saver_gallery
- printing
- pdf

### Development

- Windows 11
- Visual Studio Code
- Android Studio
- Git
- GitHub

## Architecture

The project separates presentation, application-facing repositories and persistence.

```text
TerraManagerApp
      │
      ▼
   AppShell
      │
      ├── Boxes
      ├── Animals
      └── Settings
             │
             ▼
        Repositories
             │
             ▼
           Drift
             │
             ▼
      Local Persistence
```

The UI should not contain direct database implementation logic.

Repositories provide the application-facing API for data access and modification.

Platform-specific functionality is isolated behind services where practical.

## Project Structure

The project is organized approximately as follows:

```text
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── theme/
│   │   └── app_theme.dart
│   │
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── app_database.g.dart
│   │   ├── converters/
│   │   ├── enums/
│   │   ├── tables/
│   │   └── repositories/
│   │
│   ├── media/
│   │   ├── image_media_info.dart
│   │   └── legacy_animal_picture_migration_service.dart
│   │
│   └── qr/
│       ├── qr_export_service.dart
│       ├── qr_file_name.dart
│       ├── qr_id_generator.dart
│       ├── qr_print_service.dart
│       ├── qr_storage_service.dart
│       └── qr_validator.dart
│
├── features/
│   ├── navigation/
│   ├── boxes/
│   ├── animals/
│   │   └── presentation/
│   │       └── animal_display_names.dart
│   ├── feedings/
│   ├── media/
│   │   └── presentation/
│   │       ├── picture_selection_flow.dart
│   │       ├── pages/
│   │       │   ├── full_screen_image_page.dart
│   │       │   └── picture_crop_page.dart
│   │       └── widgets/
│   │           └── picture_selection_controls.dart
│   ├── settings/
│   │   ├── app_accent.dart
│   │   ├── app_language.dart
│   │   ├── animal_name_order.dart
│   │   ├── app_settings_controller.dart
│   │   └── presentation/
│   │
│   └── backup/
│       ├── application/
│       ├── domain/
│       └── infrastructure/
│
└── l10n/
    ├── app_en.arb
    ├── app_de.arb
    ├── app_localizations_context.dart
    └── app_localizations_labels.dart
```

Generated Drift files such as:

```text
lib/core/database/app_database.g.dart
```

must not be edited manually.

## Development Workflow

Development is tracked with:

- Git
- GitHub Issues
- GitHub Milestones
- Architecture Decision Records
- automated tests

Typical workflow:

```text
Issue
  ↓
Implementation
  ↓
Tests
  ↓
flutter analyze
  ↓
flutter test
  ↓
Manual validation where required
  ↓
Commit
  ↓
Push
  ↓
Close Issue
```

## Testing

Run static analysis:

```text
flutter analyze
```

Run the complete automated test suite:

```text
flutter test
```

Platform-specific functionality such as camera access, gallery storage and
printing must additionally be validated on the target platform. Language
selection should be checked using supported and unsupported system locales.

## Code Generation

After changing localization resources in `lib/l10n/`:

```text
flutter gen-l10n
```

Generated localization files in `lib/l10n/generated/` must not be edited
manually.

After changing Drift tables, converters or related database definitions:

```text
dart run build_runner build
```

When changing the database schema, Drift migration files must also be updated:

```text
dart run drift_dev make-migrations
```

Do not manually edit generated Drift files.

## Documentation

Additional documentation:

docs/roadmap.md
docs/development.md
docs/platform-support.md
docs/data-model.md
docs/backup-format.md
docs/architecture-decisions.md
docs/functional-requirements-MVP.md
docs/functional-requirements-non-MVP.md
CHANGELOG.md

## Known Limitations

TerraManager currently follows a local-first architecture.

There is no cloud synchronization or automatic multi-device synchronization.

Data is stored locally on the current device or browser profile. Portable
`.tmbackup` files can be used for manual backup, recovery and transfer between
validated platforms.

Web data can still be lost when browser site data is cleared if no external
backup exists.

iOS has not yet been validated.

Detailed platform-specific limitations are documented in:

```text
docs/platform-support.md
```
