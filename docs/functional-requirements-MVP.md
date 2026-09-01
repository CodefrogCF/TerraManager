# Functional Requirements – MVP

This document defines the functionality intended for the TerraManager MVP.

Implementation progress is tracked separately in `roadmap.md`.

## Boxes

The application must allow the user to:

- create a new box
- automatically assign a permanent unique QR identifier
- view the box overview
- view box details
- view animals assigned to a box
- open an assigned animal from the box detail screen
- delete an empty box
- require confirmation before deleting a box
- prevent accidental deletion of a box containing animals
- identify a box by QR code

## Animals

The application must allow the user to:

- create an animal
- assign an animal to a box
- view the animal overview
- view animal details
- edit animal data
- change the associated box
- add or remove an animal picture
- add and edit notes
- store preferred temperature values
- store preferred humidity values
- store optional birth information
- store optional sex information
- archive an animal without losing its data
- select an archive reason and archive date
- store an optional archive note
- remove archived animals from active box assignments
- view archived animals in Animal History
- open archived animal details
- restore an archived animal to a selected box
- preserve feeding history while an animal is archived
- permanently delete an archived animal through an explicit confirmation workflow

Active animals must have a box assignment.

Archived animals must not have an active box assignment.

## Feeding

The application must allow the user to:

- add a feeding event
- store an optional feeding note
- view complete feeding history
- determine the latest feeding
- display the latest feeding directly on the animal detail screen

The latest feeding must be derived from feeding history rather than duplicated in the Animal record.

The animal detail screen must display the most recent FeedingEvent, including
its timestamp and optional note.

The displayed value must refresh after the feeding history is modified.

## QR Codes

The application must allow the user to:

- generate a unique QR ID for a box
- generate a QR code from the box ID
- display the QR code
- export the QR code as PNG
- save/download the QR image
- print the QR code
- scan a QR code
- validate TerraManager QR identifiers
- resolve a scanned QR identifier to a box
- report invalid QR codes
- report valid but unknown TerraManager QR identifiers

The QR code must contain only the stable box identifier.

## Settings

The application must allow the user to:

- use the operating system theme
- explicitly select Light mode
- explicitly select Dark mode
- select an application accent color
- persist appearance settings between application restarts

## Persistence

Core application data must be stored locally.

Data must survive normal application restarts.

The MVP does not require cloud synchronization.

Core domain data is stored with Drift/SQLite.

Appearance preferences are stored separately through `shared_preferences`.

Both domain data and appearance preferences must survive normal application
restarts or browser reloads on validated platforms.

## Platform Targets

The MVP targets:

- Android
- Web

iOS is planned but is not required to be validated before the current MVP milestones can continue.