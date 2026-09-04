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

These values are application preferences rather than terrarium domain data.

Storing them in the Drift database would couple UI preferences to the relational
domain schema and could require unnecessary database migrations for appearance
changes.

### Decision

Appearance preferences are stored through `shared_preferences`.

The Drift/SQLite database remains responsible for domain data such as:

```text
Box
Animal
FeedingEvent
MediaAsset
```

The application settings controller loads and persists appearance preferences
and notifies the application when they change.

The application theme is regenerated immediately from the selected theme mode
and accent color.

### Consequences

Advantages:

- UI preferences remain separate from domain data
- no Drift schema migration is required for appearance-only settings
- settings can be applied immediately
- simple persistence on Android and Web
- invalid stored values can safely fall back to application defaults

Disadvantages:

- application state is persisted through more than one storage mechanism
- appearance preferences are still local to the current device/browser profile
- clearing application/browser data may reset the preferences

Default values are:

```text
ThemeMode.system
Accent = TerraManager green
```

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

`Animal.picturePath` remains temporarily available only for migration and
backward compatibility with data created before persistent media storage was
introduced.

A startup migration service attempts to import readable legacy pictures into
`MediaAssets`.

If a legacy picture cannot be read, the existing path is preserved rather than
causing database migration or application startup to fail.

Portable backup files do not preserve `MediaAsset.id`.

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
- database transactions can restore domain records and media atomically

Disadvantages:

- binary media increases the size of the local database
- large image collections may increase backup size and database storage use
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
