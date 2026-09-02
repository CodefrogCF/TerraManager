# TerraManager Backup Format

This document defines the portable TerraManager backup file format.

## File Extension

TerraManager backups use:

```text
.tmbackup
```

The file is an archive containing structured data and optional media.

## Versioning

The backup format has an independent version number:

```text
backupFormatVersion
```

This must not be confused with the Drift database schema version:

```text
databaseSchemaVersion
```

A change to the database schema does not automatically require a new backup
format version.

A backup format version changes only when the external portable backup
representation becomes incompatible.

## Backup Format Version 1

Structure:

```text
TerraManager_Backup_YYYY-MM-DD_HH-mm.tmbackup
├── manifest.json
├── data.json
├── settings.json
└── media/
    └── animals/
```

Future versions may add additional media directories without changing the
meaning of existing entries.

## manifest.json

The manifest contains metadata required before data import begins.

Required information:

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
  "createdAt": "2026-09-02T12:00:00Z"
}
```

## data.json

`data.json` contains portable representations of TerraManager domain data.

Version 1 contains:

```text
boxes
animals
feedingEvents
```

Relationships must remain valid after restore.

Permanent Box QR identifiers must be preserved unchanged.

## Media

Device-specific filesystem paths are not portable and must not be treated as
backup identifiers.

Animal pictures are copied into the backup archive and referenced from the
serialized Animal data through portable media references.

During restore, media is written to storage appropriate for the target
platform and the restored database receives the new local reference.

## Settings

`settings.json` contains application preferences that are part of the backed-up
application state.

Version 1 includes:

```text
themeMode
accent
```

## QR Images

Generated QR PNG files are not included.

QR images are derived from:

```text
Box.qrId
```

and can therefore be regenerated after restore.

## Restore Model

Backup format version 1 uses full replacement.

Existing TerraManager data is not merged with the backup.

Before destructive restore:

- validate the backup
- create a safety backup of current data
- request explicit confirmation
- replace the current data
- restore media and settings
- verify the restored application state

## Compatibility

TerraManager must reject backup format versions that it does not understand.

Unsupported or invalid backups must never cause existing data to be deleted.

## Future Compatibility

Possible future additions include:

- Box pictures
- AnimalBoxAssignment history
- sensor data
- additional settings

New application versions should preserve the ability to read supported older
backup format versions whenever practical.