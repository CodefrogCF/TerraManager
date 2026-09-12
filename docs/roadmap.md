# TerraManager Roadmap

## Current Status

Latest completed release milestone:

**v1.0.0 – MVP Release**

Current application version and build:

**v1.0.6+47**

Completed development areas:

- database foundation
- repository layer
- application navigation
- box and animal workflows
- feeding history
- notes and animal pictures
- QR generation, export, storage and scanning
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
- persistent Common-name-first or Latin-name-first Animal presentation
- camera-light controls in the Box and Feeding Mode scanners
- context-sensitive Box and Animal picture actions with Camera and Gallery
  source selection
- shared free-form picture cropping before new media is persisted
- bounded WebP normalization for every new and replaced Box and Animal picture
- atomic picture replacement with processing and duplicate-action protection
- mixed legacy and optimized picture backup export and restore
- optional per-Animal feeding reminder configuration with persistent interval
  and baseline
- reminder configuration backup and restore with legacy-backup compatibility
- deterministic feeding reminder calculation using the latest FeedingEvent
  when present and the baseline only without feeding history
- efficient aggregate lookup and recalculation after FeedingEvent changes
- non-modal, localized Feeding Reminder summary and due markers in the Animal
  Overview
- due and scheduled reminder status on Animal details
- reminder navigation and immediate refresh after normal and Quick Feeding
  changes
- localized Animal sex and birth-date-accuracy labels without raw enum text
- one explicit Unknown sex choice with a legacy-null display fallback
- direct Animal creation from empty and populated Box detail assignments
- originating Box preselection and immediate assignment-list refresh
- persistent localized Box Overview sorting by natural Box number
- backup-compatible Box ordering and matching contextual detail navigation
- persistent Animal Overview sorting by creation time, displayed name, age or
  latest FeedingEvent
- deterministic missing-value ordering, bulk FeedingEvent lookup and matching
  contextual Animal navigation
- GPL-3.0-or-later open-source licensing
- public privacy, permissions, installation, updates, support, security and
  contribution documentation
- explicit Quick Feeding cancellation through Scan a different Box
- reproducible CI formatting, analysis, test and supported build gates
- documented Flutter, Dart, Java, Gradle and locked-dependency baseline
- current Animal picture thumbnails in Box-detail assignment lists with a safe
  fallback
- Box details and assigned Animals presented before a consolidated QR section
  with the permanent identifier and PNG export action
- Box deletion available only as a destructive action at the bottom of Edit
  Box, with confirmation and assigned-Animal protection
- direct Latest Feeding navigation into the complete Animal feeding history
- dedicated Feeding Reminder settings action on active Animal details
- ordinary Animal edits preserve reminder configuration without exposing its
  controls

v0.7.1 implementation and release validation are complete.

v0.8.0 implementation, documentation, Android/Web regression validation and
release are complete.

v0.9.0 implementation, documentation, Android/Web regression validation and
release are complete.

v0.10.0 implementation, documentation, Android/Web regression validation and
release are complete.

v0.11.0 implementation, documentation, automated testing, Android/Web
regression validation and release packaging are complete.

v0.12.0 implementation, documentation, automated testing, Android/Web
regression validation and release packaging are complete.

v0.13.0 implementation, documentation, automated testing, Android/Web
regression validation and release packaging are complete. Issues #74, #75 and
#76 provide the persistent per-Animal configuration, deterministic calculation
and in-app presentation required for Feeding Reminders. Issue #77 completed the
publication of release build `0.13.0+27`.

v0.14.0 implementation, documentation, automated testing, supported builds and
manual regression validation are complete. Issues #78 and #79 provide
consistent Animal form labels and direct Animal creation from Box details.
Issues #80 and #81 add persistent, backup-compatible Box and Animal Overview
sorting with contextual detail navigation. Issue #82 completes release build
`0.14.0+32`.

v0.14.1 implementation, documentation, automated testing, supported builds and
manual regression validation are complete. The patch corrects the reminder
reference for existing feeding history and reduces Box sorting to the two
meaningful Box-number directions while preserving legacy settings and backups.

v1.0.0 implementation, documentation, automated testing, supported builds,
manual regression and publication are complete. It establishes the stable MVP
baseline without changing Database Schema Version 5 or Portable Backup Format
Version 2.

Issue #89 introduces the permanent `com.codefrog.terramanager` application
identity and replaces remaining Flutter placeholder platform metadata. Android
users of builds through v0.14.1 migrate through the existing portable backup
and restore workflow because Android treats the permanent identifier as a new
application.

Issue #90 introduces fail-closed Android production signing. Release builds
load credentials only from an ignored local file or explicit environment
variables, while Debug builds remain independent of release secrets. Creating,
backing up and validating the private production key remains a local release
owner task.

Issue #91 establishes GPL-3.0-or-later as the public project licence and adds
the privacy, permission, installation, update, support, security and
contribution information needed for a public release. Historical v0.11.0 and
v0.12.0 publication actions now reflect their completed release state.

Issue #92 adds pinned GitHub Actions quality gates and documents the supported
toolchain and dependency baseline. Android production signing stays outside CI,
and the remaining Built-in Kotlin warning is tracked as an upstream plugin
migration dependency rather than being hidden by unsafe configuration.

Issue #93 completed release `1.0.0+39` without expanding the MVP scope.
Database Schema Version 5 and Portable Backup Format Version 2 remain
unchanged after the final Android, Web, backup, localization, signing and
release-artifact regression.

v1.1.0 is now the active milestone for detail and workflow polish. Development
build `1.0.2+43` starts Issue #94 by displaying current Animal pictures in the
Box-detail assignment list while preserving the existing fallback and
navigation behaviour.

Development build `1.0.3+44` implements Issue #95 by moving the permanent QR
identifier and PNG export into a final Box-detail section and removing the
former single-code printing workflow without changing QR identity or scanning.

Development build `1.0.4+45` implements Issue #96 by adding optional multiline
Box notes, Database Schema Version 6 persistence and backward-compatible
Backup Format Version 2 export and restore.

Development build `1.0.5+46` implements Issue #97 by moving Box deletion from
the detail app bar to the bottom of Edit Box. Saved and deleted edit results
are handled separately so deletion closes the detail route and refreshes the
originating overview, including after contextual Box navigation.

Development build `1.0.6+47` implements the detail and workflow changes for
Issue #98. Latest Feeding is now an explicit history shortcut, and active
Animal details expose a dedicated Feeding Reminder settings action. The
ordinary Edit Animal workflow preserves existing reminder configuration while
the dedicated page owns reminder validation and persistence.

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

- [x] Regression tests
- [x] Validate English and German on Android
- [x] Validate English and German on Web
- [x] Build the v0.10.0 Android release APK
- [x] Build the v0.10.0 Web release
- [x] Update documentation and changelog
- [x] Release v0.10.0

---

## v0.11.0 – Personalization & Capture

### Preferred Animal Name

- [x] Add Common name first and Latin name first options
- [x] Persist the selected name order
- [x] Apply changes immediately without restarting
- [x] Use the selected order in Animal overview and history
- [x] Use the selected order in Animal details
- [x] Use the selected order for Animals assigned to a Box
- [x] Use the selected order in Quick Feeding Mode
- [x] Include the preference in backup export and restore
- [x] Keep legacy backups compatible
- [x] Validate the preference on Android
- [x] Validate the preference on Web

### Scanner Torch Controls

- [x] Add a torch control to the Box scanner
- [x] Add a torch control to the Feeding scanner
- [x] Handle cameras without torch support

### Direct Camera Capture

- [x] Add Camera and Gallery source selection for Animal pictures
- [x] Add Camera and Gallery source selection for Box pictures
- [x] Keep unsupported platforms and denied permissions recoverable

### Release

- [x] Complete automated regression tests
- [x] Complete Android and Web manual validation
- [x] Update final release documentation
- [x] Build the supported release artifacts
- [x] Release v0.11.0

---

## v0.12.0 – Media Optimization

### Picture Cropping

- [x] Add a shared free-form cropping screen
- [x] Crop Camera and Gallery pictures before applying them
- [x] Use the crop flow for new and edited Boxes
- [x] Use the crop flow for new and edited Animals
- [x] Keep the existing picture unchanged when cropping is cancelled
- [x] Normalize source orientation before cropping
- [x] Persist confirmed crops through the existing MediaAssets workflow
- [x] Validate cropped and legacy picture backup compatibility
- [x] Add focused cropping and form integration tests
- [x] Validate picture cropping on Android
- [x] Validate picture cropping on Web

### Image Storage Optimization

- [x] Define maximum stored image dimensions and quality
- [x] Convert new Box and Animal pictures to WebP
- [x] Use one normalization path for Camera and Gallery imports
- [x] Integrate normalization into new and edited Box and Animal forms
- [x] Show picture-processing progress and block duplicate actions
- [x] Replace referenced media atomically without corrupting the old picture
- [x] Keep legacy and normalized pictures compatible with all display sizes
- [x] Cover all four normalized picture workflows with automated tests
- [x] Define migration behavior for existing pictures
- [x] Measure portable backup size improvements on an existing data set
- [x] Verify backup export and restore for legacy and optimized pictures

For an existing data set with 44 Boxes, 45 Animals, 20 FeedingEvents and 67
pictures, normalization reduced the portable backup from approximately 140 MB
to 22.7 MB. That is about 117.3 MB or 83.8% smaller, reducing the archive to
roughly one sixth of its previous size.

### Release

- [x] Complete automated regression tests
- [x] Complete Android and Web manual validation
- [x] Update final release documentation
- [x] Build the supported release artifacts
- [x] Release v0.12.0

---

## v0.13.0 – Feeding Reminders

### Per-Animal Configuration — Issue #74

- [x] Store an optional reminder interval in whole days
- [x] Store the baseline captured when a reminder is enabled
- [x] Keep reminders disabled by default
- [x] Add localized controls to new and edited Animal forms
- [x] Require a positive interval while reminders are enabled
- [x] Retain configuration while an Animal is archived
- [x] Preserve configuration in current backups
- [x] Restore older backups with reminders disabled
- [x] Add repository, migration, form and backup tests

### Reminder Calculation — Issue #75

- [x] Calculate the due time from the latest feeding when present, otherwise
  from the baseline
- [x] Exclude archived Animals and disabled reminders
- [x] Recalculate after feeding creation, editing and deletion
- [x] Use an injectable clock and an efficient aggregate query
- [x] Add deterministic domain and repository tests

### In-App Reminder Presentation — Issue #76

- [x] Show a non-modal due summary in the Animal Overview
- [x] Mark due Animals and order them by most overdue first
- [x] Show due state and due date on Animal details
- [x] Open the corresponding Animal and feeding workflow from a reminder
- [x] Refresh immediately after feeding history changes
- [x] Localize reminder status text in English and German
- [x] Add empty, due and refreshed widget tests

### Release — Issue #77

- [x] Complete migration, backup and reminder regression tests
- [x] Validate reminder configuration and date boundaries manually
- [x] Validate feeding create, edit and delete refresh behavior
- [x] Validate archived Animal behavior
- [x] Review English and German reminder text
- [x] Update final documentation and release notes
- [x] Build and manually test supported release artifacts
- [x] Release v0.13.0

---

## v0.14.0 – Pre-1.0 UX Polish

### Animal Form Labels — Issue #78

- [x] Replace raw English Sex enum labels
- [x] Show exactly Male, Female and Unknown in the sex selector
- [x] Use Unknown as the default and legacy-null presentation
- [x] Replace raw English BirthDateAccuracy enum labels
- [x] Keep English and German labels consistent
- [x] Preserve existing database and backup values without migration
- [x] Add form, detail and localization regression tests
- [x] Validate the updated controls manually on Android

### Add Animal from Box Details — Issue #79

- [x] Show Add Animal below empty and populated assigned-Animal sections
- [x] Open New Animal with the originating Box preselected
- [x] Keep the preselected Box editable
- [x] Refresh Box details after saving and preserve normal navigation
- [x] Block repeated Add Animal actions while the route is open
- [x] Add localized widget regression coverage
- [x] Validate direct creation manually on Android

### Box Overview Sorting — Issue #80

- [x] Add created-date and natural Box-label sorting modes
- [x] Persist and back up the selected Box ordering
- [x] Keep contextual Box detail navigation aligned with the visible order
- [x] Add sorting, settings and backup regression tests
- [x] Validate all Box ordering modes manually on Android

### Animal Overview Sorting — Issue #81

- [x] Add created-date, displayed-name, age and latest-feeding sorting modes
- [x] Handle missing birth and FeedingEvent data deterministically
- [x] Load latest FeedingEvents efficiently in bulk
- [x] Persist and back up the selected Animal ordering
- [x] Keep contextual Animal detail navigation aligned with the visible order
- [x] Add sorting, settings and backup regression tests
- [x] Validate all Animal ordering modes manually on Android

### Release — Issue #82

- [x] Complete automated and manual regression testing
- [x] Review English and German presentation
- [x] Update documentation and release notes
- [x] Build the supported release artifacts
- [x] Release v0.14.0

---

## v0.14.1 – Post-release Fixes

### Feeding Reminder Reference

- [x] Use the latest FeedingEvent whenever feeding history exists
- [x] Use the reminder baseline only without FeedingEvents
- [x] Allow old feeding history to produce an immediately due reminder
- [x] Recalculate after FeedingEvent creation, editing and deletion
- [x] Fall back to the baseline after deleting the final FeedingEvent
- [x] Add deterministic regression coverage
- [x] Validate the corrected reminder behavior manually on Android

### Box Overview Sorting Simplification

- [x] Keep only ascending and descending Box-number sorting
- [x] Use ascending Box number as the default
- [x] Migrate stored oldest/newest-created preferences
- [x] Accept and map legacy Box sort values from backups
- [x] Write only current Box sort values to new backups
- [x] Keep contextual navigation aligned with the visible order
- [x] Update localization and automated regression coverage
- [x] Validate both Box ordering modes manually on Android

### Patch Release

- [x] Complete static analysis and automated regression testing
- [x] Build and manually test the supported release artifacts
- [x] Finalize v0.14.1 documentation and release notes
- [x] Release v0.14.1

---

## v1.0.0 – MVP Release

### Application Identity and Platform Metadata — Issue #89

- [x] Select `com.codefrog.terramanager` as the permanent application ID
- [x] Update the Android namespace, application ID and MainActivity package
- [x] Preserve TerraManager as the visible Android application name
- [x] Replace placeholder Web name, title, description and theme metadata
- [x] Replace default Flutter Web icons and favicon with TerraManager artwork
- [x] Remove remaining Flutter identity placeholders from prepared platforms
- [x] Document the backup-and-restore transition from pre-v1.0 Android builds
- [x] Add automated platform metadata regression coverage
- [x] Validate Android builds, installation and application identity
- [x] Validate the Web build and install metadata

### Android Production Signing — Issue #90

- [x] Add ignored local-file and environment-variable signing configuration
- [x] Reject Release builds that lack a complete production configuration
- [x] Keep Debug builds independent of release credentials
- [x] Create and securely back up the private production signing key
- [x] Build and verify production-signed APK and AAB artifacts
- [x] Document key backup, recovery and the previous-signature transition

### Public Release Documentation — Issue #91

- [x] Add the selected open-source license
- [x] Document privacy, permissions, installation, updates and support
- [x] Correct historical issue references
- [x] Complete the public v1.0 documentation review

### Feeding Mode Scanner Return — Pre-release Fix

- [x] Replace the ambiguous Scan another Box action
- [x] Label the action as Scan a different Box in English and German
- [x] Cancel the unsaved Box-specific feeding form without creating events
- [x] Return to Feeding Mode and restart the scanner
- [x] Add localization, cancellation and scanner-resume regression coverage
- [x] Validate the action manually on Android

### Quality Gates and Toolchain Baseline — Issue #92

- [x] Add reproducible CI formatting, analysis, test and build checks
- [x] Record the supported Flutter and dependency baseline
- [x] Review current Kotlin and Gradle compatibility warnings
- [x] Remove the remaining sort-menu widget-test hit-test warnings
- [x] Confirm the first GitHub Actions run after push

### Stable MVP Release — Issue #93

- [x] Complete Android and Web regression testing
- [x] Validate current and legacy backup migration paths
- [x] Build and verify final signed release artifacts
- [x] Finalize v1.0.0 documentation and release notes
- [x] Publish the v1.0.0 tag and GitHub release

---

## v1.1.0 – Detail & Workflow Polish

### Assigned Animal Thumbnails — Issue #94

- [x] Reuse the shared media thumbnail for assigned Animals
- [x] Display the current Animal picture when stored media is available
- [x] Preserve legacy picture-path support through the shared thumbnail
- [x] Keep a safe fallback for missing or invalid pictures
- [x] Preserve assigned-Animal names and detail navigation
- [x] Add focused Box-detail widget coverage
- [x] Complete automated and manual validation with 456 passing tests

### Box QR Information — Issue #95

- [x] Move the QR code and permanent textual identifier to the bottom of Box
  details
- [x] Place Box information and assigned Animals before the QR section
- [x] Keep QR PNG export available within the consolidated QR section
- [x] Remove the Box-detail Print action
- [x] Preserve permanent QR identifiers and scanner compatibility
- [x] Remove the obsolete print service, dependencies, labels and tests
- [x] Add revised layout and contextual QR-export widget coverage
- [x] Complete automated and manual validation with 453 passing tests

### Box Notes — Issue #96

- [x] Add nullable Box notes in Database Schema Version 6
- [x] Preserve existing data during the Version 5 to Version 6 migration
- [x] Add localized multiline notes controls to New Box and Edit Box
- [x] Allow notes to be added, changed and cleared
- [x] Display non-empty notes on Box details without an empty placeholder
- [x] Preserve Box notes in Backup Format Version 2
- [x] Restore older backups without Box notes using an empty default
- [x] Add repository, widget, migration and backup regression coverage
- [x] Complete automated and manual validation with 466 passing tests

### Edit Box Deletion — Issue #97

- [x] Remove the delete action from the Box-detail app bar
- [x] Add a localized destructive Delete Box action at the bottom of Edit Box
- [x] Retain confirmation and cancellation for empty Box deletion
- [x] Retain deletion protection for Boxes with assigned Animals
- [x] Distinguish saved and deleted Edit Box navigation results
- [x] Close the deleted Box detail and refresh the originating overview
- [x] Preserve deletion behaviour after contextual Box-detail swiping
- [x] Block conflicting save, picture and navigation actions during deletion
- [x] Update focused Box edit, detail-management and swipe-navigation tests
- [x] Complete automated and manual validation

### Animal Feeding History and Reminder Actions — Issue #98

- [x] Make the Latest Feeding card open the complete Animal feeding history
- [x] Add a dedicated reminder settings action to active Animal details
- [x] Move reminder editing out of Edit Animal while preserving its data
- [x] Persist reminder changes through a targeted repository operation
- [x] Keep the injected clock available for deterministic reminder baselines
- [x] Hide reminder configuration for archived Animals
- [x] Add localized English and German reminder settings/error text
- [x] Add repository and widget coverage for activation, validation, updates,
  disabling, archive protection and detail navigation
- [ ] Complete automated regression, Android/Web manual validation and release

### Remaining Milestone Scope

- [ ] Add About information and compact accent selection — Issue #99
- [ ] Make the pre-restore safety backup optional — Issue #100
- [ ] Complete v1.1.0 regression, documentation and release — Issue #101

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
