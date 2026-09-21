# Data Model

TerraManager uses a relational database implemented with Drift and SQLite.

The current Drift database schema version is **15**.

The current database model consists of:

- Boxes
- Animals
- AnimalWeightEntries
- FeedingEvents
- MediaAssets
- AnimalPictureAssociations
- BoxPictureAssociations

Sensors are planned but are not implemented.

## Entity Relationships

```text
Box
 │
 ├──── 1:n ──── BoxPictureAssociation ──── 1:1 ──── MediaAsset
 │
 └──── 1:n ──── Active Animal
                   │
                   ├──── 1:n ──── AnimalWeightEntry
                   │
                   ├──── 1:n ──── FeedingEvent
                   │
                   └──── 1:n ──── AnimalPictureAssociation ──── 1:1 ──── MediaAsset

Archived Animal
 │
 ├── boxId = null
 ├──── 1:n ──── AnimalWeightEntry
 ├──── 1:n ──── FeedingEvent
 └──── 1:n ──── AnimalPictureAssociation ──── 1:1 ──── MediaAsset
```

An Animal remains the owner of its weight history, feeding history and picture
gallery while archived.

`Box.pictureMediaId` and `Animal.pictureMediaId` identify the primary detail
image within the corresponding gallery. They can be `null` while historical
gallery entries remain stored.

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
├── temperatureZones
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
- temperatureZones – optional free-form temperature-zone note
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

A Box can contain multiple active Animals and can reference one gallery image
as its primary picture through `pictureMediaId`.

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
picture gallery in the same transaction. The active Edit Box workflow does not
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
├── nighttimeTemperature
├── nighttimeTemperatureMin
├── nighttimeTemperatureMax
├── humidityMin
├── humidityMax
├── originHabitat
├── weight
├── sheddingNotes         (legacy)
├── restOrDormancyPeriods
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
- tempMin – preferred minimum daytime temperature
- tempMax – preferred maximum daytime temperature
- nighttimeTemperature – legacy single nighttime temperature retained for
  migration and older backup compatibility
- nighttimeTemperatureMin – optional preferred minimum nighttime temperature
- nighttimeTemperatureMax – optional preferred maximum nighttime temperature
- humidityMin – preferred minimum humidity
- humidityMax – preferred maximum humidity
- originHabitat – optional free-form origin or habitat note
- weight – legacy free-form weight retained only when it cannot be migrated
  safely to grams
- sheddingNotes – legacy nullable free-form shedding note retained only for
  migration and older backup compatibility; current application workflows use
  `SheddingEvents`
- restOrDormancyPeriods – optional free-form rest or dormancy description
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

New Animal pictures are stored through `MediaAssets` and ordered gallery
associations.

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

Archiving an Animal does not remove its Animal record, picture, weight history,
shedding history or feeding history. It also retains the optional feeding
reminder configuration. Reminder queries suppress archived Animals instead of
deleting their configuration. The archive action is available at the bottom
of Edit Animal and warns before discarding unsaved form changes.

Restoring an archived Animal requires assigning a Box again.

Permanent deletion is intentionally a separate operation. It removes associated
feeding data and application-owned gallery media before the Animal record is
considered permanently removed.

Lifecycle consistency is enforced by the repository/application layer.

Nullable Animal fields can be explicitly cleared when an Animal is edited.

The current numeric weight is derived from the newest `AnimalWeightEntry` by
`measuredAt` and deterministic ID tie breaking. Saving the same numeric value or
editing unrelated fields does not create another entry.

## AnimalWeightEntry

An AnimalWeightEntry records one positive Animal weight measurement in grams.

```text
AnimalWeightEntry
├── id
├── animalId
├── weightGrams
└── measuredAt
```

### Fields

- id – auto-incrementing primary key
- animalId – foreign key referencing Animal with cascading deletion
- weightGrams – positive finite decimal weight in grams
- measuredAt – measurement timestamp

Entries are returned in reverse chronological order. Archiving retains every
entry, permanent Animal deletion removes them through the foreign key, and
duplication creates one fresh entry from the source Animal's current weight
instead of copying its complete history. Animal details provide a quick entry
action, and the history view can add measurements or correct an existing
measurement's gram value and timestamp without creating another row. Individual
entries can be permanently deleted after confirmation; the next newest entry
then becomes the current weight.

### SheddingEvent

```text
SheddingEvent
├── id
├── animalId
├── shedAt
├── notes
├── createdAt
└── updatedAt
```

An Animal can have zero or more shedding events.
`animalId` references the owning Animal. `shedAt` records when the shedding
occurred. `notes` is optional. `createdAt` and `updatedAt` preserve event
metadata independently from the Animal record.
Shedding history is ordered by `shedAt` descending and then by event ID
descending for deterministic ties.
Archiving an Animal retains its complete shedding history. Permanent Animal
deletion removes the associated shedding events through the database
relationship.

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

## Record Duplication

Duplication creates a normal independent record through repository
transactions; the database does not store a link between source and duplicate.
No schema or portable backup-format change is required.

A Box duplicate receives a new auto-incremented `id`, a newly generated unique
`qrId`, active lifecycle state and cleared archive metadata. Its name is chosen
in the duplication dialog. Dimensions, notes and other reusable values are
copied. Every source gallery image is inserted as a new MediaAsset with the
same order, timestamp and primary selection, so later edits or deletion of
either record cannot remove the other record's pictures.
Assigned Animals remain assigned to the source and are not duplicated with the
Box.

An Animal duplicate receives a new auto-incremented `id`, active lifecycle
state, a selected active `boxId` and a common name chosen in the dialog. Profile,
environmental, reminder and optional characteristic values are copied. Archive
metadata and FeedingEvents are not copied. Every gallery image uses another
independent MediaAsset. These rules also allow an archived Animal to serve as the source
without modifying or restoring that source.

Current Backup Format Version 2 exports duplicated records and their independent
media exactly like any other Box or Animal.

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

Box and Animal galleries reference MediaAssets through association rows. The
existing nullable owner field selects the primary image:

```text
Box ──── 1:n ──── BoxPictureAssociation ──── 1:1 ──── MediaAsset
 │
 └── pictureMediaId ────────────────────────────────────┘

Animal ── 1:n ──── AnimalPictureAssociation ── 1:1 ──── MediaAsset
 │
 └── pictureMediaId ─────────────────────────────────────────┘
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

## Picture Galleries (Issue #78)

`AnimalPictureAssociations` and `BoxPictureAssociations` contain an
auto-incremented ID, the owning record ID, one unique `mediaAssetId`, a
`capturedAt` timestamp and a per-owner `sortOrder`. A unique owner/order pair
keeps chronological presentation deterministic, and cascading owner deletion
removes association rows before unreferenced MediaAssets are deleted.

Adding or replacing the visible detail image creates a new MediaAsset and
appends an association. Earlier entries remain in the gallery. Selecting a
historical entry only changes the owner's `pictureMediaId`. Clearing the
primary image does not delete history. Deleting an individual entry requires
confirmation; deleting the primary entry promotes the newest remaining image,
and unrelated media is never removed.

Capture and Gallery imports continue through the existing explicit image
selection, crop and normalization flow. Gallery storage and viewing are local
database operations and add no platform permission.

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
├── animal_weight_entries.dart
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
├── animal_weight_repository.dart
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

AnimalWeightRepository
├── add a positive finite measurement
├── retrieve reverse-chronological history
├── retrieve the current measurement
├── update an owned measurement
└── delete an owned measurement

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

The current Drift database schema version is 15.

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

### Schema Version 10

Schema Version 10 adds the Animal taxonomy columns:

```text
Animal.category
Animal.subcategory
```

`category` is non-null and defaults to the stable value `other`.
`subcategory` is nullable and must be compatible with its primary category.
The v9 → v10 migration preserves every existing Box, Animal, FeedingEvent and
MediaAsset; existing Animals begin as `other` without a subcategory. The
released Schema Version 10 snapshot retains `Animal.temperatureZones` and does
not contain a Box temperature-zone column.

Stable categories follow this canonical order:

```text
amphibian
reptile
arachnid
insect
myriapod
crustacean
mollusc
otherInvertebrate
other
```

Compatible subcategories are:

```text
amphibian: frogOrToad, newtOrSalamander, other
reptile: snake, lizard, turtle, other
arachnid: tarantula, otherSpider, scorpion,
          whipSpiderOrWhipScorpion, other
insect: beetle, cockroach, mantis, grasshopperOrCricket, other
myriapod: millipede, centipede, other
crustacean: isopod, crab, other
mollusc: snail, other
otherInvertebrate: no subcategory
other: no subcategory
```

Localized display labels are derived from these portable values and are never
stored in the database.

### Schema Version 11

Schema Version 11 adds one nullable enclosure field:

```text
Box.temperatureZones
```

The v10 → v11 migration preserves every existing Box, Animal, FeedingEvent and
MediaAsset. When an assigned Animal has a legacy, non-empty temperature-zone
value and its Box has none, the first value by Animal ID is trimmed and copied
to the Box. Boxes without such a value remain `null`.

The former Animal column remains readable for database and backup compatibility;
current forms, details, repository writes and duplication treat the Box value
as authoritative. Keeping the released v10 snapshot unchanged ensures that an
installation upgraded from v1.7.0 executes this explicit migration step.

### Schema Version 12

Schema Version 12 adds `AnimalPictureAssociations` and
`BoxPictureAssociations`. The v11 → v12 migration creates one association at
sort order `0` for every existing non-null `pictureMediaId` and copies the
MediaAsset creation timestamp into `capturedAt`. Existing owner records,
primary references, picture bytes, lifecycle data, FeedingEvents and settings
remain unchanged.

### Schema Version 13

Schema Version 13 adds the nullable `Animal.nighttimeTemperature` column. The
v12 → v13 migration only adds this optional real-number field, so every
existing Animal keeps all profile, lifecycle, gallery and feeding data and
begins with no nighttime value. New and edited values use the same inclusive
0–60 °C bounds as daytime temperatures. `tempMin` must still not exceed
`tempMax`; the optional nighttime value is validated independently.

### Schema Version 14

Schema Version 14 adds two nullable Animal columns and one history table:

```text
Animal.nighttimeTemperatureMin
Animal.nighttimeTemperatureMax
AnimalWeightEntries
```

The v13 → v14 migration copies every existing non-null
`Animal.nighttimeTemperature` value to both new bounds. It retains the legacy
column for older database and backup compatibility. Current forms write the new
independent bounds, each using the inclusive 0–60 °C limit; a populated minimum
must not exceed a populated maximum.

The migration converts a legacy `Animal.weight` only when it is an unambiguous,
positive gram value such as `140 g`. It inserts one measurement using the
Animal's `updatedAt` timestamp and then clears the migrated text. Ambiguous text
remains untouched and visible until the user replaces it with a numeric gram
value. All Box, Animal, FeedingEvent, lifecycle, taxonomy and gallery data is
preserved.

### Schema Version 15

Schema Version 15 adds the `SheddingEvents` history table.

```text
SheddingEvents
├── id
├── animalId
├── shedAt
├── notes
├── createdAt
└── updatedAt
```

During the v14 → v15 migration, every non-empty legacy
`Animal.sheddingNotes` value creates one `SheddingEvent`. Because the legacy
field contains no historical timestamp, the Animal's existing `updatedAt`
timestamp is used for `shedAt`, `createdAt` and `updatedAt`.

Whitespace-only legacy values create no event. After migration,
`Animal.sheddingNotes` is cleared. The legacy database column remains present
for compatibility with older databases and backups.

All existing Animal, Box, feeding, weight, gallery, taxonomy and lifecycle data
is preserved.