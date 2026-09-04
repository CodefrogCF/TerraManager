# Changelog

All notable changes to TerraManager are documented in this file.

The project uses semantic versioning while development remains below version 1.0.

## [0.8.0] - Contextual Navigation

### Added

- reusable `DetailNavigationContext` for ordered Animal and Box collections
- navigation sources for Active Animals, Animal History, Box-specific Animals and Box Overview
- horizontal swipe navigation between contextual Animal detail records
- horizontal swipe navigation between contextual Box detail records
- first and last record navigation boundaries

### Changed

- Animal detail actions continue to target the currently displayed Animal after swiping
- Box edit, delete and QR actions continue to target the currently displayed Box after swiping
- Animal detail navigation is disabled if an edited Animal leaves its original source collection
- missing adjacent Boxes are removed safely from the in-memory navigation context
- normal detail navigation without swipe context remains supported

### Compatibility

- database schema remains at Version 4
- portable backup exports remain at Backup Format Version 2
- no data or backup migration is required for v0.8.0

### Validated

- contextual Animal navigation on Android and Web
- contextual Box navigation on Android and Web
- Active Animal, Animal History and Box-specific Animal source ordering
- first and last record boundaries
- edit, delete and QR actions after contextual navigation
- Back navigation to the originating overview
- normal detail navigation without a swipe context

### Testing

- added contextual navigation model tests
- added Active Animal, Animal History and Box-specific Animal swipe tests
- added Box Overview swipe tests
- added boundary, edit, deletion, QR action and missing-record regression coverage
- completed the full automated test suite with 299 passing tests

## [0.7.1] - Maintenance

### Fixed

- preserve Box Overview scroll position after returning from Box details
- preserve Box Overview scroll position after returning from Box scanner and successful Box creation refreshes

## [0.7.0] - Editing & Overview

### Added

- optional Box width, height and depth
- persistent Box pictures backed by `MediaAssets`
- Box editing workflow
- human-readable Box labels (`Box N`) while preserving permanent QR identifiers
- Animal and Box thumbnails in overview lists
- FeedingEvent editing
- FeedingEvent deletion with confirmation
- Backup Format Version 2
- portable Box dimensions and Box pictures in backups
- `media/boxes/` archive media support

### Changed

- Box QR identifiers remain immutable when Box metadata is edited
- Latest Feeding is recalculated after FeedingEvent edits and deletions
- Animal Overview preserves its scroll position after detail/history navigation
- archived-Animal restore dialogs use human-readable Box labels
- safety backups include Box dimensions and Box pictures
- current backups are created as Backup Format Version 2
- restore continues to accept Backup Format Version 1

### Data Migration

- database schema upgraded from version 3 to version 4
- added nullable `Box.widthCm`
- added nullable `Box.heightCm`
- added nullable `Box.depthCm`
- added nullable `Box.pictureMediaId` referencing `MediaAssets`
- existing Boxes, Animals, FeedingEvents and media remain preserved

### Backup Compatibility

- Backup Format Version 2 is the current export format
- Backup Format Version 1 remains supported for restore
- Version 1 Box records restore with dimensions and Box picture fields set to `null`
- Box and Animal pictures are restored as new local `MediaAssets`
- permanent Box QR identifiers remain unchanged
- generated QR images remain excluded from backups

### Validated

- Android regression validation
- Web regression validation
- Backup Format Version 2 export and restore
- Backup Format Version 1 restore compatibility
- Android → Web Version 2 restore
- Web → Android Version 2 restore
- Box and Animal picture backup/restore
- pre-restore safety backup with Box dimensions and pictures

### Testing

- added schema v3 → v4 migration tests
- added Box media lifecycle tests
- added Box edit workflow tests
- added overview thumbnail tests
- added FeedingEvent edit and delete tests
- added overview scroll-position regression tests
- added Backup Format Version 2 export, validation and restore tests
- completed full automated and manual regression validation

## [0.6.0] - Backup & Restore

### Added

- portable versioned `.tmbackup` backup format
- backup manifest with application version, backup format version and database schema version
- Box, Animal and FeedingEvent backup export
- appearance settings backup export
- Animal picture backup support
- backup archive validation before restore
- validation of record IDs and relationships
- lifecycle invariant validation
- QR identifier validation
- enum and settings validation
- media reference validation
- archive path traversal protection
- duplicate archive entry protection
- backup information and confirmation dialogs
- automatic pre-restore safety backup
- full replacement restore workflow
- persistent `MediaAssets` storage for Animal pictures
- `Animal.pictureMediaId` relationship
- legacy Animal picture migration
- Android and Web backup file selection
- user-selectable backup destination on Android

### Changed

- Animal pictures are now stored persistently in Drift/SQLite instead of relying on temporary `image_picker` paths
- restored Animal pictures are stored as `MediaAssets`
- restored Animals reference pictures through `pictureMediaId`
- portable backups no longer depend on local picture paths
- backup restore media handling is now part of the transactional database replacement
- Android backup saving now uses a user-selectable system file destination
- backup format version remains independent from database schema version

### Data Migration

- database schema upgraded from version 2 to version 3
- added `MediaAssets` table
- added nullable `Animal.pictureMediaId`
- existing Animal data is preserved
- existing `picturePath` values are preserved during schema migration
- readable legacy Animal pictures are migrated to persistent `MediaAssets` after startup
- unreadable legacy picture paths are retained without causing startup failure

### Backup Compatibility

- Backup Format Version 1 remains current
- backups created from database schema version 2 remain restorable
- generated QR images remain excluded from backups
- permanent Box QR identifiers are preserved unchanged
- internal `MediaAsset` IDs are not part of the portable backup format

### Validated

- Android backup
- Android restore
- Web backup
- Web restore
- Android → Web restore
- Web → Android restore
- persistent Animal pictures after Android application restart
- persistent Animal pictures after Web browser reload
- safety backup restore including Animal pictures

### Testing

- added backup format tests
- added backup export tests
- added backup validation tests
- added transactional restore tests
- added persistent media repository tests
- added database schema v2 → v3 migration tests
- added legacy picture migration tests
- added Settings backup and restore widget tests
- added cross-platform manual backup and restore validation
- completed full regression test suite

## [0.5.0] - Usability & Settings

### Added

- assigned animals on the box detail screen
- safe deletion workflow for empty boxes
- deletion protection for boxes containing active animals
- animal lifecycle with active and archived states
- archive reasons, dates and optional archive notes
- dedicated Animal History view
- restore workflow for archived animals
- permanent deletion of archived animals
- latest feeding information on animal details
- persistent System, Light and Dark appearance settings
- selectable application accent colors

### Changed

- animal overview now displays active animals only
- box details only display active assigned animals
- archived animals are no longer associated with an active box
- animal detail refreshes latest feeding information after returning from feeding history
- application theme is generated dynamically from the selected accent color
- UI appearance preferences are stored separately from domain data

### Data Migration

- database schema upgraded from version 1 to version 2
- existing animals are migrated as active
- existing box assignments are preserved
- existing feeding history is preserved

### Testing

- added Drift schema migration tests
- added migration data-integrity tests
- added animal lifecycle repository tests
- added animal lifecycle widget tests
- added Animal History tests
- added latest-feeding tests
- added persistent settings and theme tests
- completed Android regression validation
- completed Web regression validation

## [0.4.0] - Platform Support

### Added

- Android platform validation
- Web platform validation
- SQLite WASM database support for Web
- persistent Web database storage
- platform-aware QR image storage
- Android gallery storage for QR images

### Validated

- Android debug build
- Android release build
- Android database persistence
- Android image handling
- Android camera access
- Android QR scanning
- Android QR printing
- Web application build
- Web database persistence
- Web image handling
- Web camera access
- Web QR scanning
- Web QR download
- Web QR printing

### Known Limitations

- iOS has not yet been validated
- Web data can be removed when browser site data is cleared
- Web camera, download and printing behavior depends on browser capabilities

## [0.3.0] - QR Code

### Added

- automatic box QR ID generation
- UUID-based QR identifiers
- QR code display
- QR code PNG export
- local QR image storage
- QR printing
- QR scanning
- TerraManager QR validation
- unknown QR handling
- invalid QR handling

## [0.2.0] - User Interface

### Added

- application navigation
- box overview
- box detail screen
- animal overview
- animal detail screen
- animal editing
- new box workflow
- new animal workflow
- feeding history
- animal notes
- animal picture support

## [0.1.0] - Foundation

### Added

- Flutter project foundation
- Drift/SQLite database
- Box data model
- Animal data model
- FeedingEvent data model
- Box → Animal relationship
- Animal → FeedingEvent relationship
- Sex enum and converter
- birth date accuracy support
- repository layer
- database tests
- repository tests
- initial Material 3 theme
