# TerraManager Roadmap

## Current Status

Current development milestone:

**v0.10.0 – Localization**

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
- portable backup and restore
- persistent MediaAsset storage
- cross-platform Android/Web backup transfer
- Box editing, dimensions and persistent pictures
- human-readable Box labels
- overview thumbnails
- FeedingEvent editing and deletion
- preserved Animal and Box overview scroll positions
- Backup Format Version 2 with Box media
- backward-compatible Backup Format Version 1 restore
- contextual Animal detail navigation for Active Animals, Animal History and
  Box-specific Animal collections
- contextual Box detail navigation following the Box Overview ordering
- full-screen Box and Animal picture viewing with zooming and panning
- dedicated QR Feeding Mode for active Animals assigned to a scanned Box
- atomic single- and multi-Animal quick feeding entries
- immediate scanner restart after a Feeding Mode result
- Flutter localization generation based on ARB resources
- complete English and German application interfaces
- persistent System, English and German language selection
- immediate language changes without an application restart
- language-setting backup and restore with legacy-backup compatibility

v0.7.1 implementation and release validation are complete.

v0.8.0 implementation, documentation, Android/Web regression validation and
release are complete.

v0.9.0 implementation, documentation, Android/Web regression validation and
release are complete.

v0.10.0 implementation and documentation are complete. Final release validation
is in progress.

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

- [x] Define versioned `.tmbackup` format
- [x] Separate backup format version from database schema version
- [x] Document backup compatibility rules
- [x] Store portable media references
- [x] Exclude generated QR images

### Backup

- [x] Export Boxes
- [x] Export Animals
- [x] Export FeedingEvents
- [x] Export animal pictures
- [x] Export appearance settings
- [x] Generate portable backup archive

### Restore

- [x] Validate backup before modifying data
- [x] Validate format compatibility
- [x] Validate record relationships
- [x] Validate referenced media
- [x] Create pre-restore safety backup
- [x] Require destructive restore confirmation
- [x] Restore domain data
- [x] Restore media
- [x] Restore appearance settings

### Platform Support

- [x] Validate backup on Android
- [x] Validate restore on Android
- [x] Validate backup on Web
- [x] Validate restore on Web
- [x] Validate Android → Web restore
- [x] Validate Web → Android restore

### Release

- [x] Regression tests
- [x] Update documentation
- [x] Update changelog
- [x] Release v0.6.0

---

## v0.7.0 – Editing & Overview

### Boxes

- [x] Add optional width
- [x] Add optional height
- [x] Add optional depth
- [x] Add optional Box picture
- [x] Add Box editing
- [x] Keep QR identifier immutable
- [x] Show human-readable Box labels

### Feeding

- [x] Edit FeedingEvents
- [x] Delete FeedingEvents
- [x] Recalculate Latest Feeding after changes

### Overview

- [x] Show Animal thumbnails where available
- [x] Show Box thumbnails where available
- [x] Preserve Animal Overview scroll position after detail navigation

### Release

- [x] Database migration tests
- [x] Regression tests
- [x] Validate backup compatibility
- [x] Update documentation
- [x] Update changelog
- [x] Release v0.7.0

---

## v0.7.1 – Maintenance

### Overview

- [x] Preserve Box Overview scroll position after detail navigation
- [x] Add regression coverage for Box Overview scroll restoration

### Release

- [x] Refresh documentation for the v0.7.x state
- [x] Release v0.7.1

---

## v0.8.0 – Contextual Navigation

### Detail Navigation

- [x] Add contextual detail navigation model
- [x] Swipe between Animals
- [x] Preserve Active Animal context
- [x] Preserve archived Animal context
- [x] Preserve Box-specific Animal context
- [x] Swipe between Boxes
- [x] Preserve Box Overview ordering
- [x] Keep normal non-swipe detail navigation available
- [x] Handle first and last record boundaries
- [x] Keep detail actions bound to the currently displayed record

### Release

- [x] Automated regression tests
- [x] Update documentation
- [x] Update changelog
- [x] Validate contextual navigation on Android
- [x] Validate contextual navigation on Web
- [x] Release v0.8.0

---

## v0.9.0 – Feeding Workflow & Media

### Media

- [x] Open Box detail pictures in a full-screen viewer
- [x] Open Animal detail pictures in a full-screen viewer
- [x] Support picture zooming and panning
- [x] Preserve detail swipe navigation outside the picture viewer

### Feeding Mode

- [x] Add a dedicated QR Feeding Mode entry point
- [x] Resolve a scanned Box to its currently assigned active Animals
- [x] Handle Boxes without assigned Animals
- [x] Select one or multiple Animals for a feeding
- [x] Create one FeedingEvent for every selected Animal
- [x] Write grouped feeding entries atomically
- [x] Prevent duplicate feeding submissions
- [x] Show new entries in the existing feeding history
- [x] Return to scanning after a successful feeding entry
- [x] Preserve the existing normal Box scanner workflow

### Release

- [x] Regression tests
- [x] Validate picture viewing on Android
- [x] Validate QR Feeding Mode on Android
- [x] Complete final Android and Web release validation
- [x] Update documentation and changelog
- [x] Release v0.9.0

---

## v0.10.0 – Localization

### Localization Infrastructure

- [x] Configure Flutter localization generation
- [x] Move user-visible strings into localization resources
- [x] Use English as the fallback language
- [x] Allow tests to select a fixed locale

### Language Support

- [x] Add complete German translations
- [x] Follow the system language by default
- [x] Add System, English and German language settings
- [x] Apply language changes without restarting
- [x] Persist the selected language
- [x] Include the selected language in backup and restore

### Release

- [ ] Regression tests
- [x] Validate English and German on Android
- [ ] Validate English and German on Web
- [ ] Build the v0.10.0 Android release APK
- [ ] Build the v0.10.0 Web release
- [x] Update documentation and changelog
- [ ] Release v0.10.0

---

## Stretch Goals

These features are intentionally deferred and are not blockers for the active
release sequence.

### Animal Box Assignment History

- [ ] Add `AnimalBoxAssignment` data model
- [ ] Add database migration
- [ ] Record assignment when an Animal is created
- [ ] Record Box changes
- [ ] Close the assignment when an Animal is archived
- [ ] Create an assignment when an Animal is restored
- [ ] Remove assignment history after permanent Animal deletion
- [ ] Add Box-specific Animal History view

### Additional Platform Validation

- [ ] Validate iOS build and application startup
- [ ] Validate database and media persistence on iOS
- [ ] Validate QR storage, scanning and printing on iOS

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
