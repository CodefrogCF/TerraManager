# Architecture Decision Records

## ADR-001: Local-first architecture

**Status:** Accepted
**Date:** 2026-08-19

### Context

TerraManager is intended for managing terrariums, animals, feeding events, and, later, sensors.

The application should function reliably, especially in the immediate vicinity of the terrariums. A permanent internet connection cannot be assumed in that environment.

### Decision

TerraManager will initially be developed as a **local-first application**.

Primary data will be stored locally on the respective device. The core features of the application should work without an internet connection.

Cloud synchronization may be added at a later stage.

### Consequences

**Advantages:**

* The application works offline.
* QR codes can be scanned without an internet connection.
* Changes can be saved immediately.
* The MVP has no dependency on an external server.
* Data privacy and data sovereignty initially remain entirely with the user.

**Disadvantages:**

* Data is initially tied to the respective device.
* Synchronization between multiple devices is not possible initially.
* Backup and recovery must be taken into account later.

---

## ADR-002: QR code as stable box identifier

**Status:** Accepted
**Date:** 2026-08-19

### Context

Each box should be permanently labeled with a QR code.

The data associated with a box may change over time. For example, its name, animal, notes, or feeding data may change.

Therefore, an already-attached QR code should not need to be recreated or reprinted every time a change is made.

### Decision

The QR code contains only a **permanent, unique identifier for the box**.

The actual box and animal data is not stored in the QR code.

Example:

TM:BOX:<UUID>

The UUID is generated once when a box is created and remains unchanged throughout the box's entire lifetime.

When scanned, the UUID is read and used to load the associated box from the local database.

### Consequences

**Advantages:**

* The QR code does not need to be reprinted after data changes.
* The QR code remains small and simple.
* The data structure can be extended independently of the QR code.
* Sensitive or extensive data is not stored directly in the QR code.
* QR codes can be permanently attached to physical boxes.

**Disadvantages:**

* Without access to the local database, the QR code itself contains no information about the box.
* If the local database is lost, the QR ID alone cannot restore the original data.

---

## ADR-003: Local database

**Status:** Accepted
**Date:** 2026-08-19

### Context

TerraManager requires local persistent data storage.

The data model contains several relational relationships:

* A box can contain multiple animals.
* An animal can have multiple feeding events.
* A box can have multiple sensors.

The database should be usable as consistently as possible across Android, iOS, and desktop/web-capable target platforms. Migrations and future extensions must be supported.

### Decision

TerraManager uses **SQLite through Drift** as its local database abstraction.

Drift provides a type-safe Dart interface for SQLite and enables the definition of relational tables, foreign keys, queries, and database migrations.

### Initial entities

The database will initially contain the following tables:

Box
Animal
FeedingEvent
Sensor

The relationships are:

Box 1 ─── n Animal

Animal 1 ─── n FeedingEvent

Box 1 ─── n Sensor

### Consequences

**Advantages:**

* The relational data structure fits the domain model.
* SQLite is local and well established.
* Foreign keys can ensure data integrity.
* Drift generates type-safe Dart code.
* Database migrations can be versioned.
* The database can be extended later.

**Disadvantages:**

* Slightly more initial effort than with simple NoSQL solutions.
* The database schema must be migrated when changes are made.
* SQLite may be over-engineered for very simple data structures.

### Alternatives considered

**Isar**

Isar would also be suitable due to its good Flutter integration. However, TerraManager's relational relationships favor SQLite/Drift.

**Hive**

Hive would be suitable for simple local key-value data. However, it is not considered the optimal foundation for TerraManager's relational relationships.

---

