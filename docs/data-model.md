# Data Model

The executable model is in `lib/core/database/tables/`; repositories enforce
domain rules and `app_database.dart` owns migrations. The same collection model
is used by standalone and the Shared Care server. Portable representation is
specified in [Backup format](backup-format.md).

## Entity Relationships

```text
Box -> Animals -> FeedingEvents / AnimalWeightEntries / SheddingEvents
Box -> BoxPictureAssociations -> MediaAssets
Box -> BoxCareEvents
Animal -> AnimalPictureAssociations -> MediaAssets
```

Each active Animal belongs to one active Box. Archived Animals have no Box.
Histories and galleries remain owned by their Animal while archived.
`pictureMediaId` selects the primary gallery picture and may be null.

## Fields

Record IDs are integer primary keys; custom definitions use stable UUIDs. Box and Animal have `createdAt` and
`updatedAt`; optional fields are nullable unless a default is stated.

| Entity | Fields / purpose |
| --- | --- |
| Box | Unique permanent `qrId` (`TM:BOX:<UUID-v4>`); `name`, positive `widthCm`, `heightCm`, `depthCm`; `temperatureZones`, `notes`, `pictureMediaId`; `status`, `archiveReason`, `archivedAt`, `archiveNotes`. |
| Animal identity | `boxId`, `status`, required `commonName`, `latinName`, `category` (legacy default `other`), compatible optional `subcategory`, `sex`, `birthDate`, `birthDateAccuracy`. |
| Animal husbandry | Required `tempMin`, `tempMax`, `humidityMin`, `humidityMax`; optional `nighttimeTemperatureMin`, `nighttimeTemperatureMax`, `originHabitat`, `restOrDormancyPeriods`, `notes`, `pictureMediaId`. |
| Animal lifecycle / display | `archiveReason`, `archivedAt`, `archiveNotes`; `showWeightOnDetail` and `showSheddingOnDetail` default to true and never delete history. |
| Animal reminders | `feedingReminderIntervalDays`, `feedingReminderBaseline`, `feedingReminderWeekdays`, `feedingReminderMinuteOfDay`, `feedingReminderTimeZone`. |
| Animal legacy compatibility | `picturePath`, `weight`, `sheddingNotes`, `nighttimeTemperature`, `temperatureZones`; retained for migration/older archives, not new parallel histories. |
| FeedingEvent | `animalId`, `fedAt`, optional `notes`. Group feeding creates one event per selected Animal in one transaction. |
| AnimalWeightEntry | `animalId`, positive finite `weightGrams`, `measuredAt`. Latest measurement determines current numeric weight. |
| SheddingEvent | `animalId`, `shedAt`, optional `notes`, `createdAt`, `updatedAt`. |
| BoxCareEvent | `boxId`, `type` (`substrateChange`, `cleaning`, `waterChange`, `custom`), optional `customTypeId`, `occurredAt`, optional `notes`, unique retry `requestId`, integer `revision`, creation/update timestamps. Care events have no media association. |
| CareEventType | Collection-wide UUID `id`, normalized unique `labelKey`, display `label` (1–80 characters), `sortOrder`, `archived`, `revision`, timestamps. Custom events reference its stable ID; definitions are archived rather than deleted. |
| CustomFieldTemplate | Stable UUID, target (`animal`/`box`), immutable type (`text`/`number`/`date`/`boolean`), unique normalized label per target, `hidden`, `archived`, positive `revision`. |
| CustomFieldValue | Template FK and exactly one Animal/Box owner FK, validated scalar JSON, positive revision. Unique per owner/template; owner deletion cascades. |
| MediaAsset | `fileName`, `mimeType`, binary `data`, `createdAt`, `updatedAt`. |
| Picture association | Owner `animalId` or `boxId`, `mediaAssetId`, `capturedAt`, `sortOrder`; unique media association and unique owner/order. |

Stable enums have explicit converters. Taxonomy, enum wire values, timestamp
encoding and legacy defaults are listed once in the [backup contract](backup-format.md).

Box care is a separate newest-first history in Box details. It never becomes an
Animal event or follows an Animal when it moves. Schema 17 → 18 introduced care;
18 → 19 removes the retired image-link table without changing care records. Archived Boxes retain read-only care;
duplicates start without care history. Permanent Box deletion cascades its care
events. Gallery images follow the existing gallery ownership rules.

Custom definitions are managed directly from Box care history in both modes. Rename changes the
displayed label without rewriting events; archive removes a type from new-event
choices while preserving history, filtering and edits that retain the same type.
Case-insensitive normalized labels must be unique, including archived types;
standard DE/EN labels are reserved. Reordering checks the complete ID/revision set.

Custom fields are optional profile data, edited with the core profile in one
transaction. Templates are managed from details/editing, separately for Animals
and Boxes. Rename keeps IDs; hidden fields retain values but leave the UI;
archived fields leave editing and remain readable in details. Clearing a value
keeps a revisioned null tombstone for conflict detection. Duplicate profiles copy
all custom values, including hidden/archived values. Dates are strict calendar
dates (YYYY-MM-DD); numbers are finite and may be zero; booleans distinguish
unset from false. Text is limited to 10,000 characters.

## Lifecycle and duplication

- Active records have no archive metadata. Archived records require reason/time.
- Archiving a Box requires no active assigned Animals. Creating, restoring or
  moving an Animal rechecks its active destination in the write transaction.
- Restoring a Box clears archive metadata and preserves its QR ID. Restoring an
  Animal requires an active destination Box.
- Permanent deletion requires the archived state and deletes owned histories/
  galleries transactionally. Shared Care additionally requires administrator role.
- Duplication creates new IDs; a Box gets a new QR ID and no assigned Animals.
  Reusable profile/picture data is copied, not historical events. Animal duplication
  may seed one current-weight entry rather than copying the weight timeline.

## Feeding reminders

Null `feedingReminderWeekdays` selects interval mode. A positive interval and
baseline are paired; the latest feeding supersedes the baseline. Weekly mode
uses a Monday-bit-0 mask (1-127), minute of day (0-1439), IANA zone and baseline,
with a null interval. Archived Animals are excluded from active due results.
Due state is derived from history and the clock, not stored or delivered as an
OS notification. Recalculate after care changes and foreground return.

## Storage and repositories

Android uses native SQLite; standalone Web uses SQLite WASM and a generated
worker. Browser storage belongs to one origin/profile. Shared Care owns the
collection on its server; accounts, sessions and preferences are in a separate
SQLite database. Server-only audit and upload receipts are not portable entities.

Repositories under `lib/core/database/repositories/` handle queries, validation
and transactions. Media bytes are database-backed; legacy picture paths are
migrated only when readable. Missing legacy files must not discard other data.

## Schema Version

The current Drift database schema version is **21**. Upgrade steps preserve
existing IDs, relationships and QR values and finish with foreign-key checks.

| Version | Addition |
| --- | --- |
| 1 | Boxes, Animals and Feedings |
| 2 | Animal lifecycle; nullable Box assignment |
| 3 | MediaAssets and Animal primary media |
| 4 | Box dimensions and primary media |
| 5 | Interval feeding reminders |
| 6 | Box notes |
| 7 | Box names |
| 8 | Box archive metadata |
| 9 | Extended Animal profile fields |
| 10 | Animal category/subcategory |
| 11 | Box temperature zones; migrate legacy Animal values |
| 12 | Ordered Animal/Box galleries |
| 13 | Legacy nighttime temperature |
| 14 | Nighttime range and numeric weight history |
| 15 | Timestamped shedding history |
| 16 | Per-Animal weight/shedding visibility |
| 17 | Weekday/time/zone feeding reminders |
| 18 | Box care events and picture attachments |
| 19 | Remove retired Box care picture links |
| 20 | Collection-wide custom care definitions and stable event references |
| 21 | Typed Animal/Box custom-field templates and separately stored values |

Generation commands and migration checks are in [Development](development.md).
