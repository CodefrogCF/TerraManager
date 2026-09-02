# TerraManager Backup Format

This document defines the portable TerraManager backup format.

The backup format is designed to preserve TerraManager data independently from
the underlying Drift/SQLite database implementation and from platform-specific
file paths.

The same backup format is intended to be usable on all supported TerraManager
platforms.

## File Extension

TerraManager backups use the following file extension:

```text
.tmbackup
```

A backup file is an archive containing structured data and optional media.

Example filename:

```text
TerraManager_Backup_2026-09-02_15-30.tmbackup
```

## Goals

The backup format must:

- be portable between supported platforms
- be independent from the raw SQLite database file
- preserve relationships between domain records
- preserve permanent Box QR identifiers
- include required user media
- avoid storing platform-specific local file paths
- support explicit format versioning
- allow future TerraManager versions to validate compatibility before restore
- fail safely when a backup is invalid or unsupported

## Versioning

The backup format has its own version number:

```text
backupFormatVersion
```

This value is independent from the Drift database schema version:

```text
databaseSchemaVersion
```

For example:

```text
backupFormatVersion = 1
databaseSchemaVersion = 2
```

A database schema change does not automatically require a new backup format
version.

The backup format version changes only when the external portable backup
representation becomes incompatible with the previous format.

The current backup format version is:

```text
1
```

## Backup Format Version 1

Backup Format Version 1 uses the following archive structure:

```text
TerraManager_Backup_YYYY-MM-DD_HH-mm.tmbackup
├── manifest.json
├── data.json
├── settings.json
└── media/
    └── animals/
```

Future TerraManager versions may introduce additional media directories or
additional data fields where backward compatibility can be preserved.

## manifest.json

`manifest.json` contains metadata required to identify and validate a backup
before any restore operation begins.

Required fields:

```text
backupFormatVersion
appVersion
databaseSchemaVersion
createdAt
```

Example:

```json
{
  "backupFormatVersion": 1,
  "appVersion": "0.6.0",
  "databaseSchemaVersion": 2,
  "createdAt": "2026-09-02T13:30:00.000Z"
}
```

### backupFormatVersion

Identifies the external TerraManager backup format.

Backup Format Version 1 uses:

```text
1
```

A TerraManager version must reject backup format versions that it does not
support.

### appVersion

Contains the TerraManager application version that created the backup.

Example:

```text
0.6.0
```

This value is informational and may also be used during compatibility
validation.

### databaseSchemaVersion

Contains the Drift database schema version used by the TerraManager version that
created the backup.

This value does not define the backup structure.

It exists as metadata to assist with diagnostics and compatibility handling.

### createdAt

Contains the backup creation timestamp.

Timestamps in the backup format use ISO 8601 strings.

Example:

```text
2026-09-02T13:30:00.000Z
```

## Timestamp Format

TerraManager Backup Format Version 1 serializes `DateTime` values using ISO 8601.

Dart serialization uses:

```dart
dateTime.toIso8601String()
```

Deserialization uses:

```dart
DateTime.parse(...)
```

Raw Drift or SQLite timestamp representations must not be exposed as the
portable backup representation.

## data.json

`data.json` contains portable representations of TerraManager domain data.

Backup Format Version 1 contains:

```text
boxes
animals
feedingEvents
```

Example top-level structure:

```json
{
  "boxes": [],
  "animals": [],
  "feedingEvents": []
}
```

The three collections must always be present, including when they are empty.

## Record IDs

Backup Format Version 1 preserves the integer IDs of Boxes, Animals and
FeedingEvents.

This is possible because Restore Version 1 uses full replacement rather than
merge semantics.

Preserving IDs keeps existing relationships deterministic:

```text
Box.id
  ↑
Animal.boxId

Animal.id
  ↑
FeedingEvent.animalId
```

For example:

```text
Box.id = 4
Animal.boxId = 4

Animal.id = 17
FeedingEvent.animalId = 17
```

A future merge-import implementation must not assume that source database IDs
can be inserted unchanged.

Such an implementation may require a separate source-to-target ID mapping
strategy.

## Box Representation

A Box is serialized with the following fields:

```text
id
qrId
createdAt
updatedAt
```

Example:

```json
{
  "id": 1,
  "qrId": "TM:BOX:11111111-1111-4111-8111-111111111111",
  "createdAt": "2026-08-01T10:00:00.000",
  "updatedAt": "2026-08-02T12:00:00.000"
}
```

### Box QR Identifier

`qrId` is a permanent TerraManager Box identifier.

Format:

```text
TM:BOX:<UUID-v4>
```

The QR identifier must survive backup and restore unchanged.

Generated QR images are not stored because they can be regenerated from the
permanent `qrId`.

## Animal Representation

An Animal is serialized with the following fields:

```text
id
boxId
status
commonName
latinName
sex
birthDate
birthDateAccuracy
tempMin
tempMax
humidityMin
humidityMax
pictureMediaPath
notes
archiveReason
archivedAt
archiveNotes
createdAt
updatedAt
```

Example active Animal:

```json
{
  "id": 10,
  "boxId": 1,
  "status": "active",
  "commonName": "Test Snake",
  "latinName": "Pantherophis guttatus",
  "sex": "female",
  "birthDate": "2024-01-01T00:00:00.000",
  "birthDateAccuracy": "yearKnown",
  "tempMin": 24.0,
  "tempMax": 28.0,
  "humidityMin": 40.0,
  "humidityMax": 60.0,
  "pictureMediaPath": "media/animals/10.jpg",
  "notes": "Test animal",
  "archiveReason": null,
  "archivedAt": null,
  "archiveNotes": null,
  "createdAt": "2026-08-01T10:00:00.000",
  "updatedAt": "2026-08-02T12:00:00.000"
}
```

Example archived Animal:

```json
{
  "id": 11,
  "boxId": null,
  "status": "archived",
  "commonName": "Archived Snake",
  "latinName": "Pantherophis guttatus",
  "sex": null,
  "birthDate": null,
  "birthDateAccuracy": null,
  "tempMin": 24.0,
  "tempMax": 28.0,
  "humidityMin": 40.0,
  "humidityMax": 60.0,
  "pictureMediaPath": null,
  "notes": null,
  "archiveReason": "rehomed",
  "archivedAt": "2026-09-01T00:00:00.000",
  "archiveNotes": "Moved to another keeper",
  "createdAt": "2026-08-01T10:00:00.000",
  "updatedAt": "2026-09-01T00:00:00.000"
}
```

## Animal Lifecycle Invariants

Lifecycle consistency is part of backup validation.

### Active Animal

An active Animal uses:

```text
status = "active"
boxId = valid Box ID
archiveReason = null
archivedAt = null
archiveNotes = null
```

The referenced Box must exist in the backup.

### Archived Animal

An archived Animal uses:

```text
status = "archived"
boxId = null
archiveReason = defined archive reason
archivedAt = defined timestamp
archiveNotes = optional
```

Archived Animals retain their Animal record and FeedingEvent history.

Unknown or contradictory lifecycle combinations must cause backup validation to
fail before restore begins.

## FeedingEvent Representation

A FeedingEvent is serialized with the following fields:

```text
id
animalId
fedAt
notes
```

Example:

```json
{
  "id": 100,
  "animalId": 10,
  "fedAt": "2026-08-20T18:30:00.000",
  "notes": "Mouse"
}
```

`animalId` must reference an Animal contained in the same backup.

The chronological latest feeding remains derived from FeedingEvents and is not
stored separately.

## Stable Enum Values

Enum values stored in backups are part of the external backup format.

They must not be generated implicitly from Dart enum names during export.

TerraManager uses explicit encoding and decoding for backup enum values.

This allows internal Dart enum names to evolve independently while preserving
compatibility with existing backup files.

Unknown enum values must cause backup validation to fail instead of being
silently replaced with default values.

### AnimalStatus

Backup Format Version 1 defines:

```text
active
archived
```

Mapping:

```text
AnimalStatus.active   -> "active"
AnimalStatus.archived -> "archived"
```

### AnimalArchiveReason

Backup Format Version 1 defines:

```text
sold
traded
deceased
rehomed
other
```

Mapping:

```text
AnimalArchiveReason.sold     -> "sold"
AnimalArchiveReason.traded   -> "traded"
AnimalArchiveReason.deceased -> "deceased"
AnimalArchiveReason.rehomed  -> "rehomed"
AnimalArchiveReason.other    -> "other"
```

### BirthDateAccuracy

Backup Format Version 1 defines:

```text
exact
monthKnown
yearKnown
```

Mapping:

```text
BirthDateAccuracy.exact      -> "exact"
BirthDateAccuracy.monthKnown -> "monthKnown"
BirthDateAccuracy.yearKnown  -> "yearKnown"
```

### Sex

Backup Format Version 1 defines:

```text
male
female
unknown
```

Mapping:

```text
Sex.male    -> "male"
Sex.female  -> "female"
Sex.unknown -> "unknown"
```

## Media References

Device-specific filesystem paths are not portable and must never be stored as
portable backup media identifiers.

Example of a local device path:

```text
/data/user/0/.../animal.jpg
```

This value must not appear as `pictureMediaPath` inside the portable backup.

Instead, the referenced media file is copied into the archive.

Example:

```text
media/animals/10.jpg
```

The archive filename extension is preserved when a recognized image extension
is available.

If the source reference does not expose a usable image extension, TerraManager
may use the generic `.img` extension.

The media content itself remains unchanged.

The Animal representation then stores:

```json
{
  "pictureMediaPath": "media/animals/10.jpg"
}
```

During restore:

```text
backup media file
        │
        ▼
platform-appropriate media storage
        │
        ▼
new local picturePath
        │
        ▼
restored Animal record
```

The original device-specific `picturePath` is therefore not preserved.

This allows backups to remain portable between Android and Web.

## Missing Pictures

Animals without pictures use:

```json
{
  "pictureMediaPath": null
}
```

If `pictureMediaPath` contains a media reference, the referenced file must exist
inside the backup archive.

A missing referenced media file makes the backup invalid.

## Future Media

The media hierarchy may be extended in future backup-compatible versions.

For example:

```text
media/
├── animals/
└── boxes/
```

This allows future Box pictures or other media types to be added without
relying on platform-specific paths.

## QR Images

Generated QR PNG files are not included in TerraManager backups.

QR images are derived from:

```text
Box.qrId
```

and can therefore be regenerated after restore.

Excluding generated QR images:

- reduces backup size
- avoids storing redundant data
- prevents duplicate derived representations
- keeps the permanent QR identifier as the source of truth

## settings.json

`settings.json` contains portable application appearance preferences.

Backup Format Version 1 contains:

```text
themeMode
accent
```

Example:

```json
{
  "themeMode": "dark",
  "accent": "green"
}
```

Settings values are also part of the backup format contract and must be
explicitly encoded and validated.

## Stable Theme Mode Values

Backup Format Version 1 defines:

```text
system
light
dark
```

Mapping:

```text
ThemeMode.system -> "system"
ThemeMode.light  -> "light"
ThemeMode.dark   -> "dark"
```

Unknown theme mode values must cause validation to fail.

## Stable Accent Values

Backup Format Version 1 defines:

```text
green
blue
teal
orange
purple
red
```

These correspond to the predefined TerraManager application accent choices.

Unknown accent values must cause validation to fail.

## Archive Validation

Before restore, the complete backup archive must be validated.

Validation includes at least:

- expected archive structure
- `manifest.json` exists
- `data.json` exists
- `settings.json` exists
- supported `backupFormatVersion`
- valid JSON
- required fields
- valid field types
- valid timestamps
- supported enum values
- supported settings values
- valid TerraManager QR identifiers
- unique Box QR identifiers
- valid Box references
- valid Animal references
- valid lifecycle combinations
- referenced media files exist

Validation must complete successfully before existing TerraManager data is
modified.

### Archive Path Safety

Archive entry paths must be portable relative paths using `/` as separator.

The following are rejected:

- absolute paths
- Windows-style backslash paths
- drive-qualified paths
- `.` path segments
- `..` path segments
- duplicate archive entry names

This prevents backup archives from referencing files outside their intended
restore location.

## Relationship Validation

The following relationships must be valid.

### Animal → Box

For every active Animal:

```text
Animal.boxId
```

must reference an existing Box.

Archived Animals must use:

```text
boxId = null
```

### FeedingEvent → Animal

Every:

```text
FeedingEvent.animalId
```

must reference an existing Animal.

Broken references make the backup invalid.

## Duplicate Validation

Backup Format Version 1 must not contain conflicting identities.

At minimum:

- Box IDs must be unique
- Animal IDs must be unique
- FeedingEvent IDs must be unique
- Box QR identifiers must be unique

A backup containing duplicate required identities must be rejected.

## Restore Model

Backup Format Version 1 uses full replacement.

Existing TerraManager domain data is not merged with backup data.

Merge restore is explicitly outside Backup Format Version 1 restore semantics.

The intended restore sequence is:

```text
Select backup
      │
      ▼
Read archive
      │
      ▼
Validate complete backup
      │
      ▼
Create safety backup of current state
      │
      ▼
Request explicit confirmation
      │
      ▼
Replace current TerraManager data
      │
      ▼
Restore media
      │
      ▼
Restore settings
      │
      ▼
Verify restored state
```

No destructive operation may begin before validation succeeds.

## Pre-Restore Safety Backup

Before replacing existing TerraManager data, the current application state must
be backed up.

The safety backup exists to reduce the risk of accidental data loss caused by:

- selecting the wrong backup
- user error
- restore failure
- unexpected compatibility problems

The restore workflow must not silently discard the current state.

## Restore Failure

An invalid backup must never modify existing TerraManager data.

If validation fails:

```text
existing database = unchanged
existing media = unchanged
existing settings = unchanged
```

Restore implementation must avoid leaving the application in an apparently
successful but partially restored state.

Exact transactional and recovery behavior is defined by the restore
implementation.

## Full Replacement vs Merge

Backup Format Version 1 intentionally uses full replacement.

Merge restore is not supported.

This avoids ambiguity around:

- conflicting numeric IDs
- duplicate QR identifiers
- duplicate Animals
- FeedingEvent foreign keys
- archived lifecycle state
- media conflicts

A future merge implementation will require explicit conflict-resolution and ID
mapping rules.

## Cross-Platform Portability

The backup representation must not depend on:

- Android filesystem paths
- browser-specific storage identifiers
- raw SQLite database files
- Drift-generated implementation details

A backup produced on one validated platform should therefore be structurally
usable on another validated platform.

Platform-specific restore logic is responsible for converting portable media
references into appropriate local storage references.

## Compatibility Rules

TerraManager must reject backup format versions that it does not understand.

For example, an application that supports only:

```text
backupFormatVersion = 1
```

must reject:

```text
backupFormatVersion = 2
```

unless explicit support for Version 2 has been implemented.

Unsupported backups must never trigger destructive restore operations.

## Database Schema Compatibility

`databaseSchemaVersion` is metadata and is not itself the backup parser version.

A future TerraManager version may restore a backup created from an older
database schema if it still understands that backup format.

For example:

```text
Backup:
backupFormatVersion = 1
databaseSchemaVersion = 2

Future application:
backupFormatVersion 1 supported
databaseSchemaVersion = 4
```

This can remain compatible if the application provides the required mapping from
Backup Format Version 1 into its current domain model.

## Backup Format Evolution

Future TerraManager versions may add data such as:

- Box dimensions
- Box pictures
- AnimalBoxAssignment history
- sensor data
- additional settings
- additional media

Where possible, new application versions should preserve support for older
backup formats.

A new backup format version should be introduced when the external portable
representation changes incompatibly.

## Backup Format Version vs Application Version

Application versions and backup format versions evolve independently.

For example:

```text
TerraManager 0.6.0 -> Backup Format 1
TerraManager 0.7.0 -> Backup Format 1
TerraManager 0.8.0 -> Backup Format 1
```

is valid if all additional data can be represented compatibly.

A new application release does not automatically require:

```text
backupFormatVersion + 1
```

## Source of Truth

The portable backup representation is the compatibility boundary.

Internal implementation details such as:

- Dart enum names
- Drift table implementation
- generated Drift classes
- SQLite timestamp representation
- local picture paths
- SharedPreferences keys

must not be treated as stable external backup values unless explicitly defined
by this document.

## Backup Format Version 1 Summary

Version 1 contains:

```text
manifest.json
├── backupFormatVersion
├── appVersion
├── databaseSchemaVersion
└── createdAt

data.json
├── boxes
├── animals
└── feedingEvents

settings.json
├── themeMode
└── accent

media/
└── animals/
```

Version 1 preserves:

- Box IDs
- permanent Box QR identifiers
- Animal IDs
- active and archived lifecycle state
- Box assignments for active Animals
- archive metadata
- FeedingEvent IDs
- FeedingEvent relationships
- timestamps
- notes
- animal pictures through portable media references
- appearance settings

Version 1 excludes:

- generated QR PNG files
- raw SQLite database files
- platform-specific media paths
- cloud data
- merge semantics
- selective restore
- automatic backup scheduling