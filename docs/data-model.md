# Data Model

TerraManager uses a relational database implemented with Drift and SQLite.

The current Drift database schema version is **8**.

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
├── name
├── status
├── archiveReason
├── archivedAt
├── archiveNotes
├── notes
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
- name – optional free-form Box name
- status – `active` (default) or `archived`, stored as a stable string
- archiveReason – nullable `sold`, `replaced`, `damaged` or `other`
- archivedAt – nullable archive timestamp
- archiveNotes – optional context for archiving, separate from ordinary notes
- notes – optional ordinary Box notes
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

### Box lifecycle persistence (Issue #102)

Schema Version 8 adds `status` with a database default of `active` and nullable
`archiveReason`, `archivedAt` and `archiveNotes` columns. The Version 7 to 8
migration adds columns without replacing or deleting existing records. All
existing Boxes remain active and have empty archive metadata; Animal
assignments, feeding records and pictures are preserved.

Archived Boxes retain their identifier, QR identifier, name, dimensions,
picture, ordinary notes and creation timestamp. Archive reasons use stable
values in SQLite and portable backups, with localized English and German
display labels. Ordinary Box edits preserve lifecycle fields.

Valid portable data requires an archive reason and timestamp for archived
Boxes; active Boxes must have no archive metadata. Backup validation enforces
these rules before restore. Backups with active Animals assigned to archived
Boxes are also rejected.

### Box archive and restore workflows (Issue #103)

Archiving requires confirmation, an archive reason and an empty active-Animal
assignment list. The archive operation checks the Box and assigned Animals
inside a database transaction before setting lifecycle metadata. It never
changes an Animal record. Animal creation, reassignment and restore validate
that their destination Box is active inside the same transaction as the write,
so a stale assignment form cannot refill an archived Box.

Restore changes only archived Boxes back to active and clears their archive
reason, timestamp and archive note. Both operations require the expected
previous status, so duplicate submissions cannot overwrite lifecycle metadata.
The active overview and assignment controls read `getActiveBoxes()`; archived
records remain available through `getArchivedBoxes()` and `getAllBoxes()`
continues to include both states for backups. These workflows require no
additional schema migration.

Permanent deletion is restricted to archived Boxes and removes their associated
picture media in the same transaction. The active Edit Box workflow does not
offer deletion, matching the archive-first lifecycle used for Animals.

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
├── originHabitat
├── weight
├── sheddingNotes
├── restOrDormancyPeriods
├── temperatureZones
├── picturePath
├── pictureMediaId
├── notes
├── archiveReason
├── archivedAt
├── archiveNotes
├── feedingReminderIntervalDays
├── feedingReminderBaseline
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
- originHabitat – optional free-form origin or habitat note
- weight – optional free-form current weight description
- sheddingNotes – optional free-form shedding note
- restOrDormancyPeriods – optional free-form rest or dormancy description
- temperatureZones – optional free-form temperature-zone note
- picturePath – nullable legacy picture reference retained for migration compatibility
- pictureMediaId – nullable foreign key referencing MediaAsset
- notes – optional notes
- archiveReason – optional archive reason
- archivedAt – optional archive date
- archiveNotes – optional archive notes
- feedingReminderIntervalDays – optional positive whole-day feeding interval
- feedingReminderBaseline – fallback timestamp used when no FeedingEvent exists
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
history. It also retains the optional feeding reminder configuration. Reminder
queries suppress archived Animals instead of deleting their configuration.
The archive action is available at the bottom of Edit Animal and warns before
discarding unsaved form changes.

Restoring an archived Animal requires assigning a Box again.

Permanent deletion is intentionally a separate operation. It removes associated
feeding data and application-owned picture media before the Animal record is
considered permanently removed.

Lifecycle consistency is enforced by the repository/application layer.

Nullable Animal fields can be explicitly cleared when an Animal is edited.

### Feeding Reminder Configuration

A feeding reminder is disabled when both reminder fields are `null`:

```text
feedingReminderIntervalDays = null
feedingReminderBaseline = null
```

An enabled reminder requires both fields:

```text
feedingReminderIntervalDays > 0
feedingReminderBaseline = timestamp captured when enabled
```

The create and edit workflows validate this pair before persistence. Capturing
the baseline when a reminder is first enabled prevents an existing Animal with
no feeding history from becoming overdue immediately. Changing only the
interval of an enabled reminder preserves its existing baseline.

### Feeding Reminder Calculation

The due state is derived and is not persisted as another Animal field:

```text
referenceAt = latest FeedingEvent.fedAt ?? feedingReminderBaseline
dueAt = referenceAt + feedingReminderIntervalDays
isDue = evaluatedAt >= dueAt
```

Persisted timestamps are normalized to the same UTC or local representation as
the injected calculation clock before they are exposed in a reminder state.
Their absolute moments remain unchanged, which keeps calculations and tests
consistent across platform time zones.

When no FeedingEvent exists, the baseline is the reference. When feeding
history exists, the latest FeedingEvent remains authoritative even if it
predates the reminder baseline. Equality at the due
timestamp counts as due.

The application queries all active Animals with valid reminder configuration
and aggregates the latest FeedingEvent timestamps for their IDs in one query.
The calculation service does not cache derived state, so a later call reflects
created, edited or deleted FeedingEvents. Disabled and archived Animals are
excluded from reminder results.

Due results are sorted by ascending `dueAt`. This places the most overdue
Animal first and provides deterministic ordering for the reminder UI.

Reminder states remain derived presentation data. The Animal Overview requests
the current due subset for its non-modal summary and list markers. Animal
details request the state for one Animal and display its due or scheduled
timestamp. Feeding history changes trigger a new calculation; no presentation
state is written back to the database.

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

Newly selected or captured Box and Animal pictures are cropped and normalized
before a MediaAsset is created. The stored result uses WebP, a `.webp` filename
and the `image/webp` MIME type. Its longest edge is limited to 1920 pixels
without upscaling.

Existing MediaAssets keep their original format and metadata. No database
migration rewrites previously stored user pictures.

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

Web runtime assets:

```text
web/sqlite3.wasm
web/drift_worker.dart
```

The compiled `drift_worker.dart.js` is generated before the Web build and is
not committed.

Box and Animal pictures are also stored through MediaAssets.

Web database and Box/Animal picture persistence have been validated across normal browser
reloads.

## Schema Version

The current Drift database schema version is 9.

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

### Schema Version 5

Schema version 5 introduced optional per-Animal feeding reminder
configuration.

Changes:

```text
Animal.feedingReminderIntervalDays added
Animal.feedingReminderBaseline added
```

Both columns are nullable. The v4 → v5 migration preserves all existing data
and initializes both fields to `null`, so reminders remain disabled for every
existing Animal until explicitly enabled.

### Schema Version 6

Schema Version 6 adds nullable `Box.notes`. The v5 → v6 migration preserves all
existing rows and leaves the new field `null` for existing Boxes.

### Schema Version 7

Schema Version 7 adds nullable `Box.name`. The v6 → v7 migration preserves all
existing data and keeps existing Boxes unnamed until the user assigns a name.

### Schema Version 8

Schema Version 8 adds the Box lifecycle fields `status`, `archiveReason`,
`archivedAt` and `archiveNotes`. Existing Boxes migrate as active with empty
archive metadata. QR identifiers, assignments, pictures and other records are
preserved.

### Schema Version 9

Schema Version 9 adds five nullable Animal profile columns:

```text
Animal.originHabitat
Animal.weight
Animal.sheddingNotes
Animal.restOrDormancyPeriods
Animal.temperatureZones
```

The v8 → v9 migration only adds nullable columns. It preserves every existing
Box, Animal, FeedingEvent and MediaAsset and initializes the new values to
`null`. The fields are deliberately free-form text in v1.4.0; weight history,
shedding history, calculations, reminders and measurement links remain outside
this schema.
