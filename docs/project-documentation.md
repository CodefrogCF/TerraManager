---
layout: default
title: TerraManager Project Documentation
permalink: /project-documentation.html
---

# TerraManager

TerraManager is a cross-platform, local-first application for managing terrarium boxes, animals and feeding records.

The application is developed with Flutter and currently supports Android and Web.

iOS support is planned, but has not yet been validated because no macOS build environment or physical iOS test device is currently available.

Public project information:

- [Project homepage](https://codefrogcf.github.io/TerraManager/)
- [Installation and updates](installation-and-updates.md)
- [Release checklist](release-checklist.md)
- [Documentation maintenance](documentation-maintenance.md)
- [Roadmap](roadmap.md)
- [Privacy](https://github.com/CodefrogCF/TerraManager/blob/main/PRIVACY.md)
- [Datenschutz (Deutsch)](https://github.com/CodefrogCF/TerraManager/blob/main/PRIVACY.de.md)
- [Support](https://github.com/CodefrogCF/TerraManager/blob/main/SUPPORT.md)
- [Security](https://github.com/CodefrogCF/TerraManager/blob/main/SECURITY.md)
- [Contributing](https://github.com/CodefrogCF/TerraManager/blob/main/CONTRIBUTING.md)
- [GPL-3.0-or-later license](https://github.com/CodefrogCF/TerraManager/blob/main/LICENSE)

## Project Status

The development version is maintained in `pubspec.yaml`; published versions
are listed in GitHub Releases and `CHANGELOG.md`.

Validated release platforms:

- Android
- Web

iOS support remains planned but has not yet been validated.

The current technical compatibility baseline is:

- Database Schema Version 16
- Portable Backup Format Version 2
- permanent Android application ID `com.codefrog.terramanager`

For authoritative details see:

- [Platform support](platform-support.md)
- [Data model](data-model.md)
- [Backup format](backup-format.md)
- [Shared Care API and local accounts](shared-care-api.md)
- [Shared Care Raspberry Pi deployment](shared-care-deployment.md)
- [Installation and updates](installation-and-updates.md)

Published changes are recorded in the
[CHANGELOG](https://github.com/CodefrogCF/TerraManager/blob/main/CHANGELOG.md).

## Current Capabilities

TerraManager provides local-first management for Boxes, Animals, feeding,
weight and shedding histories, reminders, picture galleries, QR workflows,
lifecycle archives and portable backups. The current overview workflows include
optional large-picture presentation, while the archive workflows provide
sorting, restoration and duplication for both Animals and Boxes. QR scanning
supports Box lookup, grouped feeding and confirmed Animal reassignment without
sending collection data to a remote service.

The public homepage and user guides describe the current user-facing workflows:

- [Project homepage](https://codefrogcf.github.io/TerraManager/)
- [German visual user guide](https://codefrogcf.github.io/TerraManager/guide/)
- [English visual user guide](https://codefrogcf.github.io/TerraManager/guide/en/)

Published feature changes are recorded in the repository
[CHANGELOG](https://github.com/CodefrogCF/TerraManager/blob/main/CHANGELOG.md).

Current and planned development work is tracked in the
[roadmap](roadmap.md).

This document intentionally does not maintain a second feature-by-feature
specification.

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

In standalone mode, application data is stored locally on the current device
or browser profile.

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

The optional Shared Care Web mode uses a separate Flutter entry point. It
authenticates against a self-hosted LAN server, which alone owns the SQLite
collection. Shared-mode browsers hold no local collection database and cannot
edit while disconnected. Appearance, language and sorting preferences remain
local to each browser. Big Picture Mode is selected in Settings and applies to
both overviews and their archives. Sorting and Animal category grouping remain
in the overview toolbars, which follow the standalone action order with Reload
as the additional rightmost control. The Android app can open this mode in an external
browser; its local collection remains independent.

Shared Care's active Box overview can scan a physical Box label in a browser
with native QR recognition. The camera image stays on the device; only a
validated Box QR identifier is sent to the operator's API. The scanner does
not fetch an external decoder. Trusted HTTPS is required on other LAN devices.
The [deployment guide](shared-care-deployment.md) lists the full two-device,
scanning and recovery checks still needed for a new installation.

Administrators can download the complete shared collection as a portable
`.tmbackup` and restore a compatible archive after saving a current safety
copy and confirming replacement. Shared archives leave caregiver accounts and
personal browser preferences outside the portable collection. A host-volume
backup is still needed to protect server accounts and sessions.

There is no developer-operated cloud synchronization.

In standalone mode, data stored on one device is not automatically available
on another. Shared Care browsers signed in to the same self-hosted server see
the same collection after refresh.

Portable `.tmbackup` files can be used to manually transfer TerraManager data
between supported devices and platforms.

Backup transfer is not automatic synchronization. A restore replaces the current
local TerraManager state with the selected backup.

## Data Model

The authoritative current database model, entity relationships, lifecycle rules
and schema history are maintained in:

[Data model](data-model.md)

Portable backup representation is intentionally documented separately in:

[Backup format](backup-format.md)

These documents are the technical source of truth for database and backup
compatibility.

## QR Architecture

QR functionality is separated into reusable generation, export, validation and
resolution components.

```text
Box.qrId
    │
    ├── BoxQrCode
    │
    ├── QrExporter
    │       │
    │       ▼
    │    PNG / ZIP / PDF bytes
    │       │
    │       └── Platform save workflow
    │
    └── QR Scanner
            │
            ▼
       QR validation
            │
            ▼
       BoxRepository
            │
            ├── Open Box details
            ├── Start Feeding Mode
            └── Resolve an active destination for Rehouse Mode
```

The QR image itself is not stored in the database. It is generated from the
permanent qrId when needed.
A Rehouse scan resolves the identifier locally and accepts only an existing
active Box. The application asks for confirmation before the repository moves
the active Animal. Unknown, archived and current Box identifiers are rejected.
The reassignment is transactional and does not require a new permission or
network connection.

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

Installation, update, migration and Web deployment instructions are maintained
in the canonical guide:

[Installation and updates](installation-and-updates.md)

Android production signing is maintained separately in:

[Android release signing](android-release-signing.md)

## Privacy and Permissions

TerraManager stores application data locally and has no TerraManager-operated
account, backend, cloud sync, advertising, analytics, telemetry or crash-
reporting service. Camera, gallery and file access is requested only for the
corresponding user-initiated feature. Feeding reminders remain inside the
application and do not request system notification permission.

Portable `.tmbackup` archives include records, settings and pictures and are
not encrypted. Store them as sensitive files. The complete data and permission
description is available in [PRIVACY.md](../PRIVACY.md).

## Support and Security

Report reproducible problems and feature requests through
[GitHub Issues](https://github.com/CodefrogCF/TerraManager/issues), following
[SUPPORT.md](../SUPPORT.md). Do not publish real backups, private notes, pictures,
passwords or signing material. Potential vulnerabilities should follow the
private-first process in [SECURITY.md](../SECURITY.md).

## License and Commercial Use

Copyright (C) 2026 Codefrog.

TerraManager is free software licensed under the
[GNU General Public License v3.0 or later](../LICENSE), identified as
`GPL-3.0-or-later`. The licence permits private and commercial use,
modification and redistribution subject to its terms. In particular, a
distributed modified version must preserve the recipients' GPL freedoms and
provide its corresponding source as required by the licence.

The maintainer may separately offer services, official builds, support,
custom development or alternative commercial licence terms. Those offerings
do not reduce the rights granted for the GPL-licensed project.

Before submitting source code, translations, artwork or substantial
documentation, read [CONTRIBUTING.md](../CONTRIBUTING.md). The current
contribution policy deliberately preserves the option of consistent future
dual licensing.

## Development

Development setup, code generation and issue-level validation are maintained in:

[Development guide](development.md)

The supported toolchain and automated quality-gate baseline are maintained in:

[Toolchain baseline](toolchain-baseline.md)

Release validation is maintained in:

[Release checklist](release-checklist.md)

## Documentation

Documentation ownership, localization alignment, screenshot maintenance and
release-review responsibilities are defined in:

[Documentation maintenance](documentation-maintenance.md)

Key authoritative documents:

- [Installation and updates](installation-and-updates.md)
- [Release checklist](release-checklist.md)
- [Development guide](development.md)
- [Platform support](platform-support.md)
- [Data model](data-model.md)
- [Backup format](backup-format.md)
- [Architecture decisions](architecture-decisions.md)
- [Roadmap](roadmap.md)

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
