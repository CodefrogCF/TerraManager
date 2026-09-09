# Functional Requirements – MVP

This document defines the functionality intended for the TerraManager MVP.

Implementation progress is tracked separately in `roadmap.md`.

## Boxes

The application must allow the user to:

- create a new Box
- automatically assign a permanent unique QR identifier
- view the Box overview
- sort the Box overview by ascending or descending natural Box number
- persist the selected Box Overview order between application restarts
- view Box details
- edit optional Box width, height and depth
- add, replace or remove a persistent Box picture
- take a new Box picture with a supported device camera
- select a Box picture from the device gallery
- crop a selected or captured Box picture before applying it
- open a Box picture in a full-screen viewer
- zoom and pan a Box picture in the full-screen viewer
- display human-readable local Box labels while preserving the permanent QR identifier
- display Box thumbnails where pictures are available
- view Animals assigned to a Box
- open an assigned Animal from the Box detail screen
- create a new Animal directly from Box details with that Box preselected
- refresh assigned Animals immediately after direct creation
- delete an empty Box
- require confirmation before deleting a Box
- prevent accidental deletion of a Box containing Animals
- identify a Box by QR code
- preserve Box Overview scroll position after returning from related detail workflows
- swipe between Box details using the ordering of the Box Overview

The permanent QR identifier must remain unchanged when associated application
data changes.

## Animals

The application must allow the user to:

- create an Animal
- assign an Animal to a Box
- view the Animal overview
- sort the Animal overview by oldest or newest creation time
- sort the Animal overview by the displayed primary name in both directions
- sort the Animal overview by oldest or youngest age
- sort the Animal overview by newest or oldest latest FeedingEvent
- place missing birth and FeedingEvent data deterministically
- persist the selected Animal Overview order between application restarts
- display Animal thumbnails where pictures are available
- preserve Animal Overview scroll position after returning from related detail/history workflows
- view Animal details
- swipe between Animal details using the ordering of the source collection
- edit Animal data
- change the associated Box
- add or remove an Animal picture
- take a new Animal picture with a supported device camera
- select an Animal picture from the device gallery
- crop a selected or captured Animal picture before applying it
- open an Animal picture in a full-screen viewer
- zoom and pan an Animal picture in the full-screen viewer
- persist Animal pictures across normal application restarts or browser reloads
- add and edit notes
- store preferred temperature values
- store preferred humidity values
- store optional birth information
- store and display Male, Female or Unknown sex information
- display legacy Animals without a stored sex value as Unknown
- present sex and birth-date-accuracy choices as localized user-facing labels
  without raw enum values
- archive an Animal without losing its data
- select an archive reason and archive date
- store an optional archive note
- remove archived Animals from active Box assignments
- view archived Animals in Animal History
- open archived Animal details
- restore an archived Animal to a selected Box
- preserve feeding history while an Animal is archived
- preserve its picture while an Animal is archived
- optionally configure a feeding reminder interval in positive whole days
- capture a reminder baseline when the reminder is enabled
- retain reminder configuration while the Animal is archived
- calculate a reminder due timestamp from its configuration and feeding history
- permanently delete an archived Animal through an explicit confirmation workflow

Active Animals must have a Box assignment.

Archived Animals must not have an active Box assignment.

Application-owned Box and Animal pictures must use persistent TerraManager
storage and must not depend on temporary image-selection paths for normal
operation.

If a picture source is unavailable or access is denied, the application must
remain usable and the existing picture must remain unchanged.

Cancelling picture cropping must return to the form without replacing the
current picture. A confirmed crop must be used by the existing preview,
persistence and portable backup workflows.

Newly selected or captured Box and Animal pictures must be resized without
upscaling to a maximum 1920-pixel longest edge and stored as WebP with quality
82. Existing pictures in supported legacy formats must remain usable without an
automatic destructive conversion.

Camera and Gallery pictures must pass through the same crop and normalization
path. While normalization is running, the form must communicate progress and
must not allow another picture import or a save operation. Repeated callbacks
must not create duplicate MediaAssets.

Replacing a stored picture must be atomic. Until the normalized replacement and
its Box or Animal reference have been saved successfully, the previous
MediaAsset must remain valid. A processing or persistence error must leave the
previous picture unchanged.

## Contextual Detail Navigation

When a detail page is opened from an ordered collection, the application must
preserve:

- the ordered record IDs
- the currently displayed record
- the source collection
- the source Box for a Box-specific Animal collection

Supported Animal source collections are Active Animals, Animal History and the
active Animals assigned to one Box.

Supported Box navigation follows the Box Overview ordering.

Horizontal navigation must stop at the first and last record of the source
collection. Editing or acting on a detail page must affect the record currently
displayed after swiping.

Back must return to the overview from which the detail route was opened.

Opening a detail page without a navigation context must remain supported and
must not enable contextual swipe navigation.

## Feeding

The application must allow the user to:

- add a FeedingEvent
- edit an existing FeedingEvent
- delete a FeedingEvent through an explicit confirmation workflow
- store an optional feeding note
- clear an existing feeding note
- view complete feeding history
- determine the latest feeding
- display the latest feeding directly on the Animal detail screen

The latest feeding must be derived from feeding history rather than duplicated
in the Animal record.

The Animal detail screen must display the most recent FeedingEvent, including
its timestamp and optional note.

The displayed value must refresh after the feeding history is modified.

The application must provide a dedicated Feeding Mode that allows the user to:

- scan a permanent Box QR code
- view the active Animals currently assigned to the scanned Box
- handle a Box without active Animals without creating a feeding
- select one or multiple Animals
- use the current date and time as the default feeding timestamp
- adjust the feeding timestamp
- enter an optional note shared by the selected Animals
- create one FeedingEvent for every selected Animal
- return to the scanner after saving or cancelling

All active Animals displayed after a scan should be selected by default so a
single-Animal Box can be recorded with a minimal number of actions.

Creating multiple FeedingEvents through Feeding Mode must be atomic. If one
event cannot be inserted, no event from the grouped feeding may remain.

Repeated save submissions must not create duplicate FeedingEvents.

Feeding Mode must use the existing FeedingEvent model so new entries remain
visible and editable through the existing Animal feeding history.

Per-Animal feeding reminders must be disabled by default. When enabled, both a
positive whole-day interval and a baseline timestamp must be stored. Invalid or
incomplete reminder configuration must not be saved.

Archiving an Animal must retain its configuration for a later restore, while
archived Animals must not produce active reminder results.

For each active Animal with an enabled reminder, the reminder reference is its
latest FeedingEvent timestamp whenever feeding history exists. The configured
baseline is used only when no FeedingEvent exists. The due timestamp is that
reference plus the configured whole-day interval. The Animal is due when the
current time is equal to or later than this timestamp.

Reminder calculations must use current FeedingEvent data rather than storing a
duplicate due-state value. Adding, editing or deleting a FeedingEvent must
therefore affect the next calculation immediately. Loading overview reminder
states must aggregate latest feedings without issuing one query per Animal.

When at least one active Animal is due, the Animal Overview must show a
non-modal reminder summary containing the number of due Animals. Its entries
must be ordered from most overdue to least overdue and open the corresponding
Animal. Due Animals must also be visibly marked in the regular overview list.
Animals that are not due and archived Animals must not appear in the summary.

An Animal with an enabled reminder must show its current due or scheduled state
and calculated due timestamp on the detail screen. The status must open the
existing feeding history workflow. Returning after FeedingEvent creation,
editing or deletion must refresh both the detail state and overview summary.
Quick Feeding submissions must also invalidate the overview state.

Reminder presentation must be available in English and German, must not open a
blocking dialog automatically and must not request system-notification
permissions.

## QR Codes

The application must allow the user to:

- generate a unique QR ID for a Box
- generate a QR code from the Box ID
- display the QR code
- export the QR code as PNG
- save/download the QR image
- print the QR code
- scan a QR code
- allow the camera light to be switched on and off while scanning when the
  active camera supports it
- validate TerraManager QR identifiers
- resolve a scanned QR identifier to a Box
- open a scanned Box in the dedicated Feeding Mode
- resolve a Feeding Mode scan to the Box's currently assigned active Animals
- report invalid QR codes
- report valid but unknown TerraManager QR identifiers

The QR code must contain only the stable Box identifier.

Generated QR images are derived data and do not need to be persisted in the
domain database or portable backups.

## Settings

The application must allow the user to:

- use the operating system theme
- explicitly select Light mode
- explicitly select Dark mode
- select an application accent color
- persist appearance settings between application restarts
- follow the operating-system language by default
- explicitly select English or German
- apply language changes without restarting the application
- persist the selected language between application restarts
- fall back to English when the system language is unsupported

Appearance, language and overview-order settings must be included in portable
TerraManager backups.

## Persistence

Core application data must be stored locally.

Data must survive normal application restarts.

The MVP does not require cloud synchronization.

Core domain data is stored with Drift/SQLite.

Application-owned Box and Animal pictures are stored persistently through
MediaAssets in the local Drift database.

New and replaced pictures use normalized `.webp` filenames and the
`image/webp` MIME type. Existing MediaAssets retain their original bytes and
metadata until the user replaces the picture.

Overview thumbnails, detail pictures and the full-screen viewer must display
both normalized WebP media and previously supported legacy image formats.

Appearance, language and overview-order preferences are stored separately
through `shared_preferences`.

Domain data, Box and Animal pictures, appearance preferences and manual language
selection must survive normal application restarts or browser reloads on
validated platforms.

## Platform Targets

The MVP targets:

- Android
- Web

iOS is planned but is not required to be validated before the current MVP
milestones can continue.

Android and Web are validated platforms.

## Backup and Restore

The application must allow the user to:

- create a portable backup of local TerraManager data
- export Boxes, including optional dimensions
- export Animals
- export FeedingEvents
- export Box pictures
- export Animal pictures
- export appearance, language and overview-order settings
- select an existing TerraManager backup
- inspect backup metadata before restore
- restore a compatible TerraManager backup
- validate a backup before modifying existing data
- validate domain relationships
- validate lifecycle state
- validate referenced media
- validate permanent Box QR identifiers
- create a safety backup before destructive database replacement
- explicitly confirm replacement of existing local data
- restore Box dimensions
- restore persistent Box pictures
- restore persistent Animal pictures
- restore appearance, language and overview-order settings
- restore older backups without a language field using the System setting
- restore older backups without a Box sort-order field using ascending Box
  number
- map legacy oldest/newest-created Box sort values to ascending/descending Box
  number
- restore older backups without an Animal sort-order field using
  oldest-created Animal first
- export and restore optional per-Animal feeding reminder configuration
- restore older backups without reminder fields with reminders disabled

Backup Format Version 2 must support archives containing legacy PNG/JPEG media,
normalized WebP media or both at the same time. Export and restore must preserve
the original media bytes without recompression. Restore must recreate a MIME
type matching the portable filename, while known stored MIME metadata takes
precedence over a stale filename during export.

The backup format must be independent from the raw SQLite database file.

Backups must use an explicit backup format version that is independent from the
database schema version.

Generated QR images are not included because they can be recreated from the
permanent Box `qrId`.

Portable backup media references must not expose device-specific filesystem
paths, browser Blob URLs or internal MediaAsset IDs.

The initial restore implementation uses full replacement.

Merging backup data with existing application data is not required for the MVP.

Backup Format Version 2 is the current export format and must support manual
transfer between the currently validated platforms. Backup Format Version 1
remains supported for backward-compatible restore:

```text
Android → Android
Web → Web
Android → Web
Web → Android
```

Restore must fail safely when validation or transactional database replacement
fails.
