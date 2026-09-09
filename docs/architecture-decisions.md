# Architecture Decision Records

## ADR-001: Local-first architecture

**Status:** Accepted

**Date:** 2026-08-19

### Context

TerraManager is intended for managing terrarium boxes, animals, feeding events and, later, sensors.

The application should function reliably near the physical terrariums. A permanent internet connection cannot be assumed.

### Decision

TerraManager is developed as a **local-first application**.

Primary application data is stored locally.

Core functionality must work without an internet connection.

Cloud synchronization may be added later.

### Consequences

Advantages:

- application works offline
- QR codes can be resolved locally
- changes can be saved immediately
- MVP has no dependency on an external server
- local data sovereignty

Disadvantages:

- data is initially tied to the local device or browser profile
- synchronization between devices is not currently available
- backup and restore must be addressed separately

---

## ADR-002: QR code as stable box identifier

**Status:** Accepted

**Date:** 2026-08-19

### Context

Each physical box should be permanently labeled with a QR code.

Animals and other data associated with the box may change over time.

A physical QR label should therefore not need to be recreated whenever application data changes.

### Decision

The QR code contains only a permanent unique identifier for the box.

Format:

```text
TM:BOX:<UUID-v4>
```

The UUID is generated when the box is created and remains unchanged.

The actual box, animal and feeding data is stored in the local database.

Scanning the QR identifier resolves the corresponding box through BoxRepository.

### Consequences

Advantages:

- physical QR labels remain valid after data changes
- QR payload is small
- database schema can evolve independently
- application data is not embedded in the QR code
- QR codes can be permanently attached to physical enclosures

Disadvantages:

- QR code alone contains no useful animal data
- loss of the local database cannot be repaired from the QR code alone

---

## ADR-003: Drift and SQLite as local database

**Status**: Accepted

**Date**: 2026-08-19

### Context

TerraManager requires relational, persistent local storage.

Current relationships include:

```text
Box 1 ─── n Animal

Animal 1 ─── n FeedingEvent
```

Future functionality may add additional entities such as sensors.

### Decision

TerraManager uses SQLite through Drift.

Drift provides:

- typed Dart access
- relational queries
- foreign keys
- schema migrations
- generated database code
- native and Web-compatible persistence

Current entities are:

```text
Box
Animal
FeedingEvent
MediaAsset
```

Sensors are planned but not yet implemented.

### Consequences

Advantages:

- domain relationships map naturally to a relational model
- local persistent storage
- type-safe Dart API
- migration support
- suitable for future schema expansion

Disadvantages:

- schema migrations must be maintained
- generated code must remain synchronized with table definitions
- Web requires an additional SQLite WASM setup

### Alternatives considered

**Isar**

Good Flutter integration, but the relational TerraManager data model favors Drift/SQLite.

**Hive**

Suitable for simple key-value data but less appropriate for TerraManager's relational structure.

---

## ADR-004: SQLite WASM persistence on Web

**Status**: Accepted

**Date**: 2026-08-27

### Context

The native Drift configuration works on Android but cannot be used directly when Flutter is compiled for Web.

TerraManager also requires persistent browser-side data after a page reload.

### Decision

The Web version uses Drift with SQLite WASM.

Required Web assets include:

```text
web/sqlite3.wasm
web/drift_worker.dart
web/drift_worker.dart.js
```

AppDatabase configures DriftWebOptions with the SQLite WASM file and Drift worker.

The worker is compiled with:

```text
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
```

### Consequences

Advantages:

- same relational Drift model can be used on Android and Web
- browser data persists across normal page reloads
- repository API remains platform-independent

Disadvantages:

- additional Web build assets are required
- sqlite3.wasm must remain compatible with the resolved sqlite3 package
- clearing browser site data can remove the database

---

## ADR-005: Platform-specific QR operations behind services

**Status**: Accepted

**Date**: 2026-08-27

### Context

QR codes must be generated, saved and printed on multiple target platforms.

Direct platform-specific implementation in presentation widgets would make the UI difficult to test and maintain.

### Decision

Platform-related QR functionality is separated behind interfaces and services.

Current responsibilities include:

```text
QrExporter
    │
    └── generate PNG bytes

QrStorage
    │
    └── persist or download PNG

QrPrinter
    │
    └── create printable document and invoke printing
```

The UI communicates with these abstractions rather than directly implementing file or print operations.

### Consequences

Advantages:

- presentation layer remains platform-neutral
- services can be replaced by fakes in tests
- Android and Web storage behavior can differ without changing UI code
- printing and export logic are reusable

Disadvantages:

- additional abstraction and files
- platform-specific implementations still require manual validation

---

## ADR-006: Store UI preferences outside the domain database

**Status:** Accepted

**Date:** 2026-09-01

### Context

TerraManager supports user-selectable appearance settings:

- System, Light and Dark theme modes
- predefined accent colors

TerraManager also supports a user-selectable application language:

- System language
- English
- German

Animal presentation also has a user-selectable primary name:

- common name first
- Latin name first

The Box Overview has a user-selectable order:

- ascending or descending natural Box number

The Animal Overview has a user-selectable order:

- oldest or newest creation time first
- displayed primary name A–Z or Z–A
- oldest or youngest Animal first
- newest or oldest latest FeedingEvent first

These values are application preferences rather than terrarium domain data.

Storing them in the Drift database would couple UI preferences to the relational
domain schema and could require unnecessary database migrations for preference
changes.

### Decision

Appearance, language, Animal name-order and overview sort-order preferences are
stored through `shared_preferences`.

The Drift/SQLite database remains responsible for domain data such as:

```text
Box
Animal
FeedingEvent
MediaAsset
```

The application settings controller loads and persists appearance, language,
Animal name-order and overview sort-order preferences and notifies the
application when they change.

The application theme is regenerated immediately from the selected theme mode
and accent color. The application locale changes immediately when a language is
selected.

### Consequences

Advantages:

- UI preferences remain separate from domain data
- no Drift schema migration is required for UI-only settings
- settings can be applied immediately
- simple persistence on Android and Web
- invalid stored values can safely fall back to application defaults

Disadvantages:

- application state is persisted through more than one storage mechanism
- application preferences are still local to the current device/browser profile
- clearing application/browser data may reset the preferences

Default values are:

```text
ThemeMode.system
Accent = TerraManager green
Language = System
AnimalNameOrder = Common name first
AnimalSortOrder = Oldest created first
BoxSortOrder = Box number ascending
```

The System language follows the operating-system locale. Unsupported locales
fall back to English.

---

## ADR-007: Portable versioned backup format

**Status:** Accepted

**Date:** 2026-09-02

### Context

TerraManager stores important local-only data including Boxes, Animals,
FeedingEvents, lifecycle history and animal pictures.

The local-first architecture means this data currently exists only on the
current device or browser profile.

Copying the raw SQLite database would tightly couple backups to a specific
database schema and platform implementation.

Android and Web use different underlying platform persistence implementations,
so portable backups must not depend on platform-specific paths or browser
identifiers.

### Decision

TerraManager uses a portable versioned backup archive rather than exposing the
raw SQLite database as the backup format.

The backup file uses the `.tmbackup` extension.

The initial format contains:

```text
manifest.json
data.json
settings.json
media/
```

The backup format has its own `backupFormatVersion`.

This version is independent from the Drift `databaseSchemaVersion`.

Domain records are serialized into portable data structures.

Local operating-system media paths are not preserved directly. Media files are
included in the archive and referenced through portable backup media
identifiers.

Generated QR images are excluded because they can be regenerated from the
permanent Box `qrId`.

Restore version 1 uses full replacement rather than merge semantics.

Before destructive restore:

- the selected backup is validated
- a backup of the current state is created
- explicit user confirmation is required
- replacement may begin

### Implementation update – Backup Format Version 2

TerraManager 0.7.x creates Backup Format Version 2 backups. Version 2 extends
portable Box data with optional width, height, depth and Box picture media under
`media/boxes/`.

Backup Format Version 1 remains supported for backward-compatible restore.
Missing Version 2 Box fields from a Version 1 backup are mapped to `null`.

TerraManager 0.10.0 adds the optional application language to `settings.json`.
This is a backward-compatible extension of Backup Format Version 2. Older
backups without the field restore the System language setting.

TerraManager 0.11.0 adds the optional Animal name-order preference to the same
file. This is also backward compatible; older backups restore common name first.

TerraManager 0.13.3 adds the optional Box sort-order preference. TerraManager
0.14.1 limits new values to ascending or descending Box number. Missing and
legacy oldest-created values map to ascending; legacy newest-created values map
to descending. The extension remains backward compatible without a new
backup-format version.

TerraManager 0.13.4 adds the optional Animal sort-order preference with the same
compatibility strategy. Older backups restore oldest-created Animal first.

### Consequences

Advantages:

- backups can be transferred between Android and Web
- backup compatibility can evolve independently from Drift schema migrations
- media is restored into TerraManager's persistent MediaAssets storage
- QR identifiers remain stable
- backups are not tied to device-specific filesystem paths
- future application versions can implement explicit backup migration logic

Disadvantages:

- serialization and restore logic must be maintained separately from Drift
- media increases backup file size
- cross-version compatibility must be tested
- destructive restore requires additional safety handling

### Out of Scope for Version 1

- merge restore
- selective restore
- incremental backups
- cloud backup
- automatic scheduled backup

---

## ADR-008: Store application media in persistent database-backed MediaAssets

**Status:** Accepted

**Date:** 2026-09-03

### Context

Earlier TerraManager versions stored Animal pictures using the path returned by
`image_picker`.

This approach is not sufficiently reliable as long-term application storage.

On mobile platforms, a selected file path may refer to storage whose lifecycle
is not controlled by TerraManager.

On Web, image selection may expose browser-specific temporary references that
are unsuitable as persistent application identifiers.

This also complicates portable backup and restore because local paths cannot be
transferred reliably between Android and Web.

### Decision

TerraManager stores application-owned media through a dedicated Drift table:

```text
MediaAsset
├── id
├── fileName
├── mimeType
├── data
├── createdAt
└── updatedAt
```

Box and Animal pictures reference this table through:

```text
Box.pictureMediaId
Animal.pictureMediaId
```

The actual media bytes are stored persistently in the local Drift/SQLite
database.

Pictures selected from the device gallery and pictures newly captured through
the device camera enter the same persistence flow. TerraManager reads the
returned `XFile` bytes and stores them as a new `MediaAsset`; it does not retain
the temporary picker path as the application-owned image.

Before a newly selected or captured picture reaches a form, the shared picture
selection flow opens an in-app cropping route. Source orientation is normalized
before the free-form crop is calculated. Only a confirmed crop returns new
image bytes to the form. Cancelling the route returns no result, so an existing
picture and the form's unsaved-change state remain untouched.

The cropping UI operates on in-memory bytes and is shared by Android and Web.
Its output continues through the same `MediaAsset` persistence path as an
uncropped picture did previously.

After the crop is confirmed, the shared picture optimizer limits the longest
edge to 1920 pixels without upscaling and encodes the result as WebP with
quality 82. Stored filenames are normalized to `.webp`, and the corresponding
MIME type is `image/webp`. The encoder output signature is checked before the
optimized bytes are accepted.

All four create and edit forms expose the same normalization phase as an
explicit processing state. Picture selection, removal and saving are disabled
until it completes, and the asynchronous handlers reject re-entry independently
of the widget state. Camera and Gallery therefore converge on one processing
path without allowing parallel imports or duplicate save operations.

Existing `MediaAssets` are not rewritten automatically. JPEG, PNG and other
previously supported pictures continue to be displayed and exported in their
stored format. Replacing one of those pictures sends the replacement through
the new WebP optimization flow. This avoids a database migration, prolonged
startup work and destructive recompression of existing user media.

For a replacement, the new MediaAsset is created before the Box or Animal
reference changes. The new reference and deletion of the superseded MediaAsset
run in the same Drift transaction. If normalization or any database operation
fails, the old reference and media bytes remain committed and readable.

`Animal.picturePath` remains temporarily available only for migration and
backward compatibility with data created before persistent media storage was
introduced.

A startup migration service attempts to import readable legacy pictures into
`MediaAssets`.

If a legacy picture cannot be read, the existing path is preserved rather than
causing database migration or application startup to fail.

Portable backup files do not preserve `MediaAsset.id`.

Backup export and restore share one media-format mapping. Export retains a
supported filename extension when it agrees with the stored MIME type. If known
MIME metadata and a stale filename disagree, the MIME type determines the
portable extension. Restore derives the recreated MediaAsset MIME type from the
portable filename. Unknown legacy media keeps the existing `.img` and
`application/octet-stream` fallback.

This mapping transports legacy PNG/JPEG media and normalized WebP media in the
same Backup Format Version 2 archive without decoding or recompressing the
stored bytes.

Pictures are exported as portable archive entries such as:

```text
media/animals/17.jpg
```

During restore, new `MediaAsset` records are created and their generated IDs are
assigned to `Box.pictureMediaId` or `Animal.pictureMediaId` as appropriate.

Box pictures are exported under portable paths such as:

```text
media/boxes/4.jpg
```

## Consequences

Advantages:

- Box and Animal pictures are owned by TerraManager rather than temporary external paths
- Android pictures remain available after application restart
- Web pictures remain available after browser reload
- backup and restore use the same media persistence model on Android and Web
- cross-platform backup transfer does not depend on local filesystem paths
- Box and Animal pictures use the same persistent media infrastructure
- picture selection and cropping use one shared Android/Web workflow
- new and replaced pictures use bounded dimensions and lossy WebP compression
- existing pictures and older portable backups remain compatible
- mixed legacy and WebP backups preserve their original media bytes and types
- cancelling a crop cannot accidentally replace the current picture
- processing progress is visible and repeated picture/save actions are ignored
- replacing a picture cannot leave a partial domain/media update
- database transactions can restore domain records and media atomically

Disadvantages:

- binary media increases the size of the local database
- large image collections may increase backup size and database storage use
- decoding and cropping large source pictures temporarily uses additional
  memory
- WebP encoding depends on the target platform implementation and may take a
  short time after crop confirmation
- deleting or replacing records must also manage referenced MediaAssets
- legacy picture migration requires temporary compatibility logic

---

## ADR-009: Preserve source ordering with contextual detail navigation

**Status:** Accepted

**Date:** 2026-09-04

### Context

Animal and Box detail pages can be opened from different ordered collections.

Animal details may originate from:

- Active Animals
- Animal History
- Animals assigned to one Box

Box details may originate from the Box Overview.

A detail page cannot reconstruct the user's original navigation context by
querying all database records. Such a query could include unrelated records,
lose the source-specific ordering or mix active and archived Animals.

The detail page must also keep the current record identifiable while its data is
reloaded after editing or another detail action.

### Decision

TerraManager passes an optional immutable `DetailNavigationContext` to a detail
page when that page is opened from an ordered collection.

The context contains:

```text
DetailNavigationContext
├── recordIds
├── currentRecordId
├── source
└── sourceBoxId (Box-specific Animals only)
```

The supported sources are represented by `DetailNavigationSource`:

```text
activeAnimals
archivedAnimals
boxAnimals
boxes
```

The context validates that:

- the ordered record list is not empty
- record IDs are unique
- the current record belongs to the ordered record list
- a Box-specific Animal context contains its source Box ID
- other context types do not contain a source Box ID

Animal and Box detail pages use the previous or next ID from this context when a
horizontal swipe crosses the navigation threshold. They update the record shown
by the existing route rather than pushing a new detail route for every swipe.

First and last records form explicit boundaries. A swipe at a boundary keeps the
current record displayed.

After an Animal edit or lifecycle change, its navigation context is retained
only if the Animal still belongs to the original source collection. A missing
adjacent Box is removed from the in-memory navigation context without replacing
the currently displayed Box.

Navigation context is optional. Detail pages opened without one keep their
normal non-swipe behavior.

### Consequences

Advantages:

- detail navigation follows the ordering the user actually selected
- active, archived and Box-specific Animal collections remain separate
- detail actions always target the currently displayed record
- editing can refresh a record without losing its current identity
- Back returns through one detail route to the original overview
- the navigation model is shared by Animal and Box features
- existing non-swipe callers remain compatible

Disadvantages:

- the context represents a snapshot and can become stale when records change
- detail pages must handle records that disappear or leave their source
- the current context exists only in the active navigation route and is not
  restored after a complete application restart or browser reload
- horizontal gestures require coordination with other interactive detail
  content

---

## ADR-010: Store grouped feedings as atomic per-Animal events

**Status:** Accepted

**Date:** 2026-09-05

### Context

Feeding Mode starts with a physical Box rather than one Animal. Scanning the
Box QR code can therefore produce one or several active Animals that were fed at
the same time.

The existing domain model stores feeding history as individual FeedingEvents,
with every event belonging to exactly one Animal. Introducing a separate group
feeding entity would add a new schema and backup-format concept even though the
group is needed only while the user records the action.

Writing the selected Animals through independent, unrelated inserts would also
allow a partial result if one insert failed. Retrying after such a failure could
then create duplicate feeding history.

### Decision

TerraManager keeps FeedingEvent as the only persisted feeding model.

Feeding Mode resolves the scanned Box to its currently assigned active Animals
and passes the selected Animal IDs, one common timestamp and one optional common
note to `FeedingRepository.addFeedings`.

The repository validates that:

- at least one Animal ID is supplied
- the Animal IDs do not contain duplicates

It then creates one normal FeedingEvent for every selected Animal inside one
Drift transaction:

```text
Selected Animal IDs
        │
        ▼
FeedingRepository.addFeedings
        │
        ▼
Single database transaction
        │
        ├── FeedingEvent for Animal A
        ├── FeedingEvent for Animal B
        └── FeedingEvent for Animal C
```

If any insert fails, the transaction rolls back all events from that grouped
feeding.

The presentation layer prevents a second save while the first transaction is in
progress. After a successful transaction, it closes the Box-specific feeding
route and restarts the scanner.

### Consequences

Advantages:

- grouped feedings cannot remain partially written
- existing feeding history and latest-feeding queries need no special handling
- existing edit, delete, backup and restore workflows continue to use normal
  FeedingEvents
- no database schema or backup-format migration is required
- one-Animal and multi-Animal feedings share the same workflow
- repeated save actions cannot create duplicate events while a save is running

Disadvantages:

- the database does not preserve a permanent relationship between events that
  were created by the same grouped feeding
- changing a grouped feeding later requires editing its individual events
- every selected Animal currently receives the same timestamp and note

---

## ADR-011: Store feeding reminder configuration on each Animal

**Status:** Accepted

**Date:** 2026-09-08

### Context

Feeding intervals differ between individual Animals. A reminder must therefore
be configurable independently instead of being a global application setting.

Some existing Animals have no FeedingEvents. Deriving an initial reminder only
from Animal creation time or an empty feeding history could make those Animals
appear overdue immediately when the feature is enabled.

Archiving is reversible, so reminder preferences should remain available if an
Animal is restored later. At the same time, archived Animals must not create
active reminders.

### Decision

TerraManager stores two nullable fields directly on each Animal:

```text
feedingReminderIntervalDays
feedingReminderBaseline
```

The pair has two valid states:

```text
Disabled: interval = null, baseline = null
Enabled:  interval > 0, baseline = enable timestamp
```

The presentation and repository layers enforce this invariant. Enabling a
reminder captures the current time through an injectable clock. Editing the
interval of an already enabled reminder preserves the baseline; disabling the
reminder clears both fields.

Archive and restore operations do not modify the pair. Reminder queries are
responsible for excluding archived Animals.

The fields are optional in portable Animal backup records. Existing backups
that omit them decode to the disabled state, while incomplete or non-positive
configurations are rejected during validation.

### Consequences

Advantages:

- every Animal can use an independent feeding interval
- reminder configuration persists with the Animal across restarts and archive
  transitions
- newly enabled reminders start from a predictable baseline
- due-state calculations use the latest feeding when present and the baseline
  only when no feeding history exists
- older backups and migrated databases naturally default to disabled reminders

Disadvantages:

- two nullable columns represent one logical configuration and require
  cross-field validation
- the baseline is stored even after FeedingEvents exist because deleting the
  latest event may make it relevant again
- archive suppression belongs to reminder queries rather than the persisted
  configuration itself

---

## ADR-012: Derive feeding reminder state from current history

**Status:** Accepted

**Date:** 2026-09-08

### Context

A feeding reminder changes when its baseline, interval or FeedingEvent history
changes. Persisting another `dueAt` or `isDue` field would duplicate derived
information and require every feeding creation, edit, deletion and backup
restore to keep that duplicate state synchronized.

Loading the latest FeedingEvent separately for every Animal would avoid stored
derived state, but would create an N+1 query pattern in the Animal Overview.
Due-state tests also need a deterministic current time instead of depending on
the system clock.

### Decision

TerraManager calculates reminder state on demand. For every active Animal with
a valid enabled reminder:

```text
referenceAt = latest FeedingEvent.fedAt ?? feedingReminderBaseline
dueAt = referenceAt + feedingReminderIntervalDays
isDue = evaluatedAt >= dueAt
```

Database timestamps are converted to the injected clock's UTC or local
representation before the state is returned. This preserves each absolute
moment while avoiding platform-dependent timestamp representations.

If no FeedingEvent exists, the configured baseline is used. If feeding history
exists, its latest event remains authoritative even when it predates reminder
activation. Enabling a reminder can therefore immediately produce a due state
for an Animal whose most recent feeding is older than the configured interval.

The service loads configured active Animals once and obtains their latest
feeding timestamps through one grouped `MAX(fedAt)` query. It receives the
current time through an injectable clock and uses one captured value for every
Animal in the same calculation. Results are sorted by `dueAt` and Animal ID for
stable, most-overdue-first presentation.

The service keeps no cache. Calling it after a FeedingEvent is created, edited
or deleted therefore recalculates from the current database state.

### Consequences

Advantages:

- reminder state cannot drift away from FeedingEvent history
- no new schema or portable backup field is required
- creation, editing, deletion and restore use the same calculation path
- bulk reminder loading uses a fixed number of queries rather than one query
  per Animal
- an injected clock makes exact boundary behavior deterministic in tests
- the calculated state already provides the data required by the reminder UI

Disadvantages:

- the calculation must run again whenever a screen needs refreshed state
- a screen that remains open across a due boundary must explicitly refresh at
  that boundary or when it becomes active again
- the database query and calculation service must continue to use identical
  eligibility rules for active, configured Animals

---

## ADR-013: Present feeding reminders as derived, non-modal UI state

**Status:** Accepted

**Date:** 2026-09-08

### Context

Due Animals must be visible without interrupting normal application startup or
navigation. Reminder state also changes through both the Animal feeding history
and the Box-based Quick Feeding workflow. A presentation cache without explicit
invalidation could therefore show an Animal as overdue after a new feeding was
already stored.

### Decision

The Animal Overview loads active Animals and derived due reminder states
together. It renders a non-modal summary only when at least one Animal is due,
orders entries using the reminder service's most-overdue-first result and marks
the corresponding rows in the normal Animal list.

Selecting a summary entry opens the existing Animal detail route with its
normal contextual navigation. Animal details calculate one reminder state and
show either a due or scheduled status card with the calculated due timestamp.
Selecting that card opens the existing feeding history workflow.

Returning from feeding history recalculates the latest feeding and reminder
state. Returning from Animal details reloads the overview while preserving its
scroll position. Quick Feeding reports a successful write to the application
shell, which recreates the overview data source before the Animals tab is shown
again.

All reminder text is localized through the existing ARB catalogs. The in-app
presentation neither opens an automatic dialog nor requests operating-system
notification permissions.

### Consequences

Advantages:

- due Animals are prominent without blocking the user
- the summary, list marker and detail card use the same calculation service
- existing detail navigation and feeding workflows remain reusable
- normal and Quick Feeding paths invalidate stale reminder presentation
- system-notification permissions remain outside the local-only milestone

Disadvantages:

- the overview performs reminder queries whenever it is reloaded
- a due boundary crossed while a screen remains continuously visible still
  requires a later screen reload to appear
- the application shell must propagate successful Quick Feeding changes to the
  Animals page

---

## ADR-014: Adopt a permanent cross-platform application identity

**Status:** Accepted

**Date:** 2026-09-09

### Context

The Flutter project was originally created with
`com.example.flutter_application_1` and `flutter_application_1` placeholders.
Those values still identified the Android package and appeared in prepared Web
and desktop platform metadata. Android application IDs become part of the
installed application's identity and update path, so a stable identifier is
required before v1.0 and production signing.

The Web project also used Flutter's default title, description, colors and
icons, which did not identify TerraManager when installed as a progressive Web
application.

### Decision

TerraManager adopts the following permanent identifier:

```text
com.codefrog.terramanager
```

Android uses this value as both namespace and application ID. Prepared Apple
and Linux projects use the matching bundle or application identifier. Windows,
Linux and macOS user-facing names and executable metadata use TerraManager
instead of Flutter template values.

The Web manifest and HTML metadata use the TerraManager name, the local-first
application description and dark green `#0B5D36` theme color. Web launcher and
maskable icons plus the favicon are derived from the existing TerraManager app
icon.

The identifier must not change after v1.0. Platform identity preparation does
not itself promote iOS, macOS, Linux or Windows to validated status.

### Consequences

Advantages:

- Android releases have a stable non-placeholder identity
- production signing can target the final application ID
- Web installation and browser metadata clearly identify TerraManager
- prepared platform projects no longer expose Flutter template identity
- automated regression tests protect identity and core metadata

Disadvantages:

- Android considers the new identifier a separate application
- builds through v0.14.1 cannot be updated in place
- existing users must export a portable backup, install the permanent-ID build
  and restore their data
- prepared but unsupported platform identity changes cannot be fully validated
  until suitable build environments are available
