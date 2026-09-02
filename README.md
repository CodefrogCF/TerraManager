# TerraManager

TerraManager is a cross-platform, local-first application for managing terrarium boxes, animals and feeding records.

The application is developed with Flutter and currently supports Android and Web.

iOS support is planned, but has not yet been validated because no macOS build environment or physical iOS test device is currently available.

## Project Status

Current completed release milestone:

**v0.5.0 – Usability & Settings**

Completed milestones:

- v0.1.0 – Foundation
- v0.2.0 – User Interface
- v0.3.0 – QR Code
- v0.4.0 – Android and Web Platform Support
- v0.5.0 – Usability & Settings

Android and Web are currently validated platforms.

The next planned milestones are:

### v0.6.0 – Backup & Restore

Portable backup and restore of TerraManager domain data, settings and media.

### v0.7.0 – Editing & Overview

Box editing, enclosure dimensions, Box pictures, human-readable Box labels,
editable feeding events, overview thumbnails and improved list-state handling.

### v0.8.0 – Navigation & History

Contextual swipe navigation between detail records and historical tracking of
Animal-to-Box assignments.

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
- unknown and invalid QR handling
- assigned animal list on box detail
- navigation from box to assigned animal
- safe deletion of empty boxes
- deletion protection for boxes containing active animals

### Animals

- active animal overview
- animal creation
- animal detail screen
- animal editing
- box assignment
- common and Latin names
- sex
- birth date
- birth date accuracy
- preferred temperature range
- preferred humidity range
- optional picture
- notes
- active and archived lifecycle states
- archive reasons, dates and optional archive notes
- dedicated Animal History view
- restore archived animals
- permanent deletion of archived animals
- preserved feeding history while archived

### Feeding

- feeding event history
- feeding timestamps
- optional feeding notes
- latest feeding lookup
- latest feeding displayed directly on animal details
- automatic refresh after returning from feeding history

### Settings

- System theme mode
- Light theme mode
- Dark theme mode
- predefined accent colors
- immediate appearance changes
- persistent appearance settings

### Platform Support

Validated:

- Android
- Web

Not yet validated:

- iOS

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

## Data Model

The current database structure is:

```text
Box
 │
 └──── 1:n ──── Active Animal
                   │
                   └──── 1:n ──── FeedingEvent

Archived Animal
 │
 ├── no active box assignment
 └──── 1:n ──── FeedingEvent
```

### Box

```text
Box
├── id
├── qrId
├── createdAt
└── updatedAt
```

qrId is unique and permanently identifies the box.

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
├── notes
├── archiveReason
├── archivedAt
├── archiveNotes
├── createdAt
└── updatedAt
```

Active animals are assigned to a box.

Archived animals have no active box assignment. Their animal data and feeding
history remain stored until the animal is explicitly deleted permanently.

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
- shared_preferences

### Database

- Drift
- SQLite
- SQLite WASM on Web

### QR and Media

- qr_flutter
- mobile_scanner
- uuid
- image_picker
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
│   └── qr/
│       ├── qr_export_service.dart
│       ├── qr_file_name.dart
│       ├── qr_id_generator.dart
│       ├── qr_print_service.dart
│       ├── qr_storage_service.dart
│       └── qr_validator.dart
│
└── features/
    ├── navigation/
    ├── boxes/
    ├── animals/
    ├── feedings/
    └── settings/
        ├── app_accent.dart
        ├── app_settings_controller.dart
        └── presentation/
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

Platform-specific functionality such as camera access, gallery storage and printing must additionally be validated on the target platform.

## Code Generation

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
docs/database/data-model.md
docs/architecture-decisions.md
docs/functional-requirements-MVP.md
docs/functional-requirements-non-MVP.md
CHANGELOG.md

## Known Limitations

TerraManager currently follows a local-first architecture.

There is no cloud synchronization or multi-device synchronization.

Data is therefore tied to the local device or browser profile unless manually transferred or backed up.

iOS has not yet been validated.

Detailed platform-specific limitations are documented in:

```text
docs/platform-support.md
```