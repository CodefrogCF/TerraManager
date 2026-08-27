# TerraManager

TerraManager is a cross-platform application for managing terrarium boxes and their inhabitants.

The application is being developed with Flutter and is intended to initially support Android and Web, with potential iOS support at a later stage.

## Project Status

Current status:
Database foundation complete
Repository layer complete
Initial theme complete
UI development started

The basic database structure is implemented using Drift and SQLite.

The current test suite passes successfully.

Implemented so far:

- Flutter project setup
- Git/GitHub workflow
- Project documentation and ADRs
- Drift/SQLite database
- Box management data model
- Animal data model
- Box → Animal 1:n relationship
- Sex enum and database converter
- Birth date and birth date accuracy
- Feeding event history
- Animal repository
- Latest feeding lookup
- Database and repository tests

- Light and Dark application themes
- Initial application navigation
- Box overview
- Box detail screen
- Animal overview
- Animal detail screen
- Animal editing

- New Box workflow
- New Animal workflow

- Feeding history
- Animal notes/picture support

The UI and QR-code functionality are not fully implemented yet.

## Concept

The core concept is based on physical terrarium boxes identified by permanent QR codes.

Each box receives a unique QR ID.

The QR code itself does not contain the animal data. It only identifies the corresponding box.

Example:

```text
Physical box
    │
    │ QR code
    ▼
   qrId
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

A user can scan the QR code attached to a box with their smartphone camera.

The application then loads the corresponding box and its inhabitants.

## Planned Features

### Box management

- Create a new box

- Generate a unique QR ID

- Generate a printable QR code

- Save the QR code as an image

- Scan an existing QR code

- Load the associated box

- View and edit box-related data


### Animal management

Each animal belongs to exactly one box.

Animal data currently includes:

- Common name

- Latin name

- Sex

- Birth date

- Birth date accuracy

- Preferred minimum temperature

- Preferred maximum temperature

- Preferred minimum humidity

- Preferred maximum humidity

- Optional picture

- Notes

- Creation timestamp

- Modification timestamp

The preferred temperature and humidity values belong to the animal, not the box.

This allows multiple animals in the same box to have different preferred environmental parameters.

### Feeding

Feeding events are stored separately from the animal.

Each feeding event contains:

- Animal

- Feeding timestamp

- Optional notes


This allows a complete feeding history to be retained instead of storing only the last feeding date.

The latest feeding can be derived from the feeding event history.

## Data Model

The current database structure is:

```text
Boxes
  │
  │ 1:n
  ▼
Animals
  │
  │ 1:n
  ▼
FeedingEvents
```

### Boxes

```text
Boxes
├── id
├── qrId
├── createdAt
└── updatedAt
```

qrId is unique and permanently identifies the box.

### Animals

```text
Animals
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

### FeedingEvents

```text
FeedingEvents
├── id
├── animalId
├── fedAt
└── notes
```

## Technology Stack

### Application

- Flutter

- Dart


### Database

- Drift

- SQLite


### Development

- Visual Studio Code

- Android Studio

- Git

- GitHub


The project is currently developed on Windows 11.

## Architecture

The project aims to keep the application layers separated.

The intended basic structure is:

```text
App
│
▼
AppShell
│
├── Boxes
├── Animals
├── Settings
└── ...
     │
     ▼
  Repository
     │
     ▼
   Drift
     │
     ▼
   SQLite
```

The UI should not directly depend on database implementation details.

Repositories provide the application-facing API for accessing and modifying data.

## Project Structure

The current project structure is based around the following organization:

```text
lib/
├── main.dart
└── core/
    ├── theme/
    │   └── app_theme.dart
    └── database/
        ├── app_database.dart
        ├── app_database.g.dart
        ├── converters/
        │   ├── birth_date_accuracy_converter.dart
        │   └── sex_converter.dart
        ├── enums/
        │   ├── birth_date_accuracy.dart
        │   └── sex.dart
        ├── tables/
        │   ├── boxes.dart
        │   ├── animals.dart
        │   └── feeding_events.dart
        └── repositories/
            ├── animal_repository.dart
            ├── box_repository.dart
            └── feeding_repository.dart

test/
└── database/
    ├── app_database_test.dart
    ├── animal_repository_test.dart
    ├── box_repository_test.dart
    └── feeding_repository_test.dart
```

Generated Drift files such as app_database.g.dart must not be edited manually.

## Enums and Type Converters

Some Dart types are represented as strings in SQLite.

For example:

```text
Sex
 │
 ▼
SexConverter
 │
 ▼
TEXT
```

The same approach is used for:

```text
BirthDateAccuracy
```

This keeps the Dart application type-safe while using simple SQLite-compatible values.

## Birth Date Accuracy

The exact birth date of an acquired animal is often unknown.

Therefore, the application stores both:

```text
birthDate
birthDateAccuracy
```

This allows the application to distinguish between an exact and an approximate/uncertain birth date.

## QR Code Concept

QR codes are permanently associated with boxes.

The intended workflow is:

```text
Create Box
    │
    ▼
Generate unique qrId
    │
    ▼
Generate QR code
    │
    ▼
Save as PNG/JPG
    │
    ▼
Print
    │
    ▼
Attach to physical box
```

Scanning:

```text
Camera
   │
   ▼
QR code
   │
   ▼
qrId
   │
   ▼
Box
   │
   ▼
Animals
```

The QR code is therefore an identifier, not a storage medium for the actual application data.

## Development Workflow

Development is tracked using Git and GitHub.

The project uses:

- Git commits

- GitHub Issues

- Architecture Decision Records (ADRs)

- Automated tests


Changes should preferably be implemented in small, logically separated steps.

Typical workflow:

```text
Issue
  ↓
Implementation
  ↓
Test
  ↓
flutter test
  ↓
Commit
  ↓
Push
  ↓
Close Issue
```

## Testing

Run all tests with:

```text
flutter test
```

The current database and repository test suite passes successfully.

## Code Generation

Drift generates database-related code.

After changing a table, converter, or other Drift-related definition, regenerate the code.

The generated file is:

```text
lib/core/database/app_database.g.dart
```

Do not edit this file manually.

## Current Roadmap

The Roadmap is documented separately as Roadmap.

See:

```text
docs/roadmap.md
```

Roadmap should be updated whenever a step in the development process is completed.

## Architecture Decisions

Important architectural decisions are documented separately as Architecture Decision Records.

See:

```text
docs/architecture/
```

ADRs should be added whenever a significant architectural decision is made.

## Development Environment

Current development environment:

- Windows 11

- Flutter stable

- Dart

- Android Studio

- Visual Studio Code

- Android Emulator

- Git

- GitHub
