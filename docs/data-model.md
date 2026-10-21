# Data Model

The executable model is in `lib/core/database/tables/`; repositories enforce
domain rules and `app_database.dart` owns migrations. The same collection model
is used by standalone and the Shared Care server. Portable representation is
specified in [Backup format](backup-format.md).

## Entity Relationships

```text
Box -> Animals -> FeedingEvents / AnimalWeightEntries / SheddingEvents
Box -> BoxPictureAssociations -> MediaAssets
Animal -> AnimalPictureAssociations -> MediaAssets
```

Each active Animal belongs to one active Box. Archived Animals have no Box.
Histories and galleries remain owned by their Animal while archived.
`pictureMediaId` selects the primary gallery picture and may be null.

## Fields

All entity IDs are integer primary keys. Box and Animal have `createdAt` and
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
| MediaAsset | `fileName`, `mimeType`, binary `data`, `createdAt`, `updatedAt`. |
| Picture association | Owner `animalId` or `boxId`, `mediaAssetId`, `capturedAt`, `sortOrder`; unique media association and unique owner/order. |

Stable enums have explicit converters. Taxonomy, enum wire values, timestamp
encoding and legacy defaults are listed once in the [backup contract](backup-format.md).

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

The current Drift database schema version is **17**. Upgrade steps preserve
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

Generation commands and migration checks are in [Development](development.md).
