# Data Model

TerraManager uses a relational database implemented with Drift and SQLite.

The current database model consists of:

- boxes
- animals
- feeding events

Sensors are planned but are not implemented.

## Entity Relationships

```text
Box
 │
 └──── 1:n ──── Active Animal
                   │
                   └──── 1:n ──── FeedingEvent

Archived Animal
 │
 ├── boxId = null
 └──── 1:n ──── FeedingEvent
```

An animal remains the owner of its feeding history while archived.

Planned:

```text
Box
 │
 └──── 1:n ──── Sensor
```

## Box

A Box represents a terrarium, enclosure or physical container managed by TerraManager.

```text
Box
├── id
├── qrId
├── createdAt
└── updatedAt
```

### Fields

- id – auto-incrementing primary key
- qrId – unique permanent QR identifier
- createdAt – creation timestamp
- updatedAt – last modification timestamp

The QR identifier uses the following format:

```text
TM:BOX:<UUID-v4>
```

A box can contain multiple animals.

The QR identifier does not contain animal or box data. It only identifies the corresponding database record.

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
├── notes
├── archiveReason
├── archivedAt
├── archiveNotes
├── createdAt
└── updatedAt
```

### Fields

- id – auto-incrementing primary key
- boxId – foreign key referencing Box
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
- picturePath – optional picture reference/path
- notes – optional notes
- archiveReason – optional archive reason
- archivedAt – optional archive date
- archiveNotes – optional archive notes
- createdAt – creation timestamp
- updatedAt – modification timestamp

### Lifecycle

Active animals:

```text
status = active
boxId = assigned box
archiveReason = null
archivedAt = null
archiveNotes = null
```

Archived animals:

```text
status = archived
boxId = null
archiveReason = archive reason
archivedAt = archive date
archiveNotes = optional
```

Archiving an animal does not remove its animal record or feeding history.

Restoring an archived animal requires assigning a box again.

Permanent deletion is intentionally a separate operation and explicitly removes
associated feeding events before removing the animal.

Lifecycle consistency is enforced by the repository/application layer.

Nullable animal fields can be explicitly cleared when an animal is edited.

## FeedingEvent

A FeedingEvent represents a feeding performed for an animal.

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

Each animal can have multiple feeding events.

Feeding events are ordered by **fedAt**.

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

Sensor fields and supported sensor types will be defined when sensor functionality is designed.

## Type Converters

Some Dart values are mapped to SQLite-compatible text values using Drift converters.

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
└── feeding_events.dart
```

The main database is defined in:

```text
lib/core/database/app_database.dart
```

Generated Drift code is located in:

```text
lib/core/database/app_database.g.dart
```

Generated code must not be edited manually.

## Repositories

Database access is separated through repositories:

```text
lib/core/database/repositories/
├── animal_repository.dart
├── box_repository.dart
└── feeding_repository.dart
```

Examples of repository responsibilities:

```text
BoxRepository
├── create box
├── retrieve boxes
├── resolve qrId
├── update box
└── delete box

AnimalRepository
├── create animal
├── retrieve active animals
├── retrieve archived animals
├── retrieve active animals for box
├── update active animal
├── archive animal
├── restore animal
└── permanently delete archived animal

FeedingRepository
├── create feeding event
├── retrieve feeding history
├── retrieve latest feeding
├── update feeding event
└── delete feeding event
```

## Platform Persistence

### Android

Drift uses native SQLite storage.

### Web

Drift uses SQLite WASM and a Web worker.

Required assets:

```text
web/sqlite3.wasm
web/drift_worker.dart.js
```

Web persistence has been validated across normal browser reloads.

## Schema Version

The current Drift database schema version is **2**.

Schema version 2 introduced animal lifecycle support and changed `boxId` from
required to nullable.

The v1 → v2 migration preserves existing animals, box assignments and feeding
history. Existing animals are migrated with `status = active`.