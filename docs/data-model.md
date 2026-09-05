# Data Model

TerraManager uses a relational database implemented with Drift and SQLite.

The current Drift database schema version is **4**.

The current database model consists of:

- Boxes
- Animals
- FeedingEvents
- MediaAssets

Sensors are planned but are not implemented.

## Entity Relationships

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
 ├── boxId = null
 ├──── 1:n ──── FeedingEvent
 └──── 0:1 ──── MediaAsset
```

An Animal remains the owner of its feeding history and optional picture while
archived.

Planned:

```text
Box
 │
 └──── 1:n ──── Sensor
```

## Box

A Box represents a terrarium, enclosure or physical container managed by
TerraManager.

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

### Fields

- id – auto-incrementing primary key
- qrId – unique permanent QR identifier
- widthCm – optional enclosure width in centimeters
- heightCm – optional enclosure height in centimeters
- depthCm – optional enclosure depth in centimeters
- pictureMediaId – nullable foreign key referencing MediaAsset
- createdAt – creation timestamp
- updatedAt – last modification timestamp

The QR identifier uses the following format:

```text
TM:BOX:<UUID-v4>
```

A Box can contain multiple active Animals and can optionally reference a persistent picture through `pictureMediaId`.

The QR identifier does not contain Animal or Box data. It only identifies the
corresponding database record.

## Animal

An Animal represents an individual animal managed by TerraManager.

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

### Fields

- id – auto-incrementing primary key
- boxId – nullable foreign key referencing Box
- status – active or archived
- commonName – common name
- latinName – scientific name
- sex – optional sex
- birthDate – optional date of birth
- birthDateAccuracy – optional indication of birth date accuracy
- tempMin – preferred minimum temperature
- tempMax – preferred maximum temperature
- humidityMin – preferred minimum humidity
- humidityMax – preferred maximum humidity
- picturePath – nullable legacy picture reference retained for migration compatibility
- pictureMediaId – nullable foreign key referencing MediaAsset
- notes – optional notes
- archiveReason – optional archive reason
- archivedAt – optional archive date
- archiveNotes – optional archive notes
- createdAt – creation timestamp
- updatedAt – modification timestamp

New Animal pictures are stored through `MediaAssets`.

`picturePath` is not the primary picture storage mechanism anymore. It remains
available so pictures created by earlier TerraManager versions can be migrated
safely.

### Lifecycle

Active Animals:

```text
status = active
boxId = assigned Box
archiveReason = null
archivedAt = null
archiveNotes = null
```

Archived Animals:

```text
status = archived
boxId = null
archiveReason = archive reason
archivedAt = archive date
archiveNotes = optional
```

Archiving an Animal does not remove its Animal record, picture or feeding
history.

Restoring an archived Animal requires assigning a Box again.

Permanent deletion is intentionally a separate operation. It removes associated
feeding data and application-owned picture media before the Animal record is
considered permanently removed.

Lifecycle consistency is enforced by the repository/application layer.

Nullable Animal fields can be explicitly cleared when an Animal is edited.

## MediaAsset

A MediaAsset represents application-owned binary media stored persistently by
TerraManager.

```text
MediaAsset
├── id
├── fileName
├── mimeType
├── data
├── createdAt
└── updatedAt
```

### Fields

- id – auto-incrementing primary key
- fileName – original or normalized media filename
- mimeType – MIME type of the stored media
- data – binary media contents
- createdAt – creation timestamp
- updatedAt – modification timestamp

Box and Animal pictures reference MediaAssets through:

```text
Box.pictureMediaId ───────┐
                          ▼
                    MediaAsset.id
                          ▲
Animal.pictureMediaId ────┘
```

The media bytes are therefore controlled by TerraManager instead of relying on
temporary or platform-specific paths returned by image selection APIs.

This persistence model is shared by Android and Web.

Internal `MediaAsset.id` values are not part of the portable backup format.
Backup restore creates new MediaAsset records and assigns their generated IDs to
the restored Boxes and Animals.

## Legacy Picture Migration

Schema migration itself does not attempt to read external image files.

After startup, TerraManager can migrate legacy Animal pictures where:

```text
pictureMediaId = null
picturePath != null
```

If the legacy picture can be read:

```text
legacy picturePath
       │
       ▼
MediaAsset
       │
       ▼
Animal.pictureMediaId

Animal.picturePath = null
```

If the legacy picture cannot be read, the existing `picturePath` is preserved.

A missing legacy picture must therefore not cause database migration or
application startup to fail.

## FeedingEvent

A FeedingEvent represents a feeding performed for an Animal.

```text
FeedingEvent
├── id
├── animalId
├── fedAt
└── notes
```

### Fields

- id – auto-incrementing primary key
- animalId – foreign key referencing Animal
- fedAt – date and time of feeding
- notes – optional notes

Each Animal can have multiple FeedingEvents.

FeedingEvents are ordered by **fedAt**.

The latest feeding is derived from the feeding history through:

```text
FeedingRepository.getLatestFeeding(...)
```

The latest feeding date is therefore not duplicated in the Animal table.

## Sensor

Sensors are planned but are not currently implemented.

Planned relationship:

```text
Box
 └──── 1:n ──── Sensor
```

Sensor fields and supported sensor types will be defined when sensor
functionality is designed.

## Type Converters

Some Dart values are mapped to SQLite-compatible text values using Drift
converters.

Current converters include:

```text
SexConverter
BirthDateAccuracyConverter
AnimalStatusConverter
AnimalArchiveReasonConverter
```

This keeps the Dart domain model type-safe while storing simple SQLite values.

## Database Implementation

Tables are defined in:

```text
lib/core/database/tables/
├── boxes.dart
├── animals.dart
├── feeding_events.dart
└── media_assets.dart
```

The main database is defined in:

```text
lib/core/database/app_database.dart
```

Generated Drift code is located in:

```text
lib/core/database/app_database.g.dart
```

Versioned schema definitions are generated in:

```text
lib/core/database/app_database.steps.dart
```

Generated code must not be edited manually.

## Repositories

Database access is separated through repositories:

```text
lib/core/database/repositories/
├── animal_repository.dart
├── box_repository.dart
├── feeding_repository.dart
└── media_repository.dart
```

Examples of repository responsibilities:

```text
BoxRepository
├── create Box
├── retrieve Boxes
├── resolve qrId
├── update Box
└── delete Box

AnimalRepository
├── create Animal
├── retrieve active Animals
├── retrieve archived Animals
├── retrieve active Animals for Box
├── update active Animal
├── archive Animal
├── restore Animal
└── permanently delete archived Animal

FeedingRepository
├── create FeedingEvent
├── create multiple FeedingEvents atomically
├── retrieve feeding history
├── retrieve latest feeding
├── update FeedingEvent
└── delete FeedingEvent

MediaRepository
├── create MediaAsset
├── retrieve MediaAsset
├── update MediaAsset
└── delete MediaAsset
```

## Platform Persistence

### Android

Drift uses native SQLite storage.

Box and Animal pictures are stored as MediaAssets in the local database.

### Web

Drift uses SQLite WASM and a Web worker.

Required assets:

```text
web/sqlite3.wasm
web/drift_worker.dart.js
```

Box and Animal pictures are also stored through MediaAssets.

Web database and Box/Animal picture persistence have been validated across normal browser
reloads.

## Schema Version

The current Drift database schema version is 4.

### Schema Version 1

Initial domain schema containing Boxes, Animals and FeedingEvents.

### Schema Version 2

Schema version 2 introduced Animal lifecycle support and changed boxId from
required to nullable.

The v1 → v2 migration preserves existing Animals, Box assignments and feeding
history.

Existing Animals are migrated with:

```text
status = active
```

### Schema Version 3

Schema version 3 introduced persistent application-owned media.

Changes:

```text
MediaAssets table added
Animal.pictureMediaId added
```

The v2 → v3 schema migration preserves:

- existing Boxes
- existing Animals
- existing FeedingEvents
- existing picturePath values

Existing picture files are not read during the Drift schema migration.

Readable legacy pictures are migrated separately after application startup.

### Schema Version 4

Schema version 4 introduced editable Box metadata and persistent Box pictures.

Changes:

```text
Box.widthCm added
Box.heightCm added
Box.depthCm added
Box.pictureMediaId added
```

`Box.pictureMediaId` is a nullable foreign key referencing `MediaAssets`.

The v3 → v4 migration preserves existing Boxes, Animals, FeedingEvents and
MediaAssets. Existing Boxes receive `null` for the newly introduced optional
fields.
