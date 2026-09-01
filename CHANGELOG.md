# Changelog

All notable changes to TerraManager are documented in this file.

The project uses semantic versioning while development remains below version 1.0.

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