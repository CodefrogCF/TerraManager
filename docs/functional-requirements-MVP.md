# Functional Requirements – MVP

This document defines the functionality intended for the TerraManager MVP.

Implementation progress is tracked separately in `roadmap.md`.

## Boxes

The application must allow the user to:

- create a new Box
- automatically assign a permanent unique QR identifier
- view the Box overview
- view Box details
- view Animals assigned to a Box
- open an assigned Animal from the Box detail screen
- delete an empty Box
- require confirmation before deleting a Box
- prevent accidental deletion of a Box containing Animals
- identify a Box by QR code

The permanent QR identifier must remain unchanged when associated application
data changes.

## Animals

The application must allow the user to:

- create an Animal
- assign an Animal to a Box
- view the Animal overview
- view Animal details
- edit Animal data
- change the associated Box
- add or remove an Animal picture
- persist Animal pictures across normal application restarts or browser reloads
- add and edit notes
- store preferred temperature values
- store preferred humidity values
- store optional birth information
- store optional sex information
- archive an Animal without losing its data
- select an archive reason and archive date
- store an optional archive note
- remove archived Animals from active Box assignments
- view archived Animals in Animal History
- open archived Animal details
- restore an archived Animal to a selected Box
- preserve feeding history while an Animal is archived
- preserve its picture while an Animal is archived
- permanently delete an archived Animal through an explicit confirmation workflow

Active Animals must have a Box assignment.

Archived Animals must not have an active Box assignment.

Application-owned Animal pictures must use persistent TerraManager storage and
must not depend on temporary image-selection paths for normal operation.

## Feeding

The application must allow the user to:

- add a FeedingEvent
- store an optional feeding note
- view complete feeding history
- determine the latest feeding
- display the latest feeding directly on the Animal detail screen

The latest feeding must be derived from feeding history rather than duplicated
in the Animal record.

The Animal detail screen must display the most recent FeedingEvent, including
its timestamp and optional note.

The displayed value must refresh after the feeding history is modified.

## QR Codes

The application must allow the user to:

- generate a unique QR ID for a Box
- generate a QR code from the Box ID
- display the QR code
- export the QR code as PNG
- save/download the QR image
- print the QR code
- scan a QR code
- validate TerraManager QR identifiers
- resolve a scanned QR identifier to a Box
- report invalid QR codes
- report valid but unknown TerraManager QR identifiers

The QR code must contain only the stable Box identifier.

Generated QR images are derived data and do not need to be persisted in the
domain database or portable backups.

## Settings

The application must allow the user to:

- use the operating system theme
- explicitly select Light mode
- explicitly select Dark mode
- select an application accent color
- persist appearance settings between application restarts

Appearance settings must be included in portable TerraManager backups.

## Persistence

Core application data must be stored locally.

Data must survive normal application restarts.

The MVP does not require cloud synchronization.

Core domain data is stored with Drift/SQLite.

Application-owned Animal pictures are stored persistently through MediaAssets in
the local Drift database.

Appearance preferences are stored separately through `shared_preferences`.

Domain data, Animal pictures and appearance preferences must survive normal
application restarts or browser reloads on validated platforms.

## Platform Targets

The MVP targets:

- Android
- Web

iOS is planned but is not required to be validated before the current MVP
milestones can continue.

Android and Web are validated platforms.

## Backup and Restore

The application must allow the user to:

- create a portable backup of local TerraManager data
- export Boxes
- export Animals
- export FeedingEvents
- export Animal pictures
- export appearance settings
- select an existing TerraManager backup
- inspect backup metadata before restore
- restore a compatible TerraManager backup
- validate a backup before modifying existing data
- validate domain relationships
- validate lifecycle state
- validate referenced media
- validate permanent Box QR identifiers
- create a safety backup before destructive database replacement
- explicitly confirm replacement of existing local data
- restore persistent Animal pictures
- restore appearance settings

The backup format must be independent from the raw SQLite database file.

Backups must use an explicit backup format version that is independent from the
database schema version.

Generated QR images are not included because they can be recreated from the
permanent Box `qrId`.

Portable backup media references must not expose device-specific filesystem
paths, browser Blob URLs or internal MediaAsset IDs.

The initial restore implementation uses full replacement.

Merging backup data with existing application data is not required for the MVP.

Backup Format Version 1 must support manual transfer between the currently
validated platforms:

```text
Android → Android
Web → Web
Android → Web
Web → Android
```

Restore must fail safely when validation or transactional database replacement
fails.