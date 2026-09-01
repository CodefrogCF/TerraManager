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