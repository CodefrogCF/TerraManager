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
2
```

TerraManager currently supports restore of:

```text
Backup Format 1
Backup Format 2
```

New backups are always created as Backup Format Version 2.

Backup Format Version 1 remains supported for backward compatibility with
backups created by TerraManager 0.6.x.

## Backup Format Version 1

Backup Format Version 1 is the legacy format created by TerraManager 0.6.x.

It remains supported for restore compatibility.

Version 1 uses the following archive structure:

```text
TerraManager_Backup_YYYY-MM-DD_HH-mm.tmbackup
├── manifest.json
├── data.json
├── settings.json
└── media/
    └── animals/
```

## Backup Format Version 2

Backup Format Version 2 is the current format.

It extends portable Box data with dimensions and Box pictures.

Archive structure:

```text
TerraManager_Backup_YYYY-MM-DD_HH-mm.tmbackup
├── manifest.json
├── data.json
├── settings.json
└── media/
    ├── animals/
    └── boxes/
```

Version 2 adds the following portable Box fields:

```text
widthCm
heightCm
depthCm
pictureMediaPath
```

Version 2 does not preserve internal `MediaAsset.id` values.

Box and Animal pictures are stored as portable archive media and recreated as
new `MediaAssets` during restore.

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
  "backupFormatVersion": 2,
  "appVersion": "0.7.0",
  "databaseSchemaVersion": 4,
  "createdAt": "2026-09-03T13:30:00.000Z"
}
```

### backupFormatVersion

Identifies the external TerraManager backup format.

Backup Format Version 2 uses:

```text
2
```

TerraManager 0.7.x accepts Backup Format Versions 1 and 2 for restore.

Version 1 is interpreted using the legacy Box representation. Missing Version 2
Box fields are mapped to `null`.

Unsupported older or future format versions must be rejected before restore.

### appVersion

Contains the TerraManager application version that created the backup.

Example:

```text
0.7.0
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

TerraManager Backup Format Versions 1 and 2 serialize `DateTime` values using ISO 8601.

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

Backup Format Versions 1 and 2 contain:

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

Backup Format Versions 1 and 2 preserve the integer IDs of Boxes, Animals and
FeedingEvents.

This is possible because the current restore model uses full replacement rather than
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

### Backup Format Version 1

A Version 1 Box contains:

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

When a Version 1 backup is restored by TerraManager 0.7.x, the fields introduced
in Version 2 are initialized as:

```text
widthCm = null
heightCm = null
depthCm = null
pictureMediaPath = null
```

### Backup Format Version 2

A Version 2 Box contains:

```text
id
qrId
widthCm
heightCm
depthCm
pictureMediaPath
createdAt
updatedAt
```

Example:

```json
{
  "id": 1,
  "qrId": "TM:BOX:11111111-1111-4111-8111-111111111111",
  "widthCm": 60.0,
  "heightCm": 40.0,
  "depthCm": 45.0,
  "pictureMediaPath": "media/boxes/1.jpg",
  "createdAt": "2026-08-01T10:00:00.000",
  "updatedAt": "2026-08-02T12:00:00.000"
}
```

Box dimensions are optional.

When present, dimensions must be greater than zero.

`pictureMediaPath` is optional.

### Box QR Identifier

`qrId` is the permanent TerraManager Box identifier.

Format:

```text
TM:BOX:<UUID-v4>
```

The QR identifier survives backup and restore unchanged.

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

Backup Format Versions 1 and 2 define:

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

Backup Format Versions 1 and 2 define:

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

Backup Format Versions 1 and 2 define:

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

Backup Format Versions 1 and 2 define:

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

Internal `MediaAsset.id` values and device-specific filesystem paths are not
part of the portable backup format.

Backup Format Version 2 supports portable media for both Animals and Boxes:

```text
media/
├── animals/
│   └── <animalId>.<extension>
└── boxes/
    └── <boxId>.<extension>
```

Animal representation:

```json
{
  "pictureMediaPath": "media/animals/10.jpg"
}
```

Box representation:

```json
{
  "pictureMediaPath": "media/boxes/1.jpg"
}
```

For persistent `MediaAssets`, the archive extension is derived from the stored
filename or MIME type.

Legacy Animal `picturePath` data may still be read during export as a
compatibility fallback.

Boxes have no legacy filesystem picture path.

During restore:

```text
archive media
     │
     ▼
MediaAssets
     │
     ├──► Box.pictureMediaId
     │
     └──► Animal.pictureMediaId
```

New local `MediaAsset.id` values are created during restore.

Internal MediaAsset IDs are not portable domain identities and are therefore
not preserved.

If a `pictureMediaPath` is present, the referenced archive entry must exist,
must not be empty and must use the correct media directory for its record type.

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

Backup Format Versions 1 and 2 contain:

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

Backup Format Versions 1 and 2 define:

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

Backup Format Versions 1 and 2 define:

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

Supported backup formats must not contain conflicting identities.

At minimum:

- Box IDs must be unique
- Animal IDs must be unique
- FeedingEvent IDs must be unique
- Box QR identifiers must be unique

A backup containing duplicate required identities must be rejected.

## Restore Model

The current restore implementation uses full replacement for Backup Format Versions 1 and 2.

Existing TerraManager domain data is not merged with backup data.

Merge restore is explicitly outside the current restore semantics.

The restore sequence is:

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
Show backup information
      │
      ▼
Request explicit confirmation
      │
      ▼
Create and persist safety backup
      │
      ▼
Restore appearance settings
      │
      ▼
Transactional database replacement
      │
      ├── Boxes
      ├── MediaAssets
      ├── Animals
      └── FeedingEvents
      │
      ▼
Foreign-key integrity check
      │
      ▼
Restore complete
```

No destructive database operation begins before validation and explicit user
confirmation succeed.

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

## Transactional Database Replacement

Domain data and persistent media replacement are performed inside a Drift
transaction.

Existing records are deleted in dependency-safe order:

```text
Delete FeedingEvents
Delete Animals
Delete Boxes
Delete MediaAssets
Reset autoincrement sequences
```

Restore insertion order is:

```text
For each Box picture:
    Insert MediaAsset
    obtain new MediaAsset.id

Insert Boxes using pictureMediaId

For each Animal picture:
    Insert MediaAsset
    obtain new MediaAsset.id

Insert Animals using pictureMediaId

Insert FeedingEvents

Run foreign-key integrity check
```

Box and Animal MediaAsset IDs are recreated locally and may differ from IDs in
the source installation.

If any insertion or integrity check fails, the Drift transaction is rolled
back.

If database replacement fails after application settings were changed, the
previous appearance settings are restored.

The pre-restore safety backup is never deleted automatically as part of
rollback.

## Full Replacement vs Merge

Backup Format Versions 1 and 2 intentionally use full replacement.

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

The backup representation does not depend on:

- Android filesystem paths
- browser-specific Blob URLs
- internal MediaAsset IDs
- raw SQLite database files
- Drift-generated implementation details

Box and Animal pictures are exported as archive media entries and restored into
the local `MediaAssets` persistence layer.

The same restore model is therefore used on Android and Web.

Backup Format Version 2 has been manually validated for:

```text
Android → Android
Web → Web
Android → Web
Web → Android
```

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
TerraManager 0.7.x -> Backup Format 2
```

A later application release may continue to use Backup Format 2 if its portable
representation remains compatible, or introduce a new format version when the
external representation changes incompatibly.

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
- MediaAsset database IDs
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

## Backup Format Version 2 Summary

Version 2 contains:

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
├── animals/
└── boxes/
```

Version 2 preserves:

- Box IDs
- permanent Box QR identifiers
- optional Box width, height and depth
- Box pictures through portable media references
- Animal IDs
- active and archived lifecycle state
- Box assignments for active Animals
- archive metadata
- FeedingEvent IDs and relationships
- timestamps and notes
- Animal pictures through portable media references
- appearance settings

Version 2 excludes:

- internal MediaAsset IDs
- generated QR PNG files
- raw SQLite database files
- platform-specific media paths
- cloud data
- merge semantics
- selective restore
- automatic backup scheduling

### Version 1 Restore Compatibility

TerraManager 0.7.x continues to restore Backup Format Version 1.

Version 1 Box records do not contain dimensions or Box pictures. During restore,
the missing Version 2 fields are mapped to null.

Animal media, IDs, relationships, lifecycle state, FeedingEvents and settings
from Version 1 retain their existing restore semantics.

TerraManager 0.7.x creates new backups exclusively as Backup Format Version 2.

Applications that support only Version 1 must reject Version 2 backups rather
than silently restore them while discarding Version 2 Box data.
