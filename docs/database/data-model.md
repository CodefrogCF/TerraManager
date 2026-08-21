# Data Model

TerraManager uses a relational database implemented with Drift.

The current database model consists of boxes, animals and feeding events.
Sensors are part of the planned data model but are not implemented yet.

## Entity Relationships

```text
Box
 │
 ├──── 1:n ──── Animal
 │                 │
 │                 └──── 1:n ──── FeedingEvent
 │
 └──── 1:n ──── Sensor (planned)
 ```

## Box

A Box represents a terrarium or enclosure managed by TerraManager.

```text
Box
├── id
├── qrId
├── createdAt
└── updatedAt
```

### Fields

- id – auto-incrementing primary key
- qrId – unique QR identifier assigned to the box
- createdAt – creation timestamp
- updatedAt – last update timestamp

Each box can contain multiple animals.

## Animal

An Animal represents an individual animal assigned to a box.

```text
Animal
├── id
├── boxId
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
├── createdAt
└── updatedAt
```

### Fields

- id – auto-incrementing primary key
- boxId – foreign key referencing Box
- commonName – common name of the animal
- latinName – scientific/Latin name
- sex – optional sex value
- birthDate – optional date of birth
- birthDateAccuracy – optional indication of how accurately the birth date is known
- tempMin – preferred minimum temperature
- tempMax – preferred maximum temperature
- humidityMin – preferred minimum humidity
- humidityMax – preferred maximum humidity
- picturePath – optional path to the animal's picture
- notes – optional notes
- createdAt – creation timestamp
- updatedAt – last update timestamp

An animal belongs to exactly one box.

## FeedingEvent

A FeedingEvent represents a feeding performed for an individual animal.

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

The most recent feeding event can be queried through the animal repository.

## Sensor

Sensors are part of the planned data model but are not currently implemented.

The planned relationship is:

```text
Box
└──── 1:n ──── Sensor
```

The exact sensor fields and sensor types will be defined when sensor functionality is implemented.

## Type Converters

Some database fields use Drift type converters to map database values to Dart types.

Currently implemented converters include:

- SexConverter
- BirthDateAccuracyConverter

These allow enum-like Dart values to be stored as text in the database.

## Database Implementation

The database is implemented using Drift.

The main database entities are defined in:

```text
lib/core/database/tables/
├── boxes.dart
├── animals.dart
└── feeding_events.dart
```

Generated Drift code is located in:

```text
lib/core/database/app_database.g.dart
```

The generated file must not be edited manually. It is regenerated from the Drift table definitions.

## Repositories

Database access is separated from the rest of the application through repositories.

Currently implemented repositories:

```text
lib/core/database/repositories/
├── animal_repository.dart
├── box_repository.dart
└── feeding_repository.dart
```

Repositories provide application-level operations such as:

- retrieving animals
- retrieving boxes
- retrieving animals belonging to a box
- retrieving the latest feeding of an animal
- retrieving feeding history