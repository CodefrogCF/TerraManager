# TerraManager Roadmap

## Current Status

Current development milestone:

**v0.5.0 – Usability & Settings**

Completed development areas:

- database foundation
- repository layer
- application navigation
- box and animal workflows
- feeding history
- notes and animal pictures
- QR generation, export, storage, printing and scanning
- Android validation
- Web validation
- safe box management
- animal lifecycle and archive
- Animal History
- latest feeding on animal details
- persistent appearance settings

v0.5.0 has completed implementation and validation.

---

## v0.1.0 – Foundation

### Database

- [x] Define box data model
- [x] Define animal data model
- [x] Define Box → Animal relationship
- [x] Add Sex enum
- [x] Add Sex converter
- [x] Add birth date
- [x] Add birth date accuracy
- [x] Add BirthDateAccuracy converter
- [x] Define feeding events
- [x] Implement latest feeding lookup
- [x] Add database tests
- [x] Add repository tests
- [x] Complete initial repository layer

---

## v0.2.0 – User Interface

- [x] Basic application navigation
- [x] Box overview
- [x] Box detail screen
- [x] Animal overview
- [x] Animal detail screen
- [x] Animal editing
- [x] New box workflow
- [x] New animal workflow
- [x] Feeding history
- [x] Notes
- [x] Animal picture support

---

## v0.3.0 – QR Code

- [x] Generate unique QR IDs
- [x] Generate QR codes
- [x] Export QR codes as PNG
- [x] Save QR code locally
- [x] Print QR codes
- [x] Implement QR scanner
- [x] Validate TerraManager QR IDs
- [x] Handle invalid QR codes
- [x] Handle unknown box QR codes

---

## v0.4.0 – Platform Support

### Android

- [x] Android debug build
- [x] Android release build
- [x] Application startup
- [x] Core navigation
- [x] Database persistence
- [x] Animal picture support
- [x] Local QR image storage
- [x] Camera permissions
- [x] QR scanning
- [x] QR printing
- [x] Relevant tests

### Web

- [x] Web build
- [x] Application startup
- [x] Core navigation
- [x] Drift Web database
- [x] Persistent data after browser reload
- [x] Animal picture support
- [x] QR image download
- [x] Camera permissions
- [x] QR scanning
- [x] QR printing
- [x] Known Web limitations documented
- [x] Relevant tests

### iOS

- [ ] Validate iOS build
- [ ] Validate application startup
- [ ] Validate database persistence
- [ ] Validate animal pictures
- [ ] Validate QR storage
- [ ] Validate camera permissions
- [ ] Validate QR scanning
- [ ] Validate printing

iOS validation is currently deferred because no macOS development environment or physical iOS test device is available.

---

## v0.5.0 – Usability & Settings

### Box Detail Improvements

- [x] Show animals assigned to the box
- [x] Show empty state when no animals are assigned
- [x] Open animal detail from assigned animal list
- [x] Add box deletion action
- [x] Require confirmation before deletion
- [x] Prevent accidental deletion of boxes containing animals
- [x] Refresh box overview after deletion

### Animal Lifecycle

- [x] Add animal lifecycle status
- [x] Add archive reasons and archive metadata
- [x] Add database migration for lifecycle support
- [x] Archive animals
- [x] Restore archived animals
- [x] Remove archived animals from active boxes
- [x] Add Animal History view
- [x] Display archive information
- [x] Support explicit permanent deletion of archived animals
- [x] Preserve feeding history while archived

### Animal Detail Improvements

- [x] Show latest feeding on animal detail page
- [x] Show date and time of latest feeding
- [x] Show suitable empty state when no feeding exists
- [x] Refresh latest feeding after feeding history changes

### Settings

- [x] Implement appearance settings
- [x] System theme mode
- [x] Light theme mode
- [x] Dark theme mode
- [x] Selectable accent colors
- [x] Apply theme changes immediately
- [x] Persist settings
- [x] Validate settings on Android
- [x] Validate settings on Web

### Release

- [x] Regression test Android
- [x] Regression test Web
- [x] Update documentation
- [x] Update changelog
- [x] Tag and publish v0.5.0

---

## v0.6.0 – Backup & Restore

### Backup Format

- [ ] Define versioned `.tmbackup` format
- [ ] Separate backup format version from database schema version
- [ ] Document backup compatibility rules
- [ ] Store portable media references
- [ ] Exclude generated QR images

### Backup

- [ ] Export Boxes
- [ ] Export Animals
- [ ] Export FeedingEvents
- [ ] Export animal pictures
- [ ] Export appearance settings
- [ ] Generate portable backup archive

### Restore

- [ ] Validate backup before modifying data
- [ ] Validate format compatibility
- [ ] Validate record relationships
- [ ] Validate referenced media
- [ ] Create pre-restore safety backup
- [ ] Require destructive restore confirmation
- [ ] Restore domain data
- [ ] Restore media
- [ ] Restore appearance settings

### Platform Support

- [ ] Validate backup on Android
- [ ] Validate restore on Android
- [ ] Validate backup on Web
- [ ] Validate restore on Web
- [ ] Validate Android → Web restore
- [ ] Validate Web → Android restore

### Release

- [ ] Regression tests
- [ ] Update documentation
- [ ] Update changelog
- [ ] Release v0.6.0

---

## v0.7.0 – Editing & Overview

### Boxes

- [ ] Add optional width
- [ ] Add optional height
- [ ] Add optional depth
- [ ] Add optional Box picture
- [ ] Add Box editing
- [ ] Keep QR identifier immutable
- [ ] Show human-readable Box labels

### Feeding

- [ ] Edit FeedingEvents
- [ ] Delete FeedingEvents
- [ ] Recalculate Latest Feeding after changes

### Overview

- [ ] Show Animal thumbnails where available
- [ ] Show Box thumbnails where available
- [ ] Preserve Animal Overview scroll position after detail navigation

### Release

- [ ] Database migration tests
- [ ] Regression tests
- [ ] Validate backup compatibility
- [ ] Update documentation
- [ ] Update changelog
- [ ] Release v0.7.0

---

## v0.8.0 – Navigation & History

### Detail Navigation

- [ ] Add contextual detail navigation model
- [ ] Swipe between Animals
- [ ] Preserve Active Animal context
- [ ] Preserve archived Animal context
- [ ] Preserve Box-specific Animal context
- [ ] Swipe between Boxes

### Animal Box History

- [ ] Add AnimalBoxAssignment data model
- [ ] Add database migration
- [ ] Record assignment when Animal is created
- [ ] Record Box changes
- [ ] Close assignment when Animal is archived
- [ ] Create assignment when Animal is restored
- [ ] Handle permanent deletion
- [ ] Add Box-specific Animal History view (stretch)

### Release

- [ ] Regression tests
- [ ] Validate backup/restore of history data
- [ ] Update documentation
- [ ] Update changelog
- [ ] Release v0.8.0

---

## Future Development

Possible later development areas include:

- sensors
- automatic temperature and humidity tracking
- smart-home integration
- automatic backups
- scheduled backups
- cloud synchronization
- user accounts
- multi-device synchronization
- animal weight history
- shedding history
- health and event tracking
- breeding records
- enclosure maintenance history
- iOS validation