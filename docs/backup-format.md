# TerraManager Backup Format

`.tmbackup` is a portable backup, independent of raw SQLite files. New exports
use **Backup Format Version 2**; formats 1 and 2 remain readable. Format version,
database schema version and application version are independent. Additive optional
fields do not change the portable version.

## ZIP structure

```text
manifest.json
data.json
settings.json
media/animals/...
media/boxes/...     # format 2
```

Entry order is irrelevant. `manifest.json` requires `backupFormatVersion`,
`appVersion`, `databaseSchemaVersion`, `createdAt`. `data.json` always contains
`boxes`, `animals`, `feedingEvents`, including empty lists. Integer record IDs
and permanent Box QR values survive full replacement; internal MediaAsset IDs
are recreated. Media paths are portable relative paths, never device paths.
Generated QR images are omitted because `qrId` regenerates them.

## Portable records

Common creation/update fields are `createdAt`, `updatedAt`; lifecycle fields are
`status`, `archiveReason`, `archivedAt`, `archiveNotes`.

| Record | Serialized fields |
| --- | --- |
| Box | `id`, `qrId`, `name`, lifecycle, `widthCm`, `heightCm`, `depthCm`, `temperatureZones`, `notes`, `pictureMediaPath`, `pictures`, creation/update fields |
| Animal identity | `id`, `boxId`, lifecycle, `commonName`, `latinName`, `category`, `subcategory`, `sex`, `birthDate`, `birthDateAccuracy` |
| Animal profile | `tempMin`, `tempMax`, `nighttimeTemperature`, `nighttimeTemperatureMin`, `nighttimeTemperatureMax`, `humidityMin`, `humidityMax`, `originHabitat`, `weight`, `restOrDormancyPeriods`, `temperatureZones`, `notes` |
| Animal history / pictures | `weightHistory`, `sheddingNotes` (legacy), `sheddingHistory`, `showWeightOnDetail`, `showSheddingOnDetail`, `pictureMediaPath`, `pictures`, creation/update fields |
| Animal reminder | `feedingReminderIntervalDays`, `feedingReminderBaseline`, `feedingReminderWeekdays`, `feedingReminderMinuteOfDay`, `feedingReminderTimeZone` |
| FeedingEvent | `id`, `animalId`, `fedAt`, `notes` |
| Nested weight entry | `id`, `weightGrams`, `measuredAt` |
| Nested shedding entry | `id`, `shedAt`, `notes`, `createdAt`, `updatedAt` |
| Gallery entry | `mediaPath`, `capturedAt`; list order is retained |

`pictureMediaPath` selects a gallery entry as primary. Referenced files must
exist; a null primary is valid. Older single-picture backups become one-entry
galleries. Format 1 Boxes have `id`, `qrId` and timestamps; absent later fields
restore to active/null defaults. Missing taxonomy becomes `other`/null; missing
detail-visibility flags become true. Missing histories are empty, with compatible
legacy shedding/weight/nighttime data migrated without inventing ambiguous values.

## Validation rules

- IDs and Box QR values must be unique, relationships valid, and numeric/profile
  values within application bounds. Weight is finite and positive; ranges are ordered.
- Active Animals reference an existing active Box and have no archive metadata.
  Archived Animals have null `boxId` and reason/time. Archived Boxes require
  reason/time and cannot contain active Animals. Active Boxes have no archive metadata.
- Interval reminders require positive interval plus baseline; disabled reminders
  use nulls. Weekly mode uses mask 1-127 (Monday bit 0), minute 0-1439, valid IANA
  zone and baseline, with null interval. Reject partial/conflicting configurations.
- Validate required JSON types, supported versions, stable enum/taxonomy values,
  nested event IDs, picture references and used-entry lengths/CRC before restore.
  CRC detects accidental damage; authenticated encryption supplies authenticity.
- Reject absolute/drive-qualified paths, backslashes, `.`/`..` segments and duplicate
  ZIP entry names. Shared Care also limits compressed/expanded size as in the [API](shared-care-api.md).

### Stable enum and taxonomy values

| Field | Values |
| --- | --- |
| Status | `active`, `archived` |
| Box archive reason | `sold`, `replaced`, `damaged`, `stored`, `other` |
| Animal archive reason | `sold`, `traded`, `deceased`, `rehomed`, `other` |
| Birth accuracy | `exact`, `monthKnown`, `yearKnown` |
| Sex | `male`, `female`, `unknown`, `other` |
| `amphibian` | `frogOrToad`, `newtOrSalamander`, `other` |
| `reptile` | `snake`, `lizard`, `turtle`, `other` |
| `arachnid` | `tarantula`, `otherSpider`, `scorpion`, `whipSpiderOrWhipScorpion`, `other` |
| `insect` | `beetle`, `cockroach`, `mantis`, `grasshopperOrCricket`, `other` |
| `myriapod` | `millipede`, `centipede`, `other` |
| `crustacean` | `isopod`, `crab`, `other` |
| `mollusc` | `snail`, `other` |
| `otherInvertebrate`, `other` | No subcategory |

Use explicit encoders, not translated labels or implicit enum names. Only
documented missing legacy fields get defaults; unknown present values fail.
New `stored` archives require a reader that supports that reason.

## Timestamps

New event/metadata instants use UTC ISO-8601 ending in `Z`; clients localize once.
Birth dates are calendar `YYYY-MM-DD` values, not instants. Legacy time-bearing
birth dates keep their written calendar components.

For old offset-free timestamps, Shared Care requires administrator confirmation
of the original IANA zone via `X-Backup-Time-Zone`; use historical DST rules,
the earlier repeated autumn occurrence, and reject nonexistent spring times.
Standalone interprets such legacy values in the importing device's local zone.
Explicit `Z`/offsets take precedence. Never apply a fixed-hour correction or
shift existing rows speculatively.

## settings.json

`themeMode` and `accent` are required. Optional settings/defaults:

| Setting | Default / supported values |
| --- | --- |
| `themeMode` | `system`, `light`, `dark` |
| `accent` | `green`, `blue`, `teal`, `orange`, `purple`, `red` |
| `language` | `system` default; `english`, `german` |
| `animalNameOrder` | `commonNameFirst` default; `latinNameFirst` |
| `animalSortOrder` | `createdOldestFirst` default; `createdNewestFirst`, `displayNameAscending`, `displayNameDescending`, `ageOldestFirst`, `ageYoungestFirst`, `latestFeedingNewestFirst`, `latestFeedingOldestFirst` |
| `boxSortOrder` | `labelAscending` default; `labelDescending`, `nameAscending`, `nameDescending`, `volumeAscending`, `volumeDescending` |
| `animalCategoryViewEnabled` | Boolean, default false |
| `bigPictureModeEnabled` | Boolean, default false |
| `nextFeedingSummaryEnabled` | Boolean, default false |

Legacy Animal `categoryAscending`/`categoryDescending` enable grouping and map
to matching displayed-name sorting; old Box creation sorting maps to label
sorting. Archive sort orders are not portable and stay local/account-specific.
Shared exports use `scope: collectionOnly` with neutral required settings;
standalone import preserves personal preferences. Archives without scope retain
their established settings behavior. Accounts, sessions, audit and upload
idempotency receipts are excluded from portable collection data.

## Password-protected container version 1

The encrypted outer container wraps the unchanged portable ZIP. All multibyte
header integers are unsigned little-endian:

| Offset | Bytes | Content |
|---:|---:|---|
| 0 | 8 | ASCII `TMBKENC!` |
| 8 | 1 | Container version `1` |
| 9 | 1 | KDF `1` = Argon2id |
| 10 | 1 | Cipher `1` = AES-256-GCM |
| 11 | 4 | Maximum plaintext frame size, `262144` |
| 15 | 4 | Argon2id memory in KiB, currently `19456` |
| 19 | 2 | Argon2id iterations, currently `2` |
| 21 | 1 | Argon2id parallelism, currently `1` |
| 22 | 16 | Fresh random salt |
| 38 | 4 | Fresh random nonce prefix |

Argon2id derives a 32-byte key. A frame is four-byte plaintext length, ciphertext
of that length and a 16-byte AES-GCM tag. Its nonce is the four-byte prefix plus
the zero-based 64-bit frame number, big-endian. Authenticated data is the entire
header, big-endian frame number and little-endian plaintext length. An
authenticated zero-length final frame is mandatory. Reject invalid lengths,
unsupported parameters, missing final frames and trailing bytes. Wrong password
and changed ciphertext intentionally share one authentication error.

Fresh salt/nonce material is generated per export. No filename, settings or
manifest appears outside the encrypted payload. The password is not persisted
and is not written to application or Shared Care server logs. Shared Care
encrypts/decrypts in the browser; the server receives the inner ZIP over HTTPS.
Native protected save/import spools ciphertext and removes handled temporary
files; process termination can interrupt cleanup.

## Restore and limits

Authenticate/decode, validate, preview and ask for explicit replacement
confirmation before modifying data. Standalone enables an optional pre-restore
safety copy by default; cancellation/failure to save it stops replacement. A
protected import uses the same password for that local safety copy. Settings
rollback and one database transaction prevent partial replacement.

Shared Care requires a fresh safety grant for populated collections, rechecks
emptiness for first import, preserves accounts/audit and publishes an epoch reset
only after successful replacement. See [API](shared-care-api.md) for headers,
limits and safety-token lifetime; [Deployment](shared-care-deployment.md) covers
full server backup.

Large protected operations can take minutes and still use memory proportional
to the archive. File-backed paths reduce copies without establishing bounded
memory. Current evidence/open targets are in [Backup validation](testing/password-backups.md).
