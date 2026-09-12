# TerraManager

TerraManager is a cross-platform, local-first application for managing terrarium boxes, animals and feeding records.

The application is developed with Flutter and currently supports Android and Web.

iOS support is planned, but has not yet been validated because no macOS build environment or physical iOS test device is currently available.

Public project information:

- [Installation and updates](docs/installation-and-updates.md)
- [Privacy](PRIVACY.md)
- [Support](SUPPORT.md)
- [Security](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
- [GPL-3.0-or-later license](LICENSE)

## Project Status

Current completed release milestone:

**v1.0.0 – MVP Release**

Current application version and build:

**v1.0.8+49**

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
- v0.14.0 – Pre-1.0 UX Polish
- v0.14.1 – Post-release Fixes
- v1.0.0 – MVP Release

Android and Web are currently validated platforms.

The v0.14.1 patch implementation, automated regression, supported builds and
manual validation are complete. The release corrects reminder calculation for
Animals with existing feeding history and simplifies Box Overview sorting to
ascending or descending Box number while preserving legacy settings and backup
compatibility. The validation record and release notes are available in
`docs/release-v0.14.1.md`.

TerraManager v1.0.0 is released as the stable MVP baseline. Development now
continues with the v1.1.0 Detail & Workflow Polish milestone.

Development build `0.14.2+34` establishes `com.codefrog.terramanager` as the
permanent application identity, replaces the remaining Flutter placeholder
metadata and uses the TerraManager icon throughout the Android and Web
projects. This work is tracked by Issue #89.

Development build `0.14.3+35` replaces the temporary Android debug signing of
release artifacts with an explicit production-signing configuration. Local
credentials are loaded from the ignored `android/key.properties` file or from
`TERRAMANAGER_*` environment variables; Release builds fail clearly when the
configuration is incomplete. Key creation, secure backup, build verification
and the one-time transition from earlier debug-signed installations are
documented in `docs/android-release-signing.md`. This work is tracked by Issue
#90.

The production key has been created and backed up, both signed Android
artifacts have been built and verified, and the one-time physical-device
transition has been completed successfully. Future directly distributed
Android builds must retain this production certificate.

Development build `0.14.4+36` adds the GPL-3.0-or-later project licence and
the public privacy, permission, installation, update, support, security and
contribution documentation required by Issue #91. It also corrects completion
states in historical v0.11.0 and v0.12.0 release records.

Development build `0.14.5+37` replaces the ambiguous Continue-style Quick
Feeding action with an explicit **Scan a different Box** cancellation action.
It discards the unsaved Box-specific feeding form, returns to Feeding Mode and
restarts the scanner without creating a FeedingEvent.

Development build `0.14.6+38` adds reproducible GitHub Actions quality gates
for dependency-lock verification, localization generation, formatting,
analysis, tests, Android Debug and Web Release builds. The supported Flutter,
Dart, Java, Gradle and dependency baseline, including the current upstream
Kotlin-plugin warning, is documented in `docs/toolchain-baseline.md`.

Release `1.0.0+39` completed the final Android, Web, backup, localization,
signing and artifact regression defined in `docs/release-v1.0.0.md`.

Development build `1.0.2+43` begins the v1.1.0 milestone. Issue #94 displays
the current Animal picture as a thumbnail in the assigned-Animal list on Box
details and retains the existing fallback icon when no usable picture exists.

Development build `1.0.3+44` moves the Box QR code, permanent identifier and
PNG export action into one section at the bottom of Box details. Issue #95
removes the former print action and its dedicated dependencies while keeping
existing QR identifiers and scanner compatibility unchanged.

Development build `1.0.4+45` adds optional multiline notes to Boxes. Issue #96
persists them through Database Schema Version 6, displays non-empty notes on
Box details and preserves them in current backups while older backups restore
with empty Box notes.

Development build `1.0.5+46` moves the Box deletion action out of Box details
and into a destructive section at the bottom of Edit Box. Issue #97 preserves
confirmation and assigned-Animal protection while returning safely to the Box
Overview after deletion, including from a contextually swiped Box. Automated
and manual validation are complete.

Development build `1.0.6+47` implements Issue #98. The Latest Feeding card on
Animal details now opens the complete feeding history, while a dedicated
top-level action opens Feeding Reminder settings for active Animals. Reminder
controls no longer occupy Edit Animal, and ordinary Animal changes preserve
the existing reminder configuration.

Development build `1.0.7+48` implements Issue #99. Settings now uses one
compact, localized accent-color dropdown and provides an About TerraManager
dialog under Legal & Privacy with the installed application version, build
number and developer information.

Development build `1.0.8+49` implements Issue #100. The destructive Restore
confirmation now offers a safety-backup checkbox that is enabled by default
but can be disabled for an individual restore, including when the current
database is empty.

### Android transition to the permanent application ID

Releases through v0.14.1 used the temporary Android identifier
`com.example.flutter_application_1`. Android treats
`com.codefrog.terramanager` as a separate application, so the new build cannot
update an existing pre-v1.0 installation in place.

Before moving to a build with the permanent identifier:

1. Create a current `.tmbackup` file in v0.14.1.
2. Keep the old installation until the backup file is stored safely.
3. Install the new TerraManager application.
4. Restore the backup through Settings.
5. Verify Animals, Boxes, FeedingEvents, settings and pictures before removing
   the old installation.

No database or backup-format conversion is required. Portable Backup Format
Version 2 remains compatible with the new application identity.

The completed v0.14.0 validation record remains available in
`docs/release-v0.14.0.md`.

The completed v0.13.0 validation record remains available in
`docs/release-v0.13.0.md`.

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
- QR code scanning
- optional camera-light controls in the Box and Feeding Mode scanners
- unknown and invalid QR handling
- assigned animal list on box detail
- current Animal picture thumbnails in Box-detail assignment lists
- Box information and assigned Animals before the consolidated bottom QR
  section
- permanent QR identifier and PNG export action grouped with the QR code
- navigation from box to assigned animal
- Add Animal action below empty and populated Box assignment sections
- direct New Animal navigation with the originating Box preselected
- optional width, height and depth
- optional multiline Box notes
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
- localized Box Overview sorting by ascending or descending natural Box number
- persistent Box Overview ordering across application restarts
- preserved Box overview scroll position after detail navigation
- contextual swipe navigation through the Box Overview ordering
- safe deletion of empty boxes from the bottom of Edit Box
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
- localized Animal Overview sorting by creation time, displayed primary name,
  age or latest FeedingEvent
- deterministic placement of Animals without birth or feeding data
- persistent Animal Overview ordering across application restarts
- preserved Animal overview scroll position after detail navigation
- contextual swipe navigation through Active Animals, Animal History and
  Box-specific Animal collections
- optional per-Animal feeding reminder configuration
- dedicated Feeding Reminder settings from active Animal details
- positive whole-day reminder intervals
- reminder baselines set when reminders are enabled
- reminder configuration retained while an Animal is archived
- due timestamps calculated from the latest feeding when one exists, otherwise
  from the reminder baseline
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
- direct feeding-history navigation from the Latest Feeding card
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
- immediate return to scanning after saving or choosing Scan a different Box

### Settings

- System theme mode
- Light theme mode
- Dark theme mode
- predefined accent colors in a compact dropdown
- immediate appearance changes
- persistent appearance settings
- selectable Common name first or Latin name first Animal presentation
- immediate and persistent Animal name-order changes
- immediate and persistent Animal Overview sort-order changes
- immediate and persistent Box Overview sort-order changes
- System language mode
- explicit English and German language selection
- immediate language changes without an application restart
- persistent language selection
- installed version, build number and developer information under Legal &
  Privacy
- portable `.tmbackup` backup creation
- backup file selection and validation
- pre-restore backup information
- destructive restore confirmation
- optional safety backup before restore, enabled by default
- full local data restore
- appearance, language, Animal name-order, Animal sort-order and Box sort-order
  setting backup and restore

### Backup & Restore

- versioned portable `.tmbackup` archive format
- Backup Format Version 2 for current exports
- backward-compatible restore of Backup Format Version 1
- backup format version independent from database schema version
- Box export and restore, including dimensions, notes and pictures
- Animal export and restore
- FeedingEvent export and restore
- Box and Animal picture export and restore
- mixed legacy PNG/JPEG and normalized WebP picture backups
- centralized archive-extension and restored MIME-type mapping
- appearance, language, Animal name-order, Animal sort-order and Box sort-order
  setting export and restore
- backward-compatible restore of backups without language, Animal name-order,
  Animal sort-order or Box sort-order settings
- per-Animal feeding reminder configuration export and restore
- backward-compatible restore of backups without reminder fields, with
  reminders disabled
- permanent Box QR identifiers preserved
- backup validation before destructive operations
- relationship and lifecycle validation
- archive path safety validation
- per-restore safety-backup choice, enabled by default
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

The Box Overview sort menu offers ascending or descending Box number. Box
numbers are compared numerically, so `Box 10` correctly follows `Box 2` in
ascending order. The selected ordering is applied to both the list and
contextual Box detail navigation, stored locally and included in new backups.
Older missing or oldest-created-first values map to ascending Box number;
newest-created-first values map to descending Box number.

The Animal Overview sort menu offers oldest/newest creation time, displayed
name A–Z/Z–A, oldest/youngest age and newest/oldest latest feeding. Name sorting
uses the currently preferred primary Animal name. Missing birth dates remain
last in both age directions. Never-fed Animals appear first when sorting by the
oldest feeding and last when sorting by the newest feeding. The selected order
also controls contextual Animal detail navigation, persists locally and is
included in new backups. Older backups default to oldest-created Animal first.

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

After saving or choosing **Scan a different Box**, the scanner resumes so the
next Box can be scanned immediately. The second action cancels the unsaved
Box-specific feeding form without creating a FeedingEvent. Newly created
entries are available through the existing Animal feeding history and latest-
feeding display.

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
├── notes
├── pictureMediaId
├── createdAt
└── updatedAt
```

`qrId` is unique and permanently identifies the box. Width, height, depth and
notes are optional.
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
    │       └── QrStorage
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
│   │   ├── animal_sort_order.dart
│   │   ├── box_sort_order.dart
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

## Installation and Updates

Android users install the trusted Release APK. The Android App Bundle is meant
for store distribution and is not directly installed on a device. Web
operators deploy the complete static build to one stable HTTPS origin because
browser data is tied to its origin and profile.

Create a current `.tmbackup` before every application update or Web deployment.
The complete installation, artifact-verification, production-certificate and
pre-v1.0 transition guidance is in
[docs/installation-and-updates.md](docs/installation-and-updates.md).

## Privacy and Permissions

TerraManager stores application data locally and has no TerraManager-operated
account, backend, cloud sync, advertising, analytics, telemetry or crash-
reporting service. Camera, gallery and file access is requested only for the
corresponding user-initiated feature. Feeding reminders remain inside the
application and do not request system notification permission.

Portable `.tmbackup` archives include records, settings and pictures and are
not encrypted. Store them as sensitive files. The complete data and permission
description is available in [PRIVACY.md](PRIVACY.md).

## Support and Security

Report reproducible problems and feature requests through
[GitHub Issues](https://github.com/CodefrogCF/TerraManager/issues), following
[SUPPORT.md](SUPPORT.md). Do not publish real backups, private notes, pictures,
passwords or signing material. Potential vulnerabilities should follow the
private-first process in [SECURITY.md](SECURITY.md).

## License and Commercial Use

Copyright (C) 2026 CodefrogCF.

TerraManager is free software licensed under the
[GNU General Public License v3.0 or later](LICENSE), identified as
`GPL-3.0-or-later`. The licence permits private and commercial use,
modification and redistribution subject to its terms. In particular, a
distributed modified version must preserve the recipients' GPL freedoms and
provide its corresponding source as required by the licence.

The maintainer may separately offer services, official builds, support,
custom development or alternative commercial licence terms. Those offerings
do not reduce the rights granted for the GPL-licensed project.

Before submitting source code, translations, artwork or substantial
documentation, read [CONTRIBUTING.md](CONTRIBUTING.md). The current
contribution policy deliberately preserves the option of consistent future
dual licensing.

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

Platform-specific functionality such as camera access and gallery storage must
additionally be validated on the target platform. Language selection should be
checked using supported and unsupported system locales.

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

- [Roadmap](docs/roadmap.md)
- [Development guide](docs/development.md)
- [Toolchain and quality-gate baseline](docs/toolchain-baseline.md)
- [Installation and updates](docs/installation-and-updates.md)
- [Platform support](docs/platform-support.md)
- [Data model](docs/data-model.md)
- [Backup format](docs/backup-format.md)
- [Architecture decisions](docs/architecture-decisions.md)
- [MVP functional requirements](docs/functional-requirements-MVP.md)
- [Non-MVP functional requirements](docs/functional-requirements-non-MVP.md)
- [Android release signing](docs/android-release-signing.md)
- [v1.0.0 release validation](docs/release-v1.0.0.md)
- [Privacy](PRIVACY.md)
- [Support](SUPPORT.md)
- [Security policy](SECURITY.md)
- [Contribution policy](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

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
