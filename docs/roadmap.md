# TerraManager Roadmap

## Current Status

Latest completed release milestone:

**v1.10.4 – Animal Detail & Rehouse Fixes**

The current development version is maintained in `pubspec.yaml`; published
versions are listed in GitHub Releases and `CHANGELOG.md`.

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
- persistent Animal categories and compatible subcategories
- grouped Animal Overview category navigation
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
- due reminder status above the Animal picture
- reminder navigation and immediate refresh after normal and Quick Feeding
  changes
- localized Animal sex and birth-date-accuracy labels without raw enum text
- one explicit Unknown sex choice with a legacy-null display fallback
- direct Animal creation from empty and populated Box detail assignments
- originating Box preselection and immediate assignment-list refresh
- persistent localized Box Overview sorting by natural Box number
- optional free-form Box names and alphabetical Box Overview sorting
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
- compact localized accent-color selection in Settings
- installed version, build number and developer information under Legal &
  Privacy
- optional per-restore safety backup with a safe enabled default
- adjacent swipe and keyboard navigation across all three primary pages
- state-preserving primary-page navigation with synchronized visible selection
- immediate Animal Overview refresh after creation from Box details
- long-press and secondary-click quick actions in Animal and Box overviews
- independent Box and Animal duplication with copied picture media
- new permanent QR identifiers for duplicated Boxes
- shared active and archived Box selection for batch QR export
- selected Box QR export as individual PNG images or one ZIP archive
- paginated A4 PDF export with labeled 6–20 mm vector QR codes
- on-device document generation through the operating-system save dialog
- stored-picture thumbnails for archived Animals with localized semantics
- slider-only 6–20 mm PDF QR sizing
- multiline Animal Weight input and detail presentation
- synchronized offline English and German privacy content
- localized licence guidance with the authoritative English GPL text
- one reversible menu toggle per Box and Animal overview sort criterion
- ordered Animal and Box picture histories with selectable primary images
- plural localized taxonomy headings in grouped Animal Overview views
- optional nighttime temperature with minimum and maximum daytime temperature
  labels
- Latest Feeding directly below Animal names
- linked assigned-Box labels on Animal details
- alphabetical Box sorting with unnamed Boxes last in both directions
- persistent Box volume sorting with incomplete dimensions last
- optional Big Picture Mode for Box and Animal overviews
- primary-navigation due-feeding indication
- timestamped Animal shedding history
- symmetric Animal and Box archive history workflows
- persistent archive sorting
- direct archive Restore and Duplicate actions
- per-Animal Weight and Shedding detail visibility
- optional next-feeding summary
- QR-based Animal Rehouse Mode
- local transactional Animal reassignment

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
manual regression validation are complete. Issues #81 and #82 provide
consistent Animal form labels and direct Animal creation from Box details.
Issues #83 and #85 add persistent, backup-compatible Box and Animal Overview
sorting with contextual detail navigation. Issue #86 completes release build
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

Development build `1.0.7+48` implements Issue #99. The former group of accent
chips is replaced by one compact localized dropdown without changing the
stored preference, and an About TerraManager dialog now reports the installed
version, build number and developer under Legal & Privacy.

Development build `1.0.8+49` implements Issue #100. Restore confirmation keeps
the pre-restore safety backup enabled by default and allows it to be disabled
for the current operation. Skipping it avoids an unnecessary export for an
empty database without weakening validation or transactional replacement.

Release `1.1.0+50` brings the completed Issue #94–#100 changes together with
the final automated, migration, backup, Android and Web regression from Issue
#101.

Development build `1.1.1+51` implements tester feedback for optional Box names
and alphabetical name sorting while retaining Box numbers, legacy sort
preferences and Portable Backup Format Version 2 compatibility.

Release `1.4.0+59` completes the Animal Profiles and Input Quality milestone
through Issues #108–#113. Database Schema Version 9 and Portable Backup Format
Version 2 form the compatibility baseline for all later releases.

Release `1.5.0+60` completes Issues #114 and #115. Animal and Box overviews
provide localized long-press and secondary-click quick actions. Duplicate
records receive independent identities and media; Box duplicates receive new
permanent QR identifiers, and Animal duplicates omit source feeding history.

Release `1.6.0+62` completes Issues #116 and #117. All three Settings export
actions reuse one active/archived Box checklist. Selected QR codes can be saved
as individual PNG files, one ZIP archive or labeled, paginated A4 PDF sheets
with a selectable 6–20 mm code size. ZIP and PDF generation remains local and
adds no broad storage, media or network permission.

Release `1.6.1+63` completes Issues #122–#126. Animal History displays stored
pictures with the established fallback, PDF QR sizing uses only the accessible
integer slider, and Weight supports multiline content. Privacy and licence
views follow English or German while remaining offline. Overview sort menus
now contain one reversible entry per criterion while keeping every persisted
and portable enum value compatible. Schema Version 9, Backup Format Version 2
and the existing permission boundary remain unchanged.

Release `1.7.0+64` completes Issues #127 and #128. Animals store a required
category and optional compatible subcategory from the stable Issue #127
taxonomy. Animal Overview can group the complete taxonomy under localized,
accessible headings while retaining natural A–Z row order and contextual
navigation. Schema Version 10 migrates existing Animals to Other without a
subcategory; Backup Format Version 2 remains backward compatible.

Release `1.7.1+65` moves the optional temperature-zone note to its owning Box
and advances the database from the released Schema Version 10 snapshot to
Schema Version 11. Existing values transfer deterministically without replacing
a populated Box value. The patch also shortens the individual Box QR export
description and separates the PNG, ZIP and PDF actions with standard Settings
dividers. Backup Format Version 2 and device permissions remain unchanged.

---

## v0.1.0 – Foundation

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

### Overview

- [x] Preserve Box Overview scroll position after detail navigation
- [x] Add regression coverage for Box Overview scroll restoration

### Release

- [x] Refresh documentation for the v0.7.x state
- [x] Release v0.7.1

---

## v0.8.0 – Contextual Navigation

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

### Picture Cropping — Issue #80

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

Status: **Completed**

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

Status: **Completed**

### Animal Form Labels — Issue #81

- [x] Replace raw English Sex enum labels
- [x] Show exactly Male, Female and Unknown in the sex selector
- [x] Use Unknown as the default and legacy-null presentation
- [x] Replace raw English BirthDateAccuracy enum labels
- [x] Keep English and German labels consistent
- [x] Preserve existing database and backup values without migration
- [x] Add form, detail and localization regression tests
- [x] Validate the updated controls manually on Android

### Add Animal from Box Details — Issue #82

- [x] Show Add Animal below empty and populated assigned-Animal sections
- [x] Open New Animal with the originating Box preselected
- [x] Keep the preselected Box editable
- [x] Refresh Box details after saving and preserve normal navigation
- [x] Block repeated Add Animal actions while the route is open
- [x] Add localized widget regression coverage
- [x] Validate direct creation manually on Android

### Box Overview Sorting — Issue #83

- [x] Add created-date and natural Box-label sorting modes
- [x] Persist and back up the selected Box ordering
- [x] Keep contextual Box detail navigation aligned with the visible order
- [x] Add sorting, settings and backup regression tests
- [x] Validate all Box ordering modes manually on Android

### Animal Overview Sorting — Issue #85

- [x] Add created-date, displayed-name, age and latest-feeding sorting modes
- [x] Handle missing birth and FeedingEvent data deterministically
- [x] Load latest FeedingEvents efficiently in bulk
- [x] Persist and back up the selected Animal ordering
- [x] Keep contextual Animal detail navigation aligned with the visible order
- [x] Add sorting, settings and backup regression tests
- [x] Validate all Animal ordering modes manually on Android

### Release — Issue #86

- [x] Complete automated and manual regression testing
- [x] Review English and German presentation
- [x] Update documentation and release notes
- [x] Build the supported release artifacts
- [x] Release v0.14.0

---

## v0.14.1 – Post-release Fixes

Status: **Completed**

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

Status: **Completed**

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

Status: **Completed**

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
- [x] Complete automated regression and manual validation

### About Information and Compact Accent Selection — Issue #99

- [x] Replace the accent-color chip group with one compact dropdown
- [x] Preserve localized color labels and immediate persistent theme updates
- [x] Add About TerraManager under Legal & Privacy
- [x] Load the installed version and build number from platform package data
- [x] Display the developer in the localized About dialog
- [x] Handle unavailable package information without opening a broken dialog
- [x] Add localized English and German About labels
- [x] Add focused Settings and localization coverage
- [x] Complete automated and manual validation

### Optional Pre-Restore Safety Backup — Issue #100

- [x] Add a safety-backup checkbox to destructive Restore confirmation
- [x] Keep the checkbox enabled by default for every Restore attempt
- [x] Allow the user to disable it for the current Restore operation
- [x] Skip safety-backup creation and file persistence when disabled
- [x] Keep validation, confirmation and transactional replacement unchanged
- [x] Keep safety-backup failures blocking while the option is enabled
- [x] Return an explicit empty safety-backup result when the option is disabled
- [x] Add localized English and German labels and explanatory text
- [x] Add service and Settings widget coverage for both option states
- [x] Complete automated regression and Android/Web manual validation

### v1.1.0 Release — Issue #101

- [x] Set the release candidate version to `1.1.0+50`
- [x] Finalize the v1.1.0 changelog and documentation baseline
- [x] Add the complete release-regression checklist
- [x] Complete clean automated validation
- [x] Complete Database Schema Version 5 to Version 6 migration regression
- [x] Complete current and legacy backup regression
- [x] Build and verify all supported release artifacts
- [x] Complete Android and Web manual regression
- [x] Confirm the final GitHub Actions Quality gates run
- [x] Publish the v1.1.0 tag and GitHub release

---

## v1.1.1 – Optional Box Names

Status: **Completed**

### Tester Feedback Update

- [x] Set development version to `1.1.1+51`
- [x] Add nullable `Box.name` with a Version 6 to Version 7 migration
- [x] Allow optional names during Box creation and editing
- [x] Keep generated Box numbers visible for named Boxes
- [x] Display non-empty names on Box details
- [x] Add persistent name A–Z and Z–A overview sorting
- [x] Place unnamed Boxes after named Boxes in both name orders
- [x] Preserve names through backward-compatible Backup Format Version 2
- [x] Add migration, repository, backup, settings and widget coverage
- [x] Complete automated regression
- [x] Complete Android and Web manual validation

---

## v1.2.0 – Box Lifecycle & History

Status: **Completed**

### Box Lifecycle Persistence — Issue #102

- [x] Add persistent active and archived Box states in Schema Version 8
- [x] Retain archive reason, timestamp and optional notes
- [x] Preserve lifecycle data in current backups and restore legacy backups
- [x] Validate migration, restart, backup and portable enum compatibility

### Box Archive and Restore Workflows — Issue #103

- [x] Archive only empty active Boxes through Edit Box
- [x] Keep assigned Animals protected and list blockers before archive
- [x] Exclude archived Boxes from active workflows and Animal assignment
- [x] Restore archived Boxes with their permanent QR identifier
- [x] Handle archived QR scans in English and German
- [x] Restrict permanent deletion to archived Box details

### Box History — Issue #104

- [x] Add the Archived Boxes entry point and localized empty state
- [x] Show archived Boxes newest first with identity, picture and metadata
- [x] Open retained archived details through normal and contextual navigation
- [x] Cover populated, empty, restore and deletion states with widget tests

### v1.2.0 Release — Issue #105

- [x] Complete automated migration, lifecycle, QR and backup regression
- [x] Verify direct v1.1.x upgrade and current and legacy backup restore
- [x] Build Android and Web release artifacts
- [x] Verify production signatures and record artifact hashes
- [x] Complete physical-device Box lifecycle and archived-QR checks
- [x] Finalize version, changelog, documentation and release validation record
- [x] Publish the annotated `v1.2.0` tag from the final release commit
- [x] Publish the GitHub v1.2.0 release with the verified APK

---

## v1.3.0 – Primary Page Navigation

Status: **Completed**

### Swipe between Primary Pages — Issue #106

- [x] Keep Box Overview, Animal Overview and Settings in one shared shell
- [x] Swipe horizontally between adjacent primary pages in both directions
- [x] Synchronize the bottom-navigation selection after every page change
- [x] Preserve overview scroll positions, sort choices and Settings state
- [x] Keep navigation-bar taps and normal platform Back behaviour
- [x] Keep contextual detail swipes separate from root-page swipes
- [x] Avoid page changes during short gestures, vertical Settings scrolling and
  open dropdown interaction
- [x] Add localized semantics and keyboard-compatible page navigation
- [x] Give retained overview action buttons independent Hero identities
- [x] Refresh Animal Overview after direct creation from Box details
- [x] Add focused and integrated widget regression coverage

### v1.3.0 Release — Issue #107

- [x] Set release version to `1.3.0+55`
- [x] Complete localization generation, formatting, static analysis and tests
- [x] Validate root and contextual navigation regression
- [x] Review database, backup, privacy and platform compatibility
- [x] Release owner built and submitted Version `1.3.0` with Build `55`
- [x] Verify the release-owner APK signature and record its SHA-256
- [x] Update changelog, roadmap, navigation, installation and release records
- [x] Complete physical Android and hosted Web manual checks
- [x] Publish Version `1.3.0+55` through GitHub and Google Play
- [x] Close Issues #106 and #107 after the documentation commit succeeds

---

## v1.4.0 – Animal Profiles and Input Quality

Status: **Completed**

### Display Box names in Animal forms — Issue #108

- [x] Show a trimmed Box name together with its stable Box number
- [x] Keep the Box-number fallback for unnamed or whitespace-only names
- [x] Use the same labels in New Animal and Edit Animal
- [x] Cover duplicate names, fallbacks and existing selections

### Natural name sorting — Issue #109

- [x] Compare embedded digit sequences numerically and case-insensitively
- [x] Apply natural ordering to Box and Animal name sorts in both directions
- [x] Preserve deterministic tie breaking and missing-value placement
- [x] Keep contextual detail navigation aligned with the visible order

### Environmental input limits — Issue #110

- [x] Restrict humidity inputs to 0–100 percent
- [x] Restrict temperature inputs to the documented realistic range
- [x] Reject non-finite and reversed ranges in forms and repositories
- [x] Localize range validation for New Animal and Edit Animal

### Hermaphrodite / other sex — Issue #111

- [x] Add one localized Hermaphrodite / other choice to both Animal forms
- [x] Display the localized value on Animal details
- [x] Persist and back up the stable portable value `other`
- [x] Preserve every existing sex and legacy-null fallback

### Optional extended Animal characteristics — Issue #112

- [x] Add one expandable Additional characteristics section to both forms
- [x] Store origin or habitat, weight, shedding notes, rest or dormancy periods
  and temperature zones as independent optional text fields
- [x] Allow every value to be added, edited and cleared
- [x] Show only populated values with localized labels on Animal details
- [x] Advance to Schema Version 9 with a populated v8 migration regression
- [x] Extend Backup Format 2 additively and retain older backup restore
- [x] Complete English and German UI and persistence coverage

### Offline application license — Issue #113

- [x] Place License directly below Privacy Policy in Settings
- [x] Reuse the legal-document typography, scrolling and navigation structure
- [x] Bundle the authoritative complete repository `LICENSE` file
- [x] Display TerraManager, CodefrogCF and `GPL-3.0-or-later` consistently
- [x] Keep references local without invoking an external application
- [x] Cover offline content, navigation, asset identity and large text

### v1.4.0 Release

- [x] Set the source version to `1.4.0+59`
- [x] Generate localizations, Drift Schema Version 9 and migration helpers
- [x] Complete formatting, static analysis and automated source regression
- [x] Update changelog, roadmap, schema, backup and release documentation
- [x] Pass the final GitHub Actions Quality gates on the release commit
- [x] Build and sign Android release artifacts in the release-owner environment
- [x] Complete Android and hosted Web manual validation
- [x] Publish the annotated `v1.4.0` tag and GitHub/Google Play releases
- [x] Close Issues #112 and #113 after the release commit succeeds

---

## v1.5.0 – Overview Quick Actions

Status: **Completed**

### Animal and Box context menus — Issue #114

- [x] Open overview actions by long press on touch devices
- [x] Open the same actions by secondary click on pointer platforms
- [x] Offer Create Feeding, Rename, Edit, Archive and Duplicate for active
  Animals
- [x] Offer Rename, Edit, Duplicate and Archive for active Boxes
- [x] Reuse existing validation, archive confirmation and overview refresh
- [x] Add complete English and German labels and focused widget coverage

### Independent record duplication — Issue #115

- [x] Create every duplicate as a new active database record
- [x] Generate a new permanent QR identifier for every Box duplicate
- [x] Select an active destination Box for every Animal duplicate
- [x] Copy reusable profile data into the duplicate
- [x] Copy picture bytes into an independent MediaAsset
- [x] Clear lifecycle metadata and omit Animal feeding history
- [x] Allow archived Animals to be duplicated without changing the source
- [x] Preserve duplicates and independent media in current backups

### v1.5.0 Release

- [x] Set the source version to `1.5.0+60`
- [x] Complete formatting, analysis and automated source regression
- [x] Preserve Schema Version 9 and Backup Format Version 2
- [x] Publish the annotated `v1.5.0` tag
- [x] Confirm the final GitHub Actions Quality gates run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub release

---

## v1.6.0 – Batch QR Export

Status: **Completed**

### Save selected Box QR codes — Issue #116

- [x] Load active and archived Boxes into one shared checklist
- [x] Select all Boxes initially and support Select all, Clear and opt-out
- [x] Reuse the same selection workflow for every Settings QR export
- [x] Save selected QR codes as individual PNG images
- [x] Save selected PNG images together in one ZIP archive
- [x] Handle empty data, cancellation and generation failures explicitly

### Export selected QR codes as an A4 PDF sheet — Issue #117

- [x] Reuse the complete Box selection workflow from Issue #116
- [x] Choose QR sizes from 6 mm to 20 mm with integer slider values
- [x] Provide 6, 10, 15 and 20 mm presets
- [x] Lay out vector QR codes on exact A4 pages with safe margins and spacing
- [x] Add Box names and stable Box numbers with safe long-name handling
- [x] Add pages automatically when the selected codes exceed one sheet
- [x] Generate the complete PDF locally before opening the save dialog
- [x] Decode the smallest 6 mm output in an automated scan regression
- [x] Add no broad storage, media or network permission

### v1.6.0 Release

- [x] Set the source version to `1.6.0+62`
- [x] Complete formatting, analysis and the 643-test source regression
- [x] Synchronize bundled and public privacy documentation
- [x] Preserve Schema Version 9 and Backup Format Version 2
- [x] Publish the annotated `v1.6.0` tag
- [x] Confirm the final GitHub Actions Quality gates run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub and Google Play releases

---

## v1.6.1 – UX Consistency & Localization

Status: **Completed**

### Archived Animal thumbnails — Issue #122

- [x] Display stored Animal pictures in Animal History
- [x] Match the existing 56 px clipped thumbnail presentation
- [x] Retain the Animal fallback icon for missing or invalid media
- [x] Keep list and thumbnail taps on the correct archived detail context
- [x] Add localized thumbnail semantics without new permissions

### PDF QR-size controls — Issue #123

- [x] Remove the 6, 10, 15 and 20 mm preset actions
- [x] Retain the integer 6–20 mm slider and 15 mm default
- [x] Announce the selected millimetre value through Slider semantics
- [x] Preserve Box selection, exact A4 layout, labels and QR payloads
- [x] Leave individual PNG and ZIP export unchanged

### Multiline Animal Weight — Issue #124

- [x] Use the same multiline Weight field in New Animal and Edit Animal
- [x] Preserve internal line breaks and trim empty input to `null`
- [x] Display multiline Weight values correctly on Animal details
- [x] Keep Database Schema Version 9 and Backup Format Version 2 unchanged

### Localized legal content — Issue #125

- [x] Select bundled English or German privacy content from the app locale
- [x] Fall back to English for unsupported locales
- [x] Synchronize both bundled policies with their public documentation pages
- [x] Identify TerraManager, Codefrog and the effective date consistently
- [x] Explain in German that the unchanged English GPL text is authoritative
- [x] Keep the complete GPL text accessible offline without external launch
- [x] Retain scrollability with large accessibility text

### Directional sort toggles — Issue #126

- [x] Show two Box and four Animal sort criteria exactly once
- [x] Apply each criterion's documented direction when first selected
- [x] Reverse the active criterion when it is selected again
- [x] Display and announce the current localized direction
- [x] Refresh visible order and contextual detail navigation immediately
- [x] Preserve every existing preference and backup enum value

### v1.6.1 Release

- [x] Set the source version to `1.6.1+63`
- [x] Preserve Schema Version 9 and Backup Format Version 2
- [x] Generate English and German localizations
- [x] Complete formatting, analysis and automated source regression
- [x] Synchronize bundled and public privacy documentation
- [x] Publish the annotated `v1.6.1` tag
- [x] Confirm the final GitHub Actions Quality gates run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub and Google Play releases

---

## v1.7.0 – Animal Taxonomy & Category Views

Status: **Completed**

### Persistent Animal taxonomy — Issue #127

- [x] Require a primary category in New Animal and Edit Animal
- [x] Offer only compatible optional subcategories for the selected category
- [x] Place the shared taxonomy controls between Latin name and Sex
- [x] Clear an incompatible subcategory when the primary category changes
- [x] Store stable portable enum values in Database Schema Version 10
- [x] Migrate existing Animals to `other` without a subcategory
- [x] Display localized category and optional subcategory on Animal details
- [x] Preserve taxonomy during editing and Animal duplication
- [x] Extend Backup Format Version 2 without breaking Format 1 or older Format 2
- [x] Reject unknown categories, unknown subcategories and invalid combinations

### Category-grouped Animal Overview — Issue #128

- [x] Add Category as one directional Animal Overview sort criterion
- [x] Group all visible Animals in the complete Issue #127 category order
- [x] Include Amphibian, Reptile, Arachnid, Insect, Myriapod, Crustacean,
  Mollusc, Other invertebrate and Other
- [x] Reverse only the primary category order when Category is selected again
- [x] Show localized subcategory headings only when they distinguish a group
- [x] Keep Other and Not specified after named subcategory groups
- [x] Sort Animals naturally A–Z by the selected common/Latin primary name
- [x] Use database ID as the deterministic final tie breaker
- [x] Preserve thumbnails, reminders and quick actions in grouped rows
- [x] Pass the flattened visible order to contextual detail navigation
- [x] Persist and back up both Category sort directions
- [x] Provide accessible localized category and subcategory headings

### v1.7.0 Release

- [x] Set the source version to `1.7.0+64`
- [x] Advance to Database Schema Version 10
- [x] Preserve Portable Backup Format Version 2 compatibility
- [x] Generate English and German localizations and Drift migration artifacts
- [x] Complete formatting, analysis and automated source regression
- [x] Publish the annotated `v1.7.0` tag
- [x] Confirm the final GitHub Actions **Quality gates** run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub and Google Play releases

---

## v1.7.1 – Enclosure Notes & Migration

Status: **Completed**

### Box-owned temperature-zone notes

- [x] Move the optional temperature-zone note from Animal UI to Box UI
- [x] Place temperature zones directly above Notes in New Box and Edit Box
- [x] Show populated temperature zones on Box details
- [x] Preserve Box temperature zones through duplication and portable backup
- [x] Preserve the released Schema Version 10 snapshot
- [x] Add `Box.temperatureZones` in the v10 to v11 migration
- [x] Seed empty Boxes from the first non-empty assigned-Animal value by ID
  during migration and restore
- [x] Cover direct populated v10 to v11 migration and foreign-key integrity

### QR Settings polish

- [x] Keep the shared Box selection workflow for PNG, ZIP and PDF export
- [x] Shorten the individual Box QR export description
- [x] Separate PNG, ZIP and PDF export actions with standard Settings dividers
- [x] Add no storage, media, network or other device permission

### v1.7.1 Release

- [x] Set the source version to `1.7.1+65`
- [x] Advance to Database Schema Version 11
- [x] Preserve Portable Backup Format Version 2 compatibility
- [x] Generate the Schema Version 11 snapshot and Drift migration artifacts
- [x] Complete formatting, analysis and the 691-test source regression
- [x] Publish the annotated `v1.7.1` tag
- [x] Confirm the final GitHub Actions **Quality gates** run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub and Google Play releases

---

## v1.7.2 – Media Galleries

Status: **Completed**

### Animal and Box picture histories — Issue #78

- [x] Store ordered media associations for Animals and Boxes
- [x] Preserve every existing persistent picture during the v11 to v12
  migration
- [x] Keep one selectable primary image on each detail page
- [x] Record a capture or import timestamp for every gallery entry
- [x] Retain previous pictures when a new image is selected
- [x] Open every gallery image in the existing full-screen viewer
- [x] Require confirmation before deleting one gallery image
- [x] Keep unrelated images untouched during deletion
- [x] Duplicate complete galleries with independent MediaAssets
- [x] Preserve gallery order, timestamps and primary selection in Backup
  Format Version 2
- [x] Keep older single-picture backups restorable
- [x] Add migration, repository, widget and backup regression coverage
- [x] Add no storage, media, network or other device permission

### v1.7.2 Release

- [x] Set the source version to `1.7.2+66`
- [x] Advance to Database Schema Version 12
- [x] Preserve Portable Backup Format Version 2 compatibility
- [x] Complete central documentation and automated source regression
- [x] Publish the `v1.7.2` tag

---

## v1.8.0 – Animal Details, Sorting & Environmental Data

Status: **Completed**

### Grouped taxonomy labels — Issue #129

- [x] Use localized plural category and displayed subcategory headings
- [x] Keep singular labels in forms and Animal details
- [x] Preserve stored taxonomy values, grouping order and contextual navigation

### Animal detail priorities — Issues #130 and #132

- [x] Show active due reminders above the Animal picture
- [x] Omit scheduled and archived reminder placeholders
- [x] Place Latest Feeding directly below the Animal names
- [x] Keep Latest Feeding linked to the complete feeding history
- [x] Show the optional Box name before `Box N`
- [x] Open the assigned Box from an accessible link and return to the same
  Animal
- [x] Fall back safely for missing or inconsistent legacy Box references

### Animal nighttime temperature — Issue #131

- [x] Label the existing range as minimum and maximum daytime temperature
- [x] Add an optional bounded nighttime temperature under Additional
  characteristics
- [x] Persist the value through editing, duplication and Backup Format Version
  2
- [x] Add nullable `Animal.nighttimeTemperature` in Schema Version 13
- [x] Keep existing data and older backups compatible with a null default

### Box ordering — Issues #133 and #134

- [x] Keep unnamed Boxes last for Name A–Z and Name Z–A
- [x] Preserve natural case-insensitive name sorting and deterministic ID ties
- [x] Add a reversible localized Volume criterion
- [x] Calculate volume only from complete width × height × depth values
- [x] Keep incomplete dimensions last in both volume directions
- [x] Persist and back up both volume directions
- [x] Pass the visible order into contextual Box navigation

### v1.8.0 Release

- [x] Set the release version and build number
- [x] Advance to Database Schema Version 13
- [x] Preserve Portable Backup Format Version 2 compatibility
- [x] Generate English and German localizations and Drift migration artifacts
- [x] Add no device permissions
- [x] Confirm the final GitHub Actions **Quality gates** run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub and Google Play releases

---

## v1.9.0 – Animal Input & History

Status: **Completed**

### Paired environmental inputs — Issues #136 and #137

- [x] Present daytime temperature and humidity as labeled minimum/maximum pairs
- [x] Replace the single nighttime-temperature control with optional minimum
  and maximum fields using the same responsive component
- [x] Accept localized decimal input while retaining the existing temperature
  and humidity bounds
- [x] Reject reversed ranges without requiring both optional bounds
- [x] Migrate a legacy nighttime value to both new bounds
- [x] Preserve new and legacy values through duplication and Backup Format
  Version 2

### Scheduled feeding on Animal details — Issue #138

- [x] Keep active due reminders above the Animal picture
- [x] Show a future next-feeding timestamp directly below Latest Feeding
- [x] Omit the scheduled card for disabled, due and archived reminders
- [x] Refresh derived reminder data after feeding and reminder changes
- [x] Add no background service, notification or device permission

### Numeric Animal weight history — Issue #139

- [x] Accept optional positive decimal weights in grams
- [x] Create a timestamped measurement only when the numeric value changes
- [x] Show the current weight and reverse-chronological history on Animal
  details
- [x] Add a quick measurement action beside Weight History on Animal details
- [x] Add new measurements and edit values or timestamps in Weight History
- [x] Delete individual measurements from Weight History after confirmation
- [x] Preserve history while archived and delete it with its Animal
- [x] Duplicate only the current weight as one new measurement
- [x] Migrate unambiguous legacy gram values and retain ambiguous legacy text
- [x] Export, validate and restore complete weight history in Backup Format 2

### Additional-characteristic order — Issue #140

- [x] Use one shared expandable section in New Animal and Edit Animal
- [x] Order birth date, accuracy, sex, weight, origin, nighttime temperature,
  rest periods, shedding notes and notes consistently
- [x] Expand Edit Animal automatically when any optional value is populated
- [x] Keep Animal details aligned with the daytime and nighttime range order
- [x] Label both temperature ranges without units and render locale-aware values
  with one decimal place and `°C`

### v1.9.0 Release

- [x] Set the release version and build number
- [x] Advance to Database Schema Version 14
- [x] Preserve Portable Backup Format Version 2 compatibility
- [x] Generate English and German localizations and Drift migration artifacts
- [x] Add no device permissions
- [x] Confirm the final GitHub Actions **Quality gates** run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub and Google Play releases

---

## v1.9.1 – Overview & Edit Box Refinements

Status: **Completed**

### Independent Animal category view — Issue #142

- [x] Remove Category from the Animal Overview sort menu
- [x] Add an accessible category-view toggle directly left of the sort control
- [x] Keep canonical category and conditional subcategory headings in the
  grouped view
- [x] Apply creation, displayed-name, age and latest-feeding sorting in flat and
  grouped views
- [x] Apply the selected direction inside every final category group
- [x] Preserve the flattened visible order for contextual Animal navigation
- [x] Persist and back up the category-view setting
- [x] Migrate legacy Category sort settings to enabled grouping and the
  corresponding displayed-name direction
- [x] Provide English and German labels and accessible toggle semantics

### Edit Box QR information order — Issue #143

- [x] Keep temperature zones and Notes together in their existing order
- [x] Move the read-only QR identifier and explanation below Notes
- [x] Keep Save followed by Archive as the bottom actions
- [x] Preserve the permanent QR identifier across ordinary edits
- [x] Support enlarged accessibility text and small screens
- [x] Add no database, backup-format or permission change

### v1.9.1 Release

- [x] Set the release version and build number
- [x] Keep Database Schema Version 14
- [x] Preserve Portable Backup Format Version 2 compatibility
- [x] Generate English and German localizations
- [x] Add no device permissions
- [x] Confirm the final GitHub Actions **Quality gates** run
- [x] Record release-owner Android/Web artifacts and manual checks
- [x] Publish the GitHub and Google Play releases

---

## v1.10.0 — Animal Workflow & History Polish

Status: **Completed**

- [x] Add optional Big Picture Mode to Box and Animal overviews
- [x] Support Big Picture Mode in flat and category-grouped Animal views
- [x] Persist Big Picture Mode locally and through portable backups
- [x] Add a due-feeding indicator to the primary Animals navigation item
- [x] Make the first Latest Feeding sort selection use the oldest-first
      direction
- [x] Replace free-form shedding notes with timestamped shedding events
- [x] Add quick shedding entry from Animal details and Edit Animal
- [x] Add reverse-chronological shedding history
- [x] Allow shedding events to be created, edited and deleted
- [x] Preserve shedding history while Animals are archived
- [x] Migrate compatible legacy shedding notes deterministically
- [x] Export and restore shedding history through Backup Format Version 2
- [x] Advance to Database Schema Version 15
- [x] Preserve Android and Web compatibility
- [x] Introduce no new device permission

---

## v1.10.1 — Symmetric Archive History

Status: **Completed**

- [x] Add a dedicated Box History page
- [x] Align Box History presentation with Animal History
- [x] Show archived Box thumbnails, labels and archive information
- [x] Sort Animal and Box archives by archive date in both directions
- [x] Sort Animal and Box archives by displayed name in both directions
- [x] Persist archive sorting locally
- [x] Expose Box duplication from archived entries
- [x] Consolidate project and release documentation
- [x] Keep archive sorting outside portable backup data
- [x] Preserve Database Schema Version 15 and Backup Format Version 2

---

## v1.10.2 — Archive Actions & Animal Detail Preferences

Status: **Completed**

- [x] Add Restore to archived Animal context menus
- [x] Select an active destination Box while restoring an Animal
- [x] Add Restore to archived Box context menus
- [x] Allow an existing Animal birth date to be cleared
- [x] Clear birth-date accuracy together with the birth date
- [x] Add per-Animal Weight visibility for Animal details
- [x] Add per-Animal Shedding visibility for Animal details
- [x] Default both visibility settings to enabled
- [x] Add an optional next-feeding summary to the Animal Overview
- [x] Preserve existing due-reminder behavior
- [x] Advance to Database Schema Version 16
- [x] Add the new Animal fields and setting to Backup Format Version 2
- [x] Preserve compatibility with older databases and backups
- [x] Introduce no new device permission

---

## v1.10.3 — QR Rehouse Mode

Status: **Completed**

- [x] Add a QR scanner action to Edit Animal
- [x] Reuse the existing local Box scanner
- [x] Resolve scanned Box identifiers locally
- [x] Accept only active destination Boxes
- [x] Reject unknown, archived and current Box identifiers
- [x] Ask for confirmation before reassignment
- [x] Move the active Animal through one atomic repository operation
- [x] Preserve the previous assignment when validation or persistence fails
- [x] Close the scanner and Edit Animal after successful reassignment
- [x] Reuse the existing camera permission
- [x] Preserve Database Schema Version 16 and Backup Format Version 2

---

## v1.10.4 — Animal Detail & Rehouse Fixes

Status: **Completed**

- [x] Hide the Sex row when the value is absent or Unknown
- [x] Continue to display explicit localized sex values
- [x] Prevent duplicate navigation pops after QR reassignment
- [x] Close the scanner and Edit Animal exactly once after success
- [x] Preserve Database Schema Version 16 and Backup Format Version 2
- [x] Introduce no new device permission

---

## Website 1.0 – Homepage, Downloads & Guides

Status: **Completed**

### TerraManager project homepage — Issue #119

- [x] Implement one responsive homepage structure for phones, tablets and
  desktops under the GitHub Pages `/TerraManager/` project path
- [x] Make the complete German homepage the default and render English content
  through the same shared layout and localized data model
- [x] Introduce TerraManager, its main features and its local-first privacy
  model without requiring an account, tracker, cookie or external script
- [x] Present an accessible device mockup without adding a remote media
  dependency
- [x] Link Google Play, GitHub Releases, installation guidance, testing
  guidance, project documentation, support and the source repository
- [x] Keep English and German Privacy Policy pages and a local copy of the
  authoritative GPL-3.0-or-later license reachable
- [x] Use semantic headings, visible keyboard focus, a skip link, descriptive
  image alternatives and contrast-safe colors
- [x] Add canonical, language-alternate, page-title, description, favicon and
  Open Graph/Twitter metadata
- [x] Keep every internal URL compatible with direct navigation and reloads
  below the configured GitHub Pages base path
- [x] Add automated source checks for localization structure, privacy,
  accessibility markers, metadata and internal page targets
- [x] Enable GitHub Pages from the repository `docs/` directory and verify the
  published site at `https://codefrogcf.github.io/TerraManager/`

---

## Shared Care LAN mode — Issues #156–#171

Status: **Implemented; operator field checks passed on one Raspberry Pi**

- [x] Keep the standalone Android and Web collections separate from shared data
- [x] Store the shared collection and local caregiver accounts on a self-hosted
  server with an authenticated care API and trusted LAN HTTPS
- [x] Provide a browser interface with Box, Animal, history, media, backup,
  QR Feeding and QR Rehouse workflows
- [x] Match overview sorting, Big Picture, context actions, detail navigation
  and in-app Feeding reminders, including the Animals navigation indicator
- [x] Align overview toolbar order with standalone, keep Reload rightmost and
  move the browser-local Big Picture switch to Settings — Issue #183
- [x] Reuse overview pictures while scrolling and polling, with a bounded,
  session-scoped memory cache and explicit snapshot refresh — Issue #184
- [x] Offer the browser-local Show next feeding switch above Big Picture Mode
- [x] Export selected active and archived Box QR codes as PNG, ZIP and A4 PDF
- [x] Document the user workflow and Raspberry Pi deployment

The deployment checklist remains necessary for each new installation and
material update; this is not cloud sync or direct synchronization with the
standalone Android collection.

---

## v1.14.0 — Shared Care Administration & Audit

Issue #176 allows a first portable import without a safety download only when
all server collection tables are empty. Administrator authorization, CSRF,
explicit confirmation, archive validation and transactional replacement remain
required. The server rechecks emptiness while excluding caregiver writes.
Populated collections continue to require a current safety copy.

Issue #177 adds transactional server audit metadata for collection and account
changes, stable actor identities, 365-day retention and preservation across
portable restore. Audit persistence failure rolls back the corresponding change.
Shared Care browser Back also returns through detail, scanner and dialog routes.

Next planned work covers account administration (#178) and an administrator
audit viewer (#179). These are not yet implemented.

## Future Development

Possible later development areas include:

- sensors
- automatic temperature and humidity tracking
- smart-home integration
- automatic backups
- scheduled backups
- cloud synchronization
- optional remotely hosted accounts beyond the self-hosted LAN server
- direct device-to-device synchronization with the standalone collections
- health and event tracking
- breeding records
- enclosure maintenance history
