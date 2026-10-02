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

Repository-managed Web assets include:

```text
web/sqlite3.wasm
web/drift_worker.dart
```

The compiled worker is generated before each Web build and is not committed.
This keeps bundled Dart runtime and dependency code out of the source tree and
allows the worker to be regenerated from the resolved toolchain.

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

The secondary **Scan a different Box** action is an explicit cancellation. It
closes the Box-specific route with a negative result, creates no FeedingEvent
and restarts the Feeding Mode scanner so another QR code can be scanned
immediately. The same action returns an empty scanned Box to the scanner.

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

---

## ADR-015: Require external production credentials for Android Release builds

**Status:** Accepted

**Date:** 2026-09-09

### Context

Android Release builds still used Flutter's temporary debug signing
configuration. A debug certificate is unsuitable as the permanent update
identity for production artifacts. Embedding a keystore or passwords in Gradle
files would expose credentials through version control, while requiring release
credentials during ordinary development would make Debug builds unnecessarily
fragile.

The permanent application identifier was introduced in `0.14.2+34`, but that
development build was still debug-signed. Android accepts an in-place update
only when the installed and replacement packages have compatible signing
certificates.

### Decision

The Android build reads the four required signing values from either the
ignored `android/key.properties` file or these environment variables:

```text
TERRAMANAGER_KEYSTORE_FILE
TERRAMANAGER_KEYSTORE_PASSWORD
TERRAMANAGER_KEY_ALIAS
TERRAMANAGER_KEY_PASSWORD
```

Environment variables take precedence over local properties. The keystore is
stored outside the repository, and `.jks`, `.keystore` and `.p12` files beneath
the Android project are ignored as a final safeguard. The committed
`android/key.properties.example` contains placeholders only.

The Release build type uses a dedicated `release` signing configuration and
never falls back to the debug key. A requested Release task fails during Gradle
configuration when a value or keystore file is missing. Debug configuration,
testing and builds continue without production credentials.

The first production-signed build establishes the certificate that must sign
later directly distributed updates. A user running the debug-signed permanent-
ID development build must perform a one-time backup, uninstall, install and
restore transition.

### Consequences

Advantages:

- production artifacts cannot be created accidentally with the debug key
- credentials remain outside tracked source files
- local ignored properties and CI-friendly environment variables share one
  signing path
- missing configuration produces an actionable error before packaging
- normal Debug development does not depend on access to production secrets
- static tests protect the intended configuration and ignore rules

Disadvantages:

- each authorized release environment needs the private key and four values
- losing a self-managed app-signing key prevents compatible direct updates
- compromised credentials require an explicit key-response and distribution
  decision
- debug-signed `0.14.2+34` installations require one final backup-based
  transition

---

## ADR-016: License TerraManager under GPL-3.0-or-later

**Status:** Accepted

**Date:** 2026-09-09

### Context

TerraManager should remain free to use, inspect and modify for private users.
The same public source may also be useful to commercial terrarium keepers and
businesses. Open-source licensing cannot prohibit commercial use, but the
project should prevent distributed proprietary derivatives from removing the
freedoms granted to their recipients.

The maintainer may later provide paid services, official distribution,
customization or separate commercial licence terms. Accepting outside
contributions without clear copyright terms could make consistent relicensing
impossible.

### Decision

TerraManager is distributed under the GNU General Public License version 3 or
any later version, using the SPDX identifier `GPL-3.0-or-later`. The repository
contains the complete GPLv3 text and identifies CodefrogCF as the 2026
copyright holder for the project notice.

Private and commercial use are allowed under the GPL. Anyone distributing the
application or a derivative must meet the licence obligations, including
preserving notices and providing corresponding source when required.

The GPL grant does not prevent the copyright holder from separately offering
services or alternative licence terms. Until a contributor agreement is
published, substantial external source, translation, artwork and documentation
contributions require prior agreement with the maintainer.

### Consequences

Advantages:

- private use, inspection, modification and sharing remain protected
- commercial users receive the same GPL rights
- distributed derivatives cannot become closed-source without separate terms
- paid support, official builds and a future commercial licence remain possible
- cautious contribution intake preserves the maintainer's relicensing options

Disadvantages:

- businesses cannot distribute proprietary derivatives solely under the GPL
- integrations with incompatible proprietary code may require separate terms
- contribution onboarding needs explicit copyright and licensing review
- dual licensing becomes harder if copyright is shared without suitable
  contributor agreements

---

## ADR-017: Pin reproducible public quality gates and keep signing private

**Status:** Accepted

**Date:** 2026-09-09

**Updated:** 2026-09-28 (Android Gradle dependency locks)

### Context

Release confidence previously depended on commands run manually on one Windows
development machine. Flutter, Java and dependency updates could change the
result without a recorded baseline. Android production signing must not expose
the private TerraManager key to public pull requests or ordinary CI jobs.

The Android build also reports a future Built-in Kotlin incompatibility for
resolved plugins that still apply the Kotlin Gradle Plugin. Enabling migration
flags before those plugins are compatible would not resolve the actual
dependency and could break builds.

### Decision

TerraManager pins Flutter 3.47.2 stable and Temurin Java 17 in a GitHub Actions
workflow. Third-party actions are referenced by complete commit hashes. Every
push and pull request verifies the committed dependency lock, generated
localizations, formatting, static analysis, the complete test suite, an
Android Debug APK and a Web Release build.

The committed `pubspec.lock` fixes Dart package versions. Strict Gradle
dependency locks fix the resolved Android app, plugin and plugin-buildscript
module versions in repository-owned files; settings plugin resolution has its
own lockfile. Flutter engine artifacts follow the pinned Flutter SDK. A
specific Kotlin transitive is excluded because Gradle resolves it differently
after loading a lock; the exception and its verification boundary are recorded
in `docs/toolchain-baseline.md`. Upgrades occur only in focused changes with
regression validation. The supported Gradle, Android Gradle Plugin and Kotlin
declarations and their upgrade procedure are recorded there as well.

Public CI does not receive production signing credentials and does not build a
Release APK or AAB. Those artifacts remain in the documented authorized local
release process. The current Built-in Kotlin compatibility flags remain false
until all resolved plugins support the migration.

### Consequences

Advantages:

- every push receives the same formatting, analysis, test and build checks
- the Flutter and Java baseline is visible and reviewable
- accidental dependency-lock drift fails before merge
- public contributions cannot access production signing material
- upstream Kotlin migration work is tracked without hiding warnings

Disadvantages:

- CI does not prove that private production signing credentials are available
- signed APK and AAB verification remains a manual release-owner task
- pinned toolchains and action commits require intentional maintenance
- plugin compatibility warnings remain until upstream releases are available

---

## ADR-018: Preserve primary pages while navigating by swipe

**Status:** Accepted

**Date:** 2026-09-14

### Context

TerraManager exposes Box Overview, Animal Overview and Settings as three
primary destinations. Navigation-bar taps previously changed an `IndexedStack`
index, but horizontal gestures were available only inside contextual detail
routes. Replacing the root pages with independently pushed routes or disposable
page instances would lose list scroll positions, recreate queries and risk
confusing root navigation with the established detail swipe context.

Keeping all pages mounted also means their floating action buttons coexist in
one route. Default Hero tags then collide when a detail route opens. Data
created through one retained page can additionally leave a sibling page's
already completed query stale unless the mutation is announced explicitly.

### Decision

The application shell remains the only owner of the current primary-page
index. It wraps the existing `IndexedStack` with a horizontal drag recognizer
and moves only to an adjacent index after a minimum distance or velocity. The
bottom navigation bar writes through the same selection method, and the
selected indicator is derived from that single index.

The horizontal recognizer participates in Flutter's gesture arena beside each
page's vertical scrollable. Short movements and vertical drags do not change
the page. Dialogs, menus, crop flows, full-screen media and detail pages are
pushed above the shell and therefore do not expose the root gesture. Existing
contextual detail navigation continues to use its own route-level gesture and
platform Back continues to pop only pushed routes.

The shell exposes localized semantics for the current page and navigation
region. `Ctrl+Page Up` and `Ctrl+Page Down` provide adjacent keyboard
navigation without taking ordinary arrow keys away from lists and controls.
The Box and Animal overview floating actions use distinct Hero tags.

Successful Animal creation from Box details increments an Animal data revision
owned by the shell. The retained Animal Overview observes that revision,
reloads its query and restores its current scroll offset. This keeps sibling
data current without replacing the page state.

### Consequences

Advantages:

- swipe, tap and keyboard input share one deterministic page order
- overview scroll, sorting and Settings state survive primary-page changes
- each primary page and its subscriptions are created only once per data reset
- root and contextual detail swipe gestures remain independent
- cross-page Animal creation is visible without an application restart

Disadvantages:

- sibling data mutations need an explicit revision or equivalent notification
- retained pages continue to consume their normal in-memory state while hidden
- new root-page floating actions require unique Hero tags

---

## ADR-019: Store extended Animal characteristics as optional text

**Status:** Accepted

**Date:** 2026-09-14

### Context

Animal records need lightweight space for origin or habitat, weight, shedding,
rest or dormancy periods and temperature zones. Histories, measurements,
calculations and reminders would require separate domain models and workflows
that are outside the v1.4.0 scope. Existing databases and portable backups must
continue to work without synthetic profile content.

### Decision

Schema Version 9 adds five nullable text columns to Animal. New Animal and Edit
Animal use one shared expandable form section, trim entered values and persist
empty fields as `null`. Edit Animal opens the section automatically when any
saved value exists. Animal details render the section and each labeled row only
when corresponding non-empty content is present.

Portable Backup Format Version 2 adds matching optional string keys. Missing
keys from older Format 1 or Format 2 backups map to `null`; a present non-string
value fails validation. A populated v8 migration verifies that existing domain
rows remain unchanged.

### Consequences

Advantages:

- users can record the requested facts without complex setup
- empty profiles add no detail-page space or migration placeholders
- one widget keeps New and Edit behavior aligned
- the additive backup representation remains backward compatible

Disadvantages:

- weight has no normalized unit or history
- shedding and dormancy notes cannot trigger calculations or reminders
- future structured models will need an explicit migration from free-form text

---

## ADR-020: Render repository legal documents offline in Settings

**Status:** Accepted

**Date:** 2026-09-14

### Context

The Privacy Policy already renders bundled Markdown in Settings. Users must be
able to inspect the complete application license without network access, and a
second maintained license copy could drift from the authoritative repository
file. Legal pages should behave consistently under localization and large
accessibility text.

### Decision

Privacy Policy and License delegate to one legal-document page that supplies a
normal app bar, selectable Markdown, scrolling, load progress and localized
errors. The License entry sits directly below Privacy Policy and bundles the
root `LICENSE` file itself. A short localized preamble identifies TerraManager,
CodefrogCF and `GPL-3.0-or-later`; the complete GPLv3 text follows unchanged.
References remain part of the displayed document without invoking an external
application, matching the existing Privacy Policy behavior.

### Consequences

Advantages:

- the complete license remains available offline
- repository and bundled license content cannot diverge
- legal pages share navigation, typography and accessibility behavior
- legal content never depends on external navigation

Disadvantages:

- the app package includes the full plain-text GPL document
- legal-document presentation changes now affect both pages

---

## ADR-021: Create independent records through overview quick actions

**Status:** Accepted

**Date:** 2026-09-15

### Context

Common Animal and Box operations should be available from overview entries on
touch and pointer platforms. Duplication must accelerate similar record setup
without sharing identity, media ownership, lifecycle state or historical events
that belong to the source.

### Decision

One shared context-menu region maps long press and secondary click to localized
record-specific actions. Each action delegates to the same repository and
confirmation workflow used by its full page and refreshes the originating
overview when it completes.

Duplication is transactional. A Box receives a new database ID and generated QR
identifier; an Animal receives a new database ID and selected active Box. Both
copy reusable profile fields and picture bytes into independent records, reset
lifecycle state to active and clear archive metadata. Animal FeedingEvents are
not copied. Assigned Animals are not copied with a Box. No persistent
source-to-duplicate relation is stored.

### Consequences

Advantages:

- touch and pointer users reach frequent actions without opening details first
- duplicates can be edited or deleted independently from their sources
- permanent Box QR identity remains unique
- existing backup and lifecycle invariants continue to apply

Disadvantages:

- context menus expose more actions in a compact surface
- users must choose a destination Box before duplicating an Animal
- intentionally excluded history must be recreated manually when needed

---

## ADR-022: Generate selected Box QR documents locally before saving

**Status:** Accepted

**Date:** 2026-09-15

### Context

Users need individual Box QR images, one transportable ZIP archive and printable
A4 sheets. All formats must select from the same active and archived Boxes,
retain stable QR payloads and avoid extra device permissions or partial saved
documents.

### Decision

The three Settings actions reuse one checklist with all Boxes selected initially
and explicit Select all, Clear and per-Box opt-out controls. Individual export
uses the established PNG generator. ZIP export collects complete PNG results in
memory. PDF export draws vector QR codes on exact A4 pages with fixed margins,
automatic pagination, safe labels and integer sizes from 6 mm to 20 mm.

ZIP and PDF generation must finish successfully before `FileSaver.saveAs` opens
the operating-system destination dialog. Generation failures produce no file,
and save-dialog cancellation produces no success message. The workflow remains
offline and adds no broad storage, media or network permission.

### Consequences

Advantages:

- one selection model keeps the three export results consistent
- complete in-memory generation prevents unnoticed partial ZIP or PDF output
- vector PDF codes preserve print geometry across supported sizes
- the operating system controls the destination without unrestricted storage
  access

Disadvantages:

- large selections temporarily occupy memory while an archive or PDF is built
- PDF label space requires deterministic truncation for long names
- physical scan quality still depends on printer, paper and camera conditions

---

## ADR-023: Store stable Animal taxonomy and derive overview groups

**Status:** Accepted

**Date:** 2026-09-15

### Context

Animals need a useful broad classification with optional detail that survives
editing, duplication, migration and portable backup. Animal Overview must group
the same taxonomy without storing localized labels or a second independent
classification. Existing Animals and legacy backups have no taxonomy values.

### Decision

Schema Version 10 stores one required `AnimalCategory` and one nullable
`AnimalSubcategory`. New and migrated records default to `other` without a
subcategory. Stable values cover Amphibian, Reptile, Arachnid, Insect,
Myriapod, Crustacean, Mollusc, Other invertebrate and Other. Each detailed value
belongs to exactly one primary category; `otherSpider` covers spiders outside
the separately represented tarantula group. Categories without defined detail
accept no subcategory.

One shared form control clears an incompatible detail value when its category
changes. Repository and Backup Format Version 2 validation enforce the same
compatibility table. Missing taxonomy keys from Format 1 and older Format 2
backups use the migration fallback, while unsupported, localized or
incompatible present values fail validation.

Category overview groups are derived from current Animal records and enabled by
an independent persistent toggle beside the sort control. Primary groups always
follow the stable category order. A category displays subcategory headings only
when at least one contained Animal has a subcategory. Named headings sort by
localized text; Other and Not specified remain last. The selected regular
creation, displayed-name, age or latest-feeding order applies inside every final
group, with database ID as the final tie breaker. Legacy Category sort
preferences enable grouping and migrate to the matching displayed-name order.
Contextual navigation uses the flattened visible order.

### Consequences

Advantages:

- stored and portable values remain independent from the selected language
- form, validation, backup and grouping share one compatibility definition
- existing data upgrades without guessed classifications
- grouped rows retain existing thumbnails, reminders and quick actions
- flat and grouped views share the same four regular sort criteria
- every Issue #127 primary category participates in overview grouping

Disadvantages:

- users must classify newly created Animals
- changing the taxonomy later requires an explicit compatibility decision
- locale collation can change subcategory heading order between languages
- one additional portable Boolean preference records the category-view state

---

## ADR-024: Store temperature-zone notes on Boxes

**Status:** Accepted

**Date:** 2026-09-15

### Context

Temperature zones describe the physical enclosure shared by its assigned
Animals. Keeping the note on one Animal duplicates Box configuration and makes
the value disappear from the place where users manage the enclosure. Existing
Schema Version 10 databases and portable backups may already contain the value
on Animal records.

### Decision

Schema Version 11 adds nullable `Box.temperatureZones`. New Box and Edit Box
place the multiline field directly above Notes, and Box details omit the
section when it is empty. Current Animal forms, details, repository creation
and duplication no longer use the former Animal field.

The released Schema Version 10 snapshot remains unchanged and contains only the
Animal taxonomy addition from v1.7.0. This gives every v1.7.0 installation an
explicit v10 to v11 migration path instead of retroactively changing an
already released schema.

During database migration and backup restore, the first non-empty legacy value
by Animal ID seeds its assigned Box only when the Box has no temperature-zone
value. The old Animal column and backup key remain readable so existing data is
preserved, while current Box backup records carry the authoritative value.

The three Box QR export actions remain independent Settings actions. Their
shared checklist behavior is unchanged; the individual PNG description is
shortened and standard dividers separate PNG, ZIP and PDF.

### Consequences

Advantages:

- one enclosure value applies consistently to every assigned Animal
- the field appears in the Box workflow where the physical setup is managed
- old databases and backups upgrade without discarding recorded text
- the QR export presentation matches other grouped Settings actions

Disadvantages:

- a Box with several different legacy Animal values can retain only one
  authoritative migrated value
- the legacy Animal column remains until a later compatibility-breaking schema
  and backup revision can remove it safely

---

## ADR-025: Prioritize actionable Animal data and derive Box volume

**Status:** Accepted

**Date:** 2026-09-16

### Context

Animal details mixed scheduled reminders and feeding history below general
profile data, while assigned Boxes were plain text. Box ordering also needed
useful behavior for unnamed records and optional dimensions without storing a
second derived value.

### Decision

Animal details show only active due reminders above the picture and place the
latest FeedingEvent directly below the names. The assigned Box label uses the
same optional-name plus generated-number representation as selection controls
and opens the existing Box detail page. Missing legacy references remain plain
generated labels instead of blocking the Animal page.

Grouped overview headings derive plural English and German labels solely for
presentation; singular form/detail labels and stable taxonomy values remain
unchanged.

Schema Version 13 adds nullable `Animal.nighttimeTemperature`. It shares the
daytime temperature bounds and remains optional across forms, details,
duplication and Backup Format Version 2.

Box volume is calculated at sort time as `widthCm × heightCm × depthCm` only
when all dimensions exist. Incomplete values sort after calculated values in
both directions. Name sorting similarly places blank names last in both
directions. Stable Box IDs resolve all ties and both volume directions use
stable preference and backup strings.

### Consequences

- actionable feeding and navigation information is easier to reach
- no redundant volume value can become stale
- older databases, settings and backups keep their existing defaults
- every new capability remains local and requires no additional permission

---

## ADR-026: Render the project homepage from shared localized static content

**Status:** Accepted

**Date:** 2026-09-16

### Context

The GitHub Pages root previously exposed the long-form project documentation.
Issue #119 requires a focused application homepage at the repository project
path with complete German content, a maintainable English variant, downloads,
guides, legal pages and support links. The site must remain privacy-friendly,
work after direct navigation and avoid duplicating its complete structure for
every language.

### Decision

GitHub Pages continues to publish the repository `docs/` directory with Jekyll.
The configured `url` and `/TerraManager` `baseurl` are the source of every
internal asset and page URL. German `/` and English `/en/` entry pages contain
only language front matter; one `home` layout renders both from one localized
`_data/home.yml` content model. Long-form technical documentation moves to the
stable `/project-documentation.html` path without splitting it into per-issue
or per-release pages.

The homepage is static HTML and CSS. It uses bundled application media, system
fonts and a CSS device mockup. It loads no analytics, tracker, cookie banner,
remote font or external script. Download and support actions are ordinary
links to Google Play and GitHub. Privacy pages remain language-specific under
`/privacy/` and `/privacy/de/`; `/license/` publishes the authoritative
repository GPL text.

The shared layout owns semantic regions, one page heading, a keyboard skip
link, visible focus styles, descriptive image alternatives, language alternate
links, canonical URLs, favicon references and link-preview metadata. Static
paths allow each page to load directly without client-side routing.

### Consequences

- German and English changes share markup, responsive behavior and metadata
- GitHub Pages needs no runtime service, account system or additional device
  permission
- the project base path is explicit and testable before publication
- application documentation and the public landing page have separate stable
  destinations
- published content changes only after the repository owner deploys the
  updated `docs/` source through GitHub Pages

---

## ADR-027: Store Animal shedding history as owned event records

**Status:** Accepted

**Date:** 2026-09-22

### Context

A single free-form shedding note cannot represent multiple shedding dates,
corrections or event-specific notes. It also cannot provide deterministic
chronological history or support editing and deletion of individual records.

Existing installations and portable backups may still contain a non-empty
`Animal.sheddingNotes` value. Replacing that value without a migration would
discard user data.

### Decision

Schema Version 15 introduces `SheddingEvents` as Animal-owned records. Every
event stores its own shedding timestamp, optional note and creation and update
timestamps.

Shedding history is ordered by shedding timestamp descending and event ID
descending. Archiving an Animal retains all events. Permanently deleting the
Animal removes its events through the database relationship.

During migration, every compatible non-empty legacy shedding note creates one
event using the Animal's existing `updatedAt` timestamp. The legacy value is
then cleared but its database and backup field remains accepted for
compatibility.

Portable Backup Format Version 2 adds `sheddingHistory` without changing the
format version. Older backups without the list restore an empty history and can
still migrate a compatible legacy note.

### Consequences

- Animals can have a complete, editable shedding timeline
- individual records can be corrected or deleted without replacing unrelated
  history
- archived Animals retain their shedding history
- legacy notes are preserved deterministically
- Backup Format Version 2 remains backward compatible
- Schema Version 15 requires explicit migration and regression coverage

---

## ADR-028: Store Animal detail visibility per record

**Status:** Accepted

**Date:** 2026-09-22

### Context

Weight and shedding information is useful for many Animals but can add
unnecessary controls and empty sections for Animals where those records are not
relevant. A global setting cannot represent different needs within the same
collection.

Hiding a section must not delete its history or change backup ownership.

### Decision

Schema Version 16 stores `showWeightOnDetail` and
`showSheddingOnDetail` on every Animal. Both required Boolean columns default to
`true`.

The fields control only Animal-detail presentation and related quick actions.
Weight and shedding history remain stored and continue to be exported even when
their detail section is hidden.

Portable Backup Format Version 2 stores both values additively. Older databases
and backups default both values to `true`.

### Consequences

- detail pages can match the needs of each Animal
- existing Animals retain their previous visible sections
- hiding a section never deletes history
- the preferences follow the Animal through backup and restore
- Schema Version 16 requires a data-preserving migration
- no new permission or external service is required

---

## ADR-029: Reuse local Box QR resolution for transactional Animal reassignment

**Status:** Accepted

**Date:** 2026-09-22

### Context

Selecting a destination Box from a long dropdown becomes inconvenient in larger
collections. Existing physical Box QR codes already provide stable identifiers,
and TerraManager already has local scanning and validation infrastructure.

Reassignment must not leave an Animal without a valid Box or move it to an
archived, unknown or unchanged destination.

### Decision

Edit Animal reuses the existing Box scanner with a workflow-specific callback.
The scanner resolves the permanent Box identifier through the local repository.

Rehouse Mode accepts only an existing active destination Box that differs from
the Animal's current Box. The application asks for confirmation before calling
one atomic repository operation. That operation validates the active Animal and
active destination again before updating `boxId` and `updatedAt`.

After a successful move, the scanner returns success and Edit Animal closes
once. Cancellation or failure leaves the existing assignment unchanged.

The workflow reuses the existing camera permission and requires no additional
storage, media, network or background capability.

### Consequences

- physical Box labels can be used for fast reassignment
- all validation remains local
- invalid or partial moves cannot be persisted
- the scanner remains reusable across Box lookup, Feeding Mode and Rehouse Mode
- no database schema or backup format change is required
- navigation behavior requires regression coverage

---

## ADR-030: Keep shared collection data on a self-hosted server

**Status:** Accepted

**Date:** 2026-09-23

### Context

The existing Android and Web modes store collection data locally. Serving the
current Web build from a Raspberry Pi would still create a separate database in
each browser and would not give multiple caregivers one shared collection.

Shared mode needs one authoritative collection without changing how the
standalone modes work. It must not create divergent edits when the server is
unavailable.

### Decision

A self-hosted Dart server provides the shared Web application and a same-origin
HTTP API. The server owns one SQLite collection per installation, including
Boxes, Animals, care history, QR identifiers and media. It validates and
authorizes all collection changes before writing them.

Shared-mode browsers access collection data only through the API. They do not
initialize a local collection database or queue offline edits. If the server is
unavailable, the application displays a connection error.

From v1.14.1, appearance, language, sorting and other presentation preferences
belong to the signed-in account and are stored in the separate server account
database. They follow the account across browsers and are reset on sign-out;
new accounts get explicit defaults. Existing Android and Web standalone modes
continue to use their local databases and locally stored preferences.

An administrator can explicitly import an existing `.tmbackup` into the server
collection. This does not establish synchronization with the original
standalone installation. Imported presentation settings do not become shared
preferences for every user.

The server and Web application operate within the local network without an
external service. HTTPS, authentication and concurrent-edit handling are
defined in the implementation work.

### Consequences

- caregivers using the same server work with one authoritative collection
- standalone Android and Web data remain local and independent
- the UI needs a data-access boundary for local and HTTP-backed modes
- collection validation, media persistence and backups move to the server in
  shared mode
- account preferences remain personal and follow the account between devices
- server outages prevent edits instead of creating divergent local changes
- migration from standalone mode requires an explicit backup import
- browser-based shared mode requires no new Android app permission

---

## ADR-031: Decode Shared Care Box QR codes in the browser without a public CDN

**Status:** Accepted

**Date:** 2026-09-24

### Context

Shared Care needs physical Box lookup from a caregiver's phone. Its API
already resolves a permanent Box QR identifier, but the browser must decode
the camera image first. The Web scanner package's automatic fallback can
download a decoder from a public CDN when native recognition is unavailable.
That would make camera scanning depend on a service outside the operator's LAN.

### Decision

The separate Shared Care Web entry point selects the browser's native
`BarcodeDetector` reader. It does not activate the package's CDN fallback.
The Box overview opens the scanner only on user request. The client validates
the decoded TerraManager Box identifier locally, then sends only that
identifier to the authenticated, same-origin `GET /boxes/qr/{qrId}` endpoint.
The server resolves the current Box and its lifecycle status. Camera frames
are never uploaded.

Browsers without native QR recognition, including current Firefox, show a
camera/reader-unavailable message. Other Shared Care features remain usable.
Remote LAN clients require trusted HTTPS for browser camera access. The
standalone Android scanner and its existing permission model are unchanged.

### Consequences

- Box QR lookup works without an external decoder or cloud account on a
  supported browser
- a valid QR identifier is visible to the operator's server, but camera
  images stay on the scanning device
- browser support must be checked on the actual caregiver phones
- Firefox users can still manage records but cannot use this native scanner
- no Android release build or additional Android permission is required


---

## ADR-032: Commit Shared Care changes with server-owned audit metadata

**Status:** Accepted

**Date:** 2026-09-26

### Context

A shared collection needs durable attribution for caregiver and administrator
changes. Account deactivation or removal must not erase earlier attribution.
A portable collection restore must not replace the server's audit history.
Logging after a committed write could silently omit an event if storage fails.
The collection and account databases already have separate ownership.

### Decision

Each server database contains a server-only `shared_audit_events` table.
Collection changes and their audit events commit in the same Drift transaction;
account changes and their events commit in the same account-store transaction.
Audit-write failure rolls back the associated mutation. Portable collection
restore uses the same rule and preserves existing audit metadata. The Feeding
idempotency cache is cleared after a transaction failure; cached successful
replies are explicitly logged as replayed requests.

Accounts receive persistent random audit identifiers, including existing
accounts through an additive server migration. Events snapshot this identifier,
username and role, UTC time, a fixed operation, record type and identifier, and
outcome. Request bodies, free-text fields, credentials and binary media are
never copied. Events do not have a foreign key to collection or account rows.
Authenticated rejected operations can record a rejected outcome, but this is
not a general login or HTTP access log.

Portable backups omit both audit tables. Protected host-volume backups include
them. The server prunes events older than 365 days at startup and on audit
writes. Account removal preserves existing attribution until that retention
expires; previously downloaded host backups follow operator retention.

### Consequences

- successful persisted mutations cannot silently lack their audit event
- collection and account audit streams can later be merged by the admin viewer
- removed accounts remain attributable without retaining passwords or sessions
- a collection restore is an explicit audit boundary when record IDs are reused
- audit storage failure prevents writes until the operator repairs storage
- no standalone schema version or portable backup format change is required
- no additional Android permission or external service is required

---

## ADR-033: Manage server accounts without deleting audit attribution

**Status:** Accepted

**Date:** 2026-09-26

### Context

Shared Care already separates local account credentials from collection data.
Administrators need to change usernames, roles, passwords and active status,
and remove obsolete accounts. These controls must not lock out the operator,
leave old sessions usable or erase accountability for earlier care changes.

### Decision

Settings exposes a separate administrator-only Manage accounts page under the
Server section. Account updates revoke all sessions for the affected account;
self-edit or self-removal returns the browser to sign-in. An omitted password
retains the existing hash. Removal requires an explicit confirmation dialog and
a confirmed, same-origin DELETE request with administrator authorization and CSRF.

The account store validates the acting administrator and protects the last
active administrator inside the mutation transaction, after any asynchronous
password hashing. Username normalization and uniqueness remain server-owned.
Account deletion removes credentials and cascades to sessions while preserving
existing audit events. Reused usernames or row numbers receive new stable audit
identities. Administrator account responses provide this non-secret identity;
client edits and confirmed removals carry it as `expectedAuditId`, checked
inside the transaction to reject stale forms targeting a reused row number.
Successful mutations and their audit records commit together.

### Consequences

- administrators can manage access from the existing Shared Care interface
- account changes invalidate affected sessions across devices
- the final active administrator cannot be removed, deactivated or demoted
- account removal does not delete collection records or prior audit attribution
- historical host backups remain subject to operator retention
- no standalone schema or portable backup format change is required
- no additional Android permission or external service is required

---

## ADR-034: Read administrator audit metadata with bounded merged pagination

**Status:** Accepted

**Date:** 2026-09-27

### Context

Issue #179 adds an administrator viewer for the collection and account audit
streams introduced in Issue #177. Reading history must preserve account
attribution after deletion and avoid exposing collection payloads, credentials
or private notes. The interface must fit both phones and desktop browsers.

### Decision

An Audit subsection in Shared server Settings opens a read-only page with
localized actor, time, action, target and outcome metadata. Local date ranges,
literal actor-name matching and operation filters run on the server. The
existing session/administrator checks protect the API independently of UI
visibility. Failed authorization hides previously loaded events.

Each database returns at most one page plus one lookahead row. A timestamp,
source and event-ID cursor merges these bounded streams newest first and
avoids offset shifts when new events arrive. A normalized timestamp expression
and index preserve ordering across millisecond and microsecond precision.
Only allowlisted audit columns are selected; account/collection payloads are
never joined. Existing retention remains enforced, with no audit writes for
viewer reads and no standalone schema or portable backup changes.

### Consequences

- caregivers cannot read history through the UI or direct API requests
- filtered history and pagination do not download the complete audit log
- timestamps and actor names reflect the original event, even after renames
- record IDs describe the state at event time; collection restore is a boundary
- no-event, no-match, loading, retry and access-denied states are explicit
- both Shared Web and the server must be updated for the new endpoint

---

## ADR-035: Organize Shared Care by feature with explicit transport and persistence boundaries

**Status:** Accepted

**Date:** 2026-09-27

### Context

Issue #185 applies the standalone feature layout to Shared Care. Mixed overview,
detail, form and server API files combine independent Animal, Box, Feeding,
Media, Settings and administration responsibilities, making changes difficult
to review without accidentally crossing the browser/server boundary.

### Decision

Client pages and widgets live in feature presentation folders. Feature API
mixins compose over one shared transient transport, retaining public client
methods, session handling, CSRF and connection notifications. Authentication,
navigation and reusable presentation have explicit shared locations.

Server feature HTTP handlers delegate to application operations. Account and
audit persistence, password hashing, HTTP readers/writers and serialization
live in infrastructure modules. Domain models carry account/session identity,
API results and allowlisted audit metadata. Existing collection repositories
remain shared by standalone and the server; the browser does not import them.

The composition roots retain global guards and error translation. Collection
mutation auditing stays around the entire operation transaction. Backup and
Audit handlers share the same collection gate, and Feeding replay state remains
per CareApi with the existing invalidation rules. No route, payload, schema,
backup format, permission, text or workflow changes are part of the refactor.

Former flat paths remain export-only migration adapters. Repository code and
tests use canonical paths. Architecture checks enforce dependency boundaries
and prevent new production imports through migration adapters; compatibility
coverage checks existing external imports.

### Consequences

- feature changes can be reviewed within smaller, focused modules
- browser presentation and server-owned persistence remain separate
- security and transaction behavior continue through common composition roots
- existing callers can migrate imports incrementally
- compatibility exports can be retired in a later explicit migration
- [Shared Care code organization](shared-care-architecture.md) describes the layout

---

## ADR-036: Password-encrypted backups and large-file memory

**Status:** Accepted; released with a documented large-backup memory limitation

**Date:** 2026-09-28

### Context and evaluation

Issue #118 asks for optional authenticated encryption only if it remains simple,
reliable on Android and Web, and reasonably sized. The validated clients are
Android and standalone Web; Shared Care adds a browser client and a Dart server.
iOS is not yet a validated release platform. The current `.tmbackup` is a ZIP
held in memory, with portable formats 1 and 2. Standalone export and import,
Shared Care browser download and upload, and the server's restore validator all
consume complete byte arrays. Shared Care allows 256 MiB compressed input and
512 MiB expanded data. Restore can also create a safety backup.

The already pinned [`cryptography` 2.9.0](https://pub.dev/packages/cryptography/versions/2.9.0)
provides Argon2id and AES-256-GCM on Android and Web without a new dependency
or a custom cryptographic primitive. A proof of concept for a versioned,
authenticated outer container used a fresh 16-byte salt and 12-byte nonce
around unchanged input bytes. It passed Dart-VM round-trip, wrong-password,
tamper, salt/nonce-uniqueness and 16 MiB payload tests. Browser compilation and
both Android Release builds succeeded. The local Chrome test runner never
executed the test, and no Android runtime test was performed; neither platform
has a verified runtime result. An incorrect password and manipulated ciphertext
both produce an authentication failure, so the UI must describe both
possibilities without pretending to distinguish them.

The sibling [`cryptography_flutter` package](https://pub.dev/packages/cryptography_flutter)
could accelerate Android with native APIs but adds a Flutter plugin and Gradle
dependency work without addressing the full-buffer copies. The existing
`cryptography` package also supports PBKDF2-HMAC-SHA256; at 600,000 iterations
it took about 7.9 seconds on this local Dart VM, versus about 0.53 seconds for
the candidate Argon2id configuration. These are evaluation timings, not a
device benchmark or a final KDF parameter decision.

Size probe: only the reachable codec was added temporarily to each entry point,
without the proposed UI. Builds used local Flutter 3.47.0, Java 22 and a
disposable test signing key; these are not the CI/release toolchain.

| Artifact | Baseline bytes | Codec probe bytes | Increase |
|---|---:|---:|---:|
| Release APK | 91,272,456 | 91,583,752 | 311,296 (0.34%) |
| Release AAB | 80,397,959 | 80,738,535 | 340,576 (0.42%) |
| Standalone Web bundle | 48,224,404 | 48,266,179 | 41,775 (0.09%) |
| Shared Care Web bundle | 48,618,652 | 48,660,520 | 41,868 (0.09%) |

Size is acceptable for the codec itself, but the whole-file approach is not a
reliable large-backup design. In a local Dart-VM measurement, a 64 MiB input
raised process resident memory from about 251 MB to 1,085 MB after encryption
and 1,292 MB after decryption; the two operations took about 14 and 12 seconds.
These figures are machine-specific, not Android/Web benchmarks. They expose
multiple full-buffer copies on top of the existing ZIP/media buffers. No
reliable upper bound or 256 MiB phone/browser test exists.

### Reduce backup size before adding encryption

Backup size deserves its own measured step before choosing the encrypted
container. The existing picture pipeline already bounds new and replaced
images to a 1920-pixel longest edge and encodes them as WebP at quality 82;
older images retain their original bytes. The v0.12.0 roadmap records one
67-picture collection shrinking from about 140 MB to 22.7 MB after picture
normalization. This is evidence for that collection, not a prediction for
other users. Current exports use ZIP with its default fast DEFLATE setting,
copy each referenced gallery picture into its own archive entry, and omit
regenerable QR images. The primary picture is referenced by the gallery rather
than added a second time. Duplicated records can nevertheless contain
independent copies of identical picture bytes.

First measure complete backup composition on representative, consented or
synthetic collections: JSON versus media, legacy versus normalized formats,
duplicate picture content, archive overhead, export/import time, and peak
memory on Android, standalone Web and Shared Care. Do not inspect or publish
private collection contents in diagnostics. Compare candidate ZIP levels,
lossless duplicate handling and optional migration of legacy pictures against
size, fidelity, restore compatibility and CPU/memory costs. An already encoded
sample WebP in the repository gained no size from either fast or maximum ZIP
DEFLATE in a small local probe; this is not a collection benchmark.

Do not silently omit archived records, histories, notes or pictures, and do
not recompress existing pictures with quality loss merely to make a backup.
Any optional legacy-picture optimization must be explicit, preview its effect,
preserve the original collection until a verified result exists, and round-trip
through both standalone and Shared Care. Existing format-1/2 imports remain
supported. Smaller typical archives will improve transfer and storage but
cannot replace bounded-memory encryption and restore: the supported size
limits still allow large media-rich backups.

One privately supplied sample backup was inspected locally using aggregate
measurements only. Its media already consisted entirely of WebP pictures with
no image exceeding the configured 1920-pixel edge, and there were no
byte-identical picture copies. ZIP reduced the media payload by only about
0.03%. This single sample does not characterize every collection, but it gives
no evidence for archive deduplication or stronger ZIP compression as the next
change. Stripping color profiles or re-encoding pictures would risk display
fidelity for a small or unknown benefit.

### Incremental ZIP assembly

Standalone and Shared Care server exports now add each picture to the ZIP as
it is read, rather than holding a collection-wide `Map` of all picture bytes
until the end. Both exporters use one ZIP builder. ZIP entry order is not part
of portable format 2, and existing imports continue to resolve entries by
path. This reduces a full-media buffer during export without changing the
stored data, schema, backup format or the save and restore flows.

Manual standalone exports and pre-restore safety copies on native platforms
now write the ZIP into an app-owned temporary file, hand that file path to the
system Save As flow, and remove the temporary file on success, cancellation
or handled failure. A cancelled or failed safety-copy save stops the restore
before settings or collection data are replaced. The Shared Care server uses
the same file-backed ZIP output and sends the completed
file through the HTTP response, removing it afterwards. Its collection gate
is released after the snapshot is complete; a subsequent collection change
invalidates the safety token through the existing generation check. Shared
Care in browsers with the File System Access save picker now opens the picker
before starting an authenticated streamed HTTP download. It grants the client
the restore safety token only after the complete response has been written;
when `Content-Length` is present, the received length must also match. The
browser suggests a local-time filename, while the archive manifest retains
the server's export timestamp. Browsers without that picker retain the
existing byte-array download and Save As flow. In-memory export APIs remain
for that fallback and tests; standalone Web safety copies still use the
in-memory save fallback. None of these paths changes the portable archive
format.

This is still not an end-to-end bounded-memory backup implementation. The ZIP
encoder buffers each picture while compressing it; browser fallbacks and the
Shared Care client upload still materialize complete byte arrays, while
restores retain referenced media collections. Native and server file-backed
exports create temporary *unencrypted* files, so their cleanup must be
preserved, and the future encrypted format must never spool a plaintext
archive. A process crash can leave a temporary unencrypted file;
this remains a limitation of the current unencrypted export path. The next
design step must bound the browser fallback and import paths, carry
authenticated chunks through encryption and restore, and prevent a partial
restore. Browser support, large-file memory use and cleanup behavior need
device/browser measurements before claiming bounded behavior across platforms.

Import validation now checks the actual length and CRC-32 of every ZIP entry
used for restore against the central directory before returning a
`ValidatedBackup` for restore. The pinned `archive` package does not perform
this check even when `ZipDecoder.decodeBytes(verify: true)` is requested.
This rejects damaged metadata and referenced pictures before the collection
is replaced. Unused entries remain ignored so their contents need not be
expanded in memory.
Referenced decoded media are retained once for the subsequent database
transaction; a stored ZIP entry is detached when its byte view would otherwise
keep the entire input archive alive. CRC-32 detects accidental corruption but
is not authentication: a deliberately altered ZIP can be recomputed. It does
not replace the authenticated encryption planned for the later milestone.
Native standalone imports now validate a picker-provided file path through a
file-backed ZIP reader. If the picker exposes only a byte stream, the app
writes it to a private temporary file for validation and removes that file on
success or handled failure. This avoids retaining the complete compressed ZIP
as a byte array. All referenced media are still decoded and held in the
validated backup until the user confirms restore; the import is therefore not
yet bounded-memory. The file-backed reader keeps its shared handle open until
validation finishes, then closes it before any confirmation dialog. A process
crash can leave a temporary unencrypted copy of a stream-only selection. The
future encrypted format must avoid staging decrypted plaintext. Shared Care
server restores now also write the HTTP upload to a private temporary file,
enforce the existing 256 MiB limit while receiving it, and validate that file
without retaining the complete compressed archive in memory. The file is
removed after success or handled failure, including a rejected archive or a
stale safety grant. Validation still holds referenced media in memory until
the database transaction finishes. A process crash can leave an unencrypted
temporary upload, so a future encrypted format must not spool decrypted
plaintext there. Browser imports and uploads retain their existing in-memory
path. Bounded media restore, browser safety-copy handling and device
measurements remain open.

### Decision

Do not ship the proof of concept or change the backup format in Issue #118.
Formats 1 and 2 remain unencrypted and importable. The negligible dependency
and build-size cost does not overcome the unbounded peak-memory risk and the
unverified browser/device runtime. The first backup-size assessment found no
worthwhile lossless optimization in the supplied sample. Prioritize a
bounded-memory container and file-flow design in the later stretch milestone
"Password-protected portable backups" and validate it with realistic
media-backup tests on Android and Web. Reconsider size reduction only if a
broader measurement shows a material opportunity without data or quality loss.

The later design must keep the inner portable ZIP and legacy imports, identify
its encrypted envelope with an explicit version, authenticate its metadata and
ciphertext, use fresh salts/nonces, and never persist passwords or plaintext
temporary files. Export must confirm the password and warn that it cannot be
recovered. Import must distinguish unsupported/truncated containers from the
combined wrong-password-or-tampered-data state before any collection change.
Standalone safety copies must not silently become plaintext; Shared Care may
encrypt/decrypt in the browser while retaining the server's existing plaintext
restore API and administrator checks. Re-measure the complete feature, not just
the codec, against the pinned release toolchain.

### Stretch-milestone implementation status (2026-09-30)

The optional version-1 encrypted container now wraps the unchanged portable
ZIP. It authenticates the complete header and ordered 256 KiB frames with
Argon2id and AES-256-GCM, fresh salt and nonce material per export, and a
final authenticated empty frame. Standalone and Shared Care clients offer
password-protected export. Import detects the container before ZIP parsing;
Shared Care decrypts in the browser and sends only the inner ZIP to the
existing authenticated restore API. The password is not persisted or sent to
the Shared Care server. Native encrypted exports spool only ciphertext, and
native encrypted imports authenticate the whole file before validation while
re-reading media one at a time from the encrypted file. A standalone restore
of an encrypted backup saves its safety copy under the same password. A Shared
Care restore of an encrypted backup requires its current safety copy to have
been saved with password protection.

This implementation has not yet met the 256 MiB, bounded-memory acceptance
condition on every platform. Browser import and the existing restore POST
still materialize complete byte arrays, and browser Save As fallbacks do so
for export. Web import now authenticates and compacts encrypted frames in the
selected byte buffer, avoiding a second complete plaintext array, but the
picker and Shared Care POST remain proportional to archive size. Web ZIP
validation now reads media lazily from the selected archive buffer rather
than retaining every media byte array, but still validates synchronously on
the UI isolate. Shared Care server export and restore now use temporary
encrypted spools with per-operation random secrets held only in process
memory. The server authenticates the spool before reading the inner ZIP,
validates media lazily, and removes the spool after the request. The
decrypted archive is still visible to the server process and its operator
while it handles the restore. On 2026-10-01, a physical Galaxy S22 completed
protected 252 MiB imports in Brave, Chrome and Firefox. The same build also
completed a plain
import in Brave. The [device report](testing/password-backup-s22-2026-09-30.md)
contains package-wide PSS traces, the large protected export and re-import,
and negative-path results. A sequential Brave plain/protected import pair
showed sampled increases of 1,118.6 and 1,619.5 MiB, respectively. Its
500.9 MiB difference exceeds the proposed 64 MiB additional-memory target,
although the second run started 220.3 MiB higher and the traces include other
Brave activity. This is a warning, not a controlled measurement of the
encryption codec alone. A subsequent native S22 test-signed Release pair
started from nearly equal PSS baselines and completed both 252 MiB imports.
The protected run's sampled PSS increase was initially 453.4 MiB higher than
the plain run's. Removing redundant native encrypted-frame copies reduced the
protected sampled peak by 282.4 MiB in a repeat run; its increase remained
164.2 MiB above the plain run's, still above the proposed 64 MiB target.
Android's picker had retained a complete selected-file copy after import;
the client now clears that plugin cache after the backup is disposed. The
[device report](testing/password-backup-s22-2026-09-30.md) records raw traces,
debug and Release build qualifications, and observed cache cleanup. There is
still no physical approximately 4 GiB device
result, full Shared Care cross-client device run, paired export-memory
comparison, or production-signed artifact-size comparison. At this checkpoint,
the stretch milestone remained open pending those checks and the memory work.

### Follow-up evidence and release decision (2026-10-02)

The Web picker now requests a read stream without eagerly loading selected
file bytes and reads only the encrypted magic before prompting for a password.
Shared Care preview validation discards media bytes after checking them, and
failed Web authentication clears any buffer that may already contain compacted
plaintext. Standalone backup failures no longer print raw exception or stack
details to application logs. These changes reduce avoidable copies and
information exposure but do not make browser restore memory-bounded.

On a disposable local Shared Care server, a Galaxy S22 Chrome client restored
a password-protected 264,457,033-byte backup containing 12 Boxes and 84 media
assets. An expired safety token was rejected with HTTP 409 without replacing
the prior collection; a new encrypted safety copy and token allowed the full
restore, recorded as HTTP 200. The sampled Chrome package PSS rose from
817,506 KiB to 2,440,886 KiB. See the
[follow-up report](testing/password-backup-milestone-2026-10-02.md) for the
trace method, build checks and size comparison.

The Galaxy S22 has about 7.1 GiB physical RAM, so this result does not prove
the proposed approximately 4 GiB target. The browser import buffer, Shared
Care POST and save fallback still scale with the entire archive.

The project accepts that limitation for the first release of the optional
feature. Users receive progress feedback and may continue to use unprotected
portable backups. Authentication, validation and safety-copy failures occur
before collection replacement, and the tested stale-token and wrong-password
paths preserved the existing collection. A very large protected operation can
still exhaust memory or be terminated by the operating system, especially on
lower-memory devices; this limitation is documented in the guides and platform
support notes.

The 64 MiB additional-memory goal and an approximately 4 GiB device result are
deferred to follow-up optimization rather than blocking Issues #203-#207. This
decision does not claim bounded-memory behavior. Final distribution artifacts
still follow the ordinary release checklist, including the pinned toolchain,
production signing, size recording and release-candidate smoke tests.
