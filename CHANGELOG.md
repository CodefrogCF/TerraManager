# Changelog

Release changes are summarized below. Detailed contracts are in the
[documentation](docs/project-documentation.md). Dates and historical release
groupings are retained from the existing record.

## [unreleased]

### Added

- Show bundled German/English release highlights once per version/build after an
  Android Standalone update, with manual reopening through Settings → What's new;
  keep first-run onboarding and device-local display state separate (#252).

### Fixed

- Keep due Android feeding alarms pending when returning to the running app,
  instead of restarting their inexact delivery window. Cold starts still rearm
  cached alarms to recover after force stop.

## [1.16.0] - 2026-10-23

### Added

- Opt-in Android feeding notifications for the local collection, off by default,
  with contextual permission, generic private text and safe Animal navigation (#245).
- Schedule existing interval/weekday reminders on-device; update after feeding,
  reminder, archive/delete and device-setting changes. Keep in-app reminders and
  their independent 24-hour overview suppression (#246). Web/Shared Care do not
  create additional system alerts. Android delivery can be delayed by OS restrictions.
- Add View Animal as the first feeding-alert action in Standalone and Shared Care,
  alongside Add Feeding and the existing 24-hour overview suppression.

### Changed

- Give empty Boxes their own localized heading when empty-last sorting is enabled,
  in compact and Big Picture overviews in Standalone and Shared Care.
- Reduce overview bottom spacing and hide both floating actions at the end of
  scrollable Animal/Box lists and grids; show them again when scrolling back so
  the last record's context menu remains accessible.
- Shorten the Android notification setting description in German and English.
- Condense user and developer documentation and remove redundant validation reports.

## [1.15.5] - 2026-10-21

### Added

- Standalone and Shared Care: optionally show empty Boxes last while preserving
  the selected sort within each group; the setting defaults to off (#235).
- Standalone and Shared Care: tap an Animal overview feeding alert to add a
  Feeding or hide its overview alerts for 24 hours. Suppression is personal to
  each Shared Care account; schedules and detail reminders stay active (#233).
- Optional cropped/optimized pictures during Shared Care Animal/Box creation;
  retry an uncertain upload without creating a duplicate record (#232).

### Changed

- Place the Box scanner above Create Box and Feeding Mode above Create Animal;
  use the same archive icon in both overviews (#236, #237).
- Remove Standalone overview Rename actions; names remain editable through Edit (#231).
- Remove overdue-summary top/bottom outlines in both modes (#234).

## [1.15.2-1.15.4] - 2026-10-16

### Added

- Shared Care: committed revisions, targeted refresh, authenticated SSE and
  conditional fallback with reconnect/resume/restore handling; preserve drafts,
  conflict protection and bounded resources. Evaluation and integrated Pi/browser
  acceptance are recorded for #186 and #226-#230.
- Export an Animal as a width-adjustable label or a complete A4 profile with
  Feeding, Shedding and Weight histories, in Standalone and Shared Care; include
  the favorite picture and optionally the complete gallery (#141).
- Offer to restore an archived Box after scanning its QR code in Standalone and
  Shared Care (#219).

### Changed

- Keep Animal labels compact with a square favorite picture and shorter field
  labels; arrange optional A4 gallery pictures chronologically, including the
  primary picture, with four original-aspect images per page (#141).
- Place Restore Box above permanent deletion in Standalone archived Box details
  and remove the separate top restore button (#220).
- Migrate Android compilation to AGP Built-in Kotlin and compatible save/scanner
  plugins; retain the Flutter-required `android.newDsl=false` flag for a separate
  Android DSL migration (#212).

### Fixed

- Mark due Animals in the compact Shared Care overview (#217).
- Accept manual entry of the current Feeding time in Shared Care (#218).
- Keep the localized backup information title readable on narrow screens and
  with enlarged text, including German "Sicherungsinformationen" (#216).

## [1.15.1] - 2026-10-02

### Added

- allow each Animal to choose fixed weekdays, a time and a time zone for its feeding
  reminder while keeping existing interval reminders compatible
- open a chronological list of all active feeding appointments from the optional Next
  Feeding card in standalone and Shared Care

## [1.15.0] - 2026-10-02

### Added

- add optional password-protected portable backups to standalone and Shared Care with
  Argon2id, framed AES-256-GCM authentication, fresh salt/nonce material and encrypted
  pre-restore safety copies — Issues #203-#207
- keep the existing portable ZIP as the authenticated container payload and continue
  to import supported unencrypted Backup Format 1 and 2 archives
- add QR-based Box selection beside the New Animal dropdown in standalone and Shared
  Care; preserve the draft and create only on explicit Save
- reuse standalone picture cropping, orientation normalization and WebP processing for
  Shared Care Animal and Box uploads, including cancellation, upload limits and
  busy/error handling
- expose independent Weight and Shedding detail-visibility controls in Shared Care
  Edit Animal without deleting or changing the underlying history
- navigate ordered Animal and Box galleries in the common fullscreen viewer with
  Previous/Next, keyboard arrows, position counters and horizontal swipes at normal
  scale while preserving zoomed panning
- prepare localized, feature-focused standalone Play Store screenshots with synthetic
  demonstration data and reusable editable sources — Issues #180 and #181
- offer an optional Android Settings link to rate TerraManager, preferring the Play
  Store app with an HTTPS browser fallback and without automatic prompts, telemetry, a
  new permission or a new dependency — Issue #182

### Changed

- organize Shared Care client pages, widgets and API methods by feature and split
  server routing, application commands, authentication and persistence modules without
  changing API contracts, collection schema, portable backups or visible workflows;
  retain previous import paths as compatibility exports — Issue #185
- remove redundant Rename entries from Shared Care Box and Animal menus; validated
  name changes remain available through Edit and standalone menus are unchanged
- keep Shared Care password processing client-side for portable backup protection; the
  password is not persisted and is not sent to the Shared Care server
- spool native protected exports as ciphertext and authenticate protected imports
  before restore validation; handled temporary encrypted spools are removed after
  success or failure

### Fixed

- serialize Shared Care browser-history changes so a delayed context-menu Back event
  cannot dismiss the next duplicate, archive or picture-deletion dialog
- open Shared Care Animal and Box archives as real routes and retain thumbnail lists,
  archive reason/date and independent date/name sorting in normal and Big Picture
  presentation
- offer separate date and freely editable hour/minute controls for Shared Care
  Feeding, Weight and Shedding history entries
- avoid exposing raw standalone backup failure details through application logs and
  clear failed Web authentication buffers that may contain compacted plaintext

### Security and compatibility

- wrong passwords and authenticated data manipulation fail before collection
  replacement; the UI intentionally does not claim to distinguish those states
- native protected temporary backup files contain encrypted container data, not a
  plaintext portable ZIP
- large protected browser operations can still take several minutes and use
  substantial memory; bounded-memory optimization is tracked separately and is not
  claimed by this release

## [1.14.1] - 2026-09-27

### Added

- persist server-owned audit metadata for authenticated Shared Care collection and
  account changes — Issue #177
- retain stable actor identifiers and username/role snapshots without storing notes,
  pictures, passwords or session tokens; commit mutations and audit records together
  and retain audit history for 365 days
- add the Shared Care Manage accounts screen with username/role editing, optional
  password reset, deactivation/reactivation and confirmed removal — Issue #178
- revoke affected sessions after account changes, protect the last active
  administrator and retain previous audit attribution after account removal
- add an administrator-only Audit viewer under Shared server Settings with merged
  collection/account events, date/name/action filters, seek pagination and responsive
  localized states — Issue #179
- allow administrators to initialize a genuinely empty Shared Care collection from a
  portable backup without downloading an empty safety copy; populated collections
  retain the safety-token requirement — Issue #176
- show current Animal thumbnails in QR Feeding Mode for standalone and Shared Care,
  with the existing fallback for missing pictures

### Changed

- connect Shared Care detail, scanner and dialog routes to browser Back history so
  Android edge-back and in-app Back return within the interface without a duplicate
  route pop
- store Shared Care appearance, language, sorting and other personal display
  preferences per account in the server account database, with explicit defaults and
  isolation across login changes
- keep personal account preferences outside portable collection backups so they follow
  the signed-in account rather than the collection

### Fixed

- export care-event and metadata timestamps with explicit UTC offsets and use the
  original IANA time zone when importing legacy Shared Care values, including
  DST-sensitive event times and date-only birth dates
- restrict Shared Care permanent collection and picture deletion to administrators in
  both API and UI while preserving caregiver create, edit and archive workflows
- keep Box and Animal duplication dialogs open until confirmed success, select Animal
  name and destination together, prevent repeated submission and expose validation,
  permission and connection feedback
- use the active account's Animal-name order and fallback consistently in every Next
  Feeding overview, including compact presentation

### Security and compatibility

- audit entries deliberately omit free-text notes, pictures, passwords and session
  tokens and remain separate from portable collection backups
- account administration and audit metadata remain server-owned; standalone Database
  Schema Version 16 and Portable Backup Format Version 2 are unchanged

## [1.13.0] - 2026-09-26

### Added

- add a short, skippable guided introduction on the first launch of an empty
  standalone collection covering Boxes, Animals, feeding/reminders and QR workflows
- allow the standalone introduction to be replayed from Settings; it never creates
  sample collection data
- add the browser-local Show next feeding toggle above Big Picture Mode in Shared Care
  Settings
- respect that toggle in compact and Big Picture Animal overviews without hiding
  active due reminders

### Changed

- keep onboarding navigation inside the introduction itself; Back/Next move between
  steps and Finish/Skip closes the tour without changing the current primary page
- align Shared Care overview controls more closely with standalone workflows and keep
  Big Picture Mode in Settings
- reuse Shared Care overview pictures while scrolling, sorting, switching layouts and
  polling unchanged media IDs — Issue #184
- renew the picture snapshot when an overview opens, after returning from details or
  after manual Reload
- limit the Shared Care overview cache to 128 entries and 32 MiB of compressed
  pictures, with four concurrent loads and aspect-preserving thumbnail decoding
- clear overview picture caches and evict decoded entries when leaving the overview or
  signing out

## [1.11.0] - 2026-09-24

### Added

- introduce optional Shared Care LAN Web mode backed by a self-hosted Dart server that
  owns one authoritative SQLite collection for participating caregivers
- add a separate Shared Care browser client that reads and changes the shared
  collection only through the authenticated same-origin API instead of opening a local
  collection database or queuing offline edits
- provide local Shared Care accounts and authenticated collection operations for
  Boxes, Animals, care history, media and portable collection backup/restore
- add browser-based Box QR lookup for supported browsers; camera frames remain on the
  scanning device and only a validated TerraManager Box identifier is sent to the
  operator's server
- add an Android Settings entry that opens the configured Shared Care server in the
  system browser while keeping the Android standalone collection independent
- document self-hosted Raspberry Pi/LAN deployment, trusted HTTPS and the separation
  between portable collection backups and server-owned accounts

### Changed

- keep standalone Android and standalone Web local-first and independent from a Shared
  Care installation; opening Shared Care does not synchronize or replace either
  standalone collection
- make server unavailability an explicit Shared Care connection state rather than
  creating divergent offline edits
- keep server account/session data outside portable collection backups; host backups
  remain the operator's responsibility for that server-owned data

### Privacy and compatibility

- Shared Care communicates only with the user/operator configured self-hosted server;
  TerraManager does not introduce a developer-operated cloud service
- browser QR scanning does not upload camera frames to the server

## [1.10.4] - 2026-09-22

### Changed

- omit the Sex row from Animal details when no sex is stored or the stored value is
  `unknown`
- keep explicit Male, Female and Other values visible with their localized labels

### Fixed

- close the QR scanner and Edit Animal exactly once after a successful Rehouse
  operation
- prevent the Rehouse callback from popping an additional navigation route

## [1.10.3] - 2026-09-21

### Added

- add QR-based Rehouse Mode to Edit Animal
- allow an active destination Box to be selected with the existing QR scanner
- show an explicit confirmation before assigning the Animal to the scanned Box

### Changed

- make the Box scanner reusable through a resolved-Box callback and workflow-specific
  title
- perform Animal reassignment through one atomic repository operation
- close Edit Animal after a successful reassignment so the previous Box assignment
  cannot remain visible

### Privacy

- process QR identifiers and Box resolution locally
- reuse the existing camera permission and scanner implementation
- require no additional storage, media, network or background permission

## [1.10.2] - 2026-09-21

### Added

- add Restore actions to archived Animal and Box context menus
- allow an archived Animal to be restored directly after selecting an active Box
- allow an archived Box to be restored directly after confirmation
- add per-Animal controls for showing or hiding Weight and Shedding information on
  Animal details
- add an optional next-feeding summary to the Animal Overview

### Changed

- allow an existing Animal birth date to be cleared
- clear birth-date accuracy when the associated birth date is removed
- keep due feeding reminders unchanged while optionally showing the next upcoming,
  not-yet-due feeding
- persist `showWeightOnDetail` and `showSheddingOnDetail` on every Animal
- include the Animal detail-visibility fields and the next-feeding-summary setting in
  Portable Backup Format Version 2
- advance the local database to Schema Version 16

### Compatibility

- default both Animal detail-visibility fields to `true` for existing databases and
  older backups
- default `nextFeedingSummaryEnabled` to `false` when it is absent from an older
  backup
- retain Backup Format Version 2 because all new backup fields are additive

## [1.10.1] - 2026-09-21

### Added

- add a dedicated Box History page aligned with Animal History
- add archive sorting by newest or oldest archive date
- add archive sorting by ascending or descending displayed name
- add persistent local sort preferences for Animal History and Box History
- show Box thumbnails, labels and archive information in Box History
- expose the existing Duplicate action from archived Box entries

### Changed

- align Animal and Box archive presentation and interaction patterns
- keep archive sort preferences local to the current installation
- consolidate project and release documentation around authoritative shared documents

### Compatibility

- archive sort preferences affect presentation only
- archive sort preferences are not part of portable backup data

## [1.10.0] - 2026-09-20

### Added

- add an optional Big Picture Mode for Box and Animal overviews
- support Big Picture Mode in flat and category-grouped Animal views
- add a due-feeding indicator to the primary Animals navigation item
- replace the legacy free-form Animal shedding note with timestamped shedding history
  containing an optional note per event
- add quick shedding entry and shedding-history access to Animal details and Edit
  Animal
- add reverse-chronological shedding history with create, edit and confirmed delete
  actions

### Changed

- make the first Latest Feeding sort selection show the oldest latest feeding first
- persist Big Picture Mode between application restarts
- include `bigPictureModeEnabled` in Portable Backup Format Version 2
- migrate every non-empty legacy `Animal.sheddingNotes` value to one `SheddingEvent`
  using the Animal's existing `updatedAt` timestamp, then clear the legacy field
- stop New Animal, Edit Animal and Animal duplication from creating or copying legacy
  shedding-note values
- retain `Animal.sheddingNotes` only for database and portable-backup compatibility
  with earlier TerraManager versions
- preserve complete shedding history while Animals are archived and through Portable
  Backup Format Version 2 export and restore
- advance the local database to Schema Version 15 with the `SheddingEvents` table

### Compatibility

- default `bigPictureModeEnabled` to `false` when it is absent from an older backup
- restore older Animal records without `sheddingHistory` as an empty history
- continue to accept compatible legacy `sheddingNotes` values during migration and
  restore
- retain Backup Format Version 2 because the new data is additive

## [1.8.0 - 1.9.4]

### Added

- add an independent, persistent Animal Overview category-group toggle directly beside
  the sort control
- add shared side-by-side minimum and maximum controls for daytime temperature,
  nighttime temperature and humidity in New Animal and Edit Animal
- show the next scheduled feeding directly below Latest Feeding while an active
  reminder is not yet due
- add positive numeric Animal weights in grams with timestamped history and a
  reverse-chronological history view
- add a quick weight action beside Weight History on Animal details and add or edit or
  delete measurement actions inside the history view
- add a responsive German and English GitHub Pages homepage with shared localized
  content, download links, guides, support, local Privacy Policy and license access
- add a CSS-based device mockup and complete link-preview, favicon and page metadata
  without trackers, cookies, external scripts or web fonts
- show localized plural category and subcategory headings in grouped Animal Overview
  views
- add an optional bounded nighttime temperature to Animal profiles, details,
  duplication and portable backups
- make the assigned Box label on Animal details open the corresponding Box, including
  its optional name
- add persistent ascending and descending Box volume sorting based on complete width ×
  height × depth values

### Changed

- remove Category from the Animal sort menu and apply creation time, displayed name,
  age and latest-feeding sorting inside every final category group
- migrate legacy Category sort preferences to enabled category grouping with the
  equivalent displayed-name direction
- move the immutable Box QR identifier and its explanation below Notes and directly
  above Save and Archive in Edit Box
- label daytime and nighttime temperature explicitly on Animal details, format both
  ranges with one locale-aware decimal place and keep `°C` on values only
- arrange Additional characteristics consistently as birth date, accuracy, sex,
  weight, origin, nighttime temperature, rest periods, shedding notes and notes
- replace the single nighttime-temperature input with independent optional minimum and
  maximum values and migrate an existing value to both bounds
- migrate only unambiguous legacy gram values into weight history while retaining
  other legacy text until the user replaces it
- duplicate only an Animal's current weight as a fresh measurement and retain complete
  weight history through archive and portable backup workflows
- advance the local database to Schema Version 14 with nullable nighttime bounds and
  the `AnimalWeightEntries` table
- place only active due feeding reminders above the Animal picture and move Latest
  Feeding directly below the Animal names
- keep unnamed Boxes after every named Box in both alphabetical directions while
  retaining natural number ordering and deterministic ties
- rename Animal temperature inputs to minimum and maximum daytime temperature
- advance the local database to Schema Version 13; existing Animals receive a null
  nighttime temperature

### Privacy

- keep the v1.9.1 overview and Edit Box refinements local without database changes or
  new device, storage, media or network permissions
- keep v1.9.0 form, feeding and weight-history data entirely local without new device,
  storage, media or network permissions
- keep all v1.8.0 data, sorting and navigation local without adding device, storage,
  media or network permissions

## [1.7.2] - 2026-09-16

### Added

- add ordered picture histories to Animal and Box details, including local
  capture/import timestamps, full-screen viewing, selectable primary images and
  confirmed individual deletion
- preserve complete galleries, ordering and primary selection in Portable Backup
  Format Version 2

### Changed

- retain earlier pictures when a new Animal or Box picture is selected
- duplicate complete picture galleries with independent MediaAssets
- advance the local database to Schema Version 12 and migrate each existing persistent
  single picture into a one-entry gallery
- consolidate current documentation in the central guides, changelog and roadmap
  instead of maintaining per-release and per-issue files

### Privacy

- keep gallery storage, viewing and management local and reuse the existing
  user-initiated Camera and Gallery selection without adding device permissions

## [1.7.1] - 2026-09-15

### Changed

- move the optional temperature-zone note from Animal forms and details to the owning
  Box, directly above ordinary Box notes
- advance the local database to Schema Version 11 and transfer the first non-empty
  legacy Animal temperature-zone value by Animal ID to its assigned Box when that Box
  has no value
- extend Portable Backup Format Version 2 with Box temperature zones while retaining
  Format 1 and older Format 2 restore compatibility
- shorten the individual Box QR export description and separate the three QR export
  actions with the standard Settings dividers

## [1.7.0] - 2026-09-15

### Added

- add required Animal categories and optional category-specific subcategories to New
  Animal and Edit Animal, with localized labels and stable stored values
- display saved taxonomy on Animal details and preserve it during duplication
- add a Category criterion to Animal Overview that groups visible Animals under
  accessible category and conditional subcategory headings

### Changed

- advance the local database to Schema Version 10; existing Animals migrate to
  category `other` without a subcategory
- extend Portable Backup Format Version 2 with category and optional subcategory while
  retaining Format 1 and older Format 2 restore compatibility
- sort category groups in the complete taxonomy order and reverse only the primary
  group order when the active criterion is selected again
- keep subcategories and Animals A–Z inside groups using localized headings, natural
  number ordering and deterministic ID tie breaking

## [1.6.1] - 2026-09-15

### Added

- show stored pictures as thumbnails in Animal History, with the existing fallback for
  missing or invalid media and localized accessibility labels
- bundle a complete German privacy policy alongside the synchronized English policy
  and public privacy pages

### Changed

- simplify PDF QR sizing to the accessible integer slider from 6 mm to 20 mm while
  preserving the 15 mm default and generated document layout
- make Weight a multiline free-form field in New Animal and Edit Animal while
  preserving its existing database and backup representation
- present localized English or German legal information entirely offline and retain
  the unchanged authoritative English GPL-3.0-or-later text
- replace paired overview sort entries with one entry per criterion; selecting the
  active criterion reverses its direction while stored enum and backup values remain
  compatible

## [1.6.0] - 2026-09-15

### Added

- add one shared Settings selection workflow for active and archived Box QR codes,
  with all Boxes selected initially and individual opt-out
- save the selected QR codes as individual PNG images or one ZIP archive
- generate paginated A4 PDF sheets containing the selected QR codes, Box names and
  stable Box numbers
- choose the printed QR size from 6 mm to 20 mm with 6, 10, 15 and 20 mm presets

### Changed

- generate ZIP archives and vector PDF documents completely on-device before opening
  the operating-system save dialog
- prevent incomplete ZIP or PDF output when generation fails and treat a cancelled
  destination dialog as cancellation
- document the local QR export paths and unchanged permission boundary in the bundled
  and public privacy notices

## [1.5.0] - 2026-09-15

### Added

- add localized context menus to active Animal and Box overview entries, opened by
  long press or secondary click
- expose Create Feeding, Rename, Edit, Archive and Duplicate quick actions for active
  Animals
- expose Rename, Edit, Duplicate and Archive quick actions for active Boxes
- allow archived Animals to be duplicated from Animal History
- duplicate Boxes and Animals as independent active records while retaining their
  reusable profile data and copying picture media

### Changed

- assign every duplicated Box a new database ID and permanent QR identifier
- assign every duplicated Animal a new database ID and selected active Box, without
  copying lifecycle metadata or feeding history
- keep quick-action dialogs synchronized with the existing archive, validation and
  overview refresh behavior

## [1.4.0] - 2026-09-14

### Added

- show optional Box names together with the stable Box number in New Animal and Edit
  Animal assignment choices
- add the localized `Hermaphrodite / other` Animal sex value with the stable portable
  value `other`
- add an expandable Additional characteristics section to both Animal forms for origin
  or habitat, weight, shedding notes, rest or dormancy periods and temperature zones
- display only populated additional characteristics on Animal details
- add an offline License entry directly below Privacy Policy in Settings, backed by
  the authoritative repository `LICENSE` file

### Changed

- sort names containing numbers naturally in Box and Animal overviews, so names 1
  through 10 follow numeric order
- restrict humidity to 0–100 percent and temperature to the documented realistic range
  while retaining minimum/maximum ordering validation
- advance the local database to Schema Version 9 with five nullable Animal profile
  columns; existing records migrate with all five values empty
- extend Portable Backup Format Version 2 with the same optional fields while
  retaining restore compatibility with older Format 1 and Format 2 backups

## [1.3.0] - 2026-09-14

### Added

- added horizontal swipe navigation between the adjacent Box Overview, Animal Overview
  and Settings primary pages
- added localized semantics for the current primary page and navigation region
- added `Ctrl+Page Up` and `Ctrl+Page Down` as keyboard-compatible primary-page
  navigation

### Changed

- keep all primary pages in one state-preserving shell so overview scroll positions,
  selected sorting and Settings state survive swipe and tap changes
- keep the visible navigation indicator synchronized with swipe, keyboard and
  navigation-bar selection
- give the Box and Animal overview action buttons independent Hero identities while
  both pages remain alive in the shared shell
- refresh the Animal Overview immediately after an Animal is created directly from Box
  details, while preserving the overview state

## [1.2.0] - 2026-09-13

### Added

- added an Archive Box action to Edit Box with a required localized reason, optional
  archive note and explicit confirmation
- added an Archived Boxes entry point and a confirmed Restore Box action
- display archive reason, timestamp and notes on archived Box details
- added localized archived-QR results in both the Box and Feeding Mode scanners

### Changed

- filter active Box overviews and all Animal assignment choices to active Boxes
- recheck assigned active Animals transactionally before archiving and name blocking
  Animals in the explanation dialog; Animal lifecycle stays unchanged
- protect creation, reassignment and restoration of Animals from stale archived Box
  choices with transactional repository checks
- reject backups assigning active Animals to archived Boxes
- preserve the permanent QR identifier and stored Box data across archive and restore;
  restore clears archive metadata and makes the Box available again
- return to the originating overview after archive or restore, including after
  contextual detail swiping, and prevent repeated lifecycle submissions
- explain that unsaved Edit Box changes are discarded when archive is confirmed
- remove direct Box deletion from Edit Box; permanent deletion is available only at
  the bottom of archived Box details, matching the Animal archive workflow
- use the Box archive symbol consistently for the Box Overview navigation and Box
  thumbnails without pictures
- move Archive Animal from active Animal details to the bottom of Edit Animal; unsaved
  edits are explicitly disclosed before archive confirmation

## [1.1.2] - 2026-09-13

### Added

- added persistent Box lifecycle fields: active/archived status, archive reason,
  archive timestamp and optional archive notes
- added English and German labels for Sold, Replaced, Damaged and Other Box archive
  reasons; database and backup values remain language independent

### Compatibility

- corrected stale SQL definitions in the Version 5–7 schema snapshots from the
  existing historical models so regeneration retains reminder fields and Box names
- Database Schema Version 8 adds Box lifecycle columns while retaining all existing
  records; existing Boxes remain active with empty archive metadata
- Backup Format Version 2 includes all Box lifecycle fields; older Format 1 and Format
  2 backups without these fields restore Boxes as active
- backup validation rejects unknown lifecycle values, incomplete archived Box metadata
  and archive metadata on active Boxes
- archived records retain their permanent QR identifier, name, dimensions, picture and
  ordinary notes

## [1.1.1] - 2026-09-13

### Added

- added an optional free-form name to New Box and Edit Box
- added ascending and descending alphabetical Box-name sorting to the Box Overview
- added the optional Box name to current portable backups without changing Backup
  Format Version 2

### Changed

- display a named Box with its name as the primary overview label while keeping its
  generated Box number visible underneath
- display non-empty Box names prominently on Box details
- place unnamed Boxes after named Boxes in both alphabetical directions and use the
  Box ID as the deterministic tie-breaker
- advanced the development version to `1.1.1+51`

### Compatibility

- added nullable `Box.name` in Database Schema Version 7 with a data-preserving
  Version 6 to Version 7 migration
- kept existing Boxes unnamed until the user explicitly assigns a name
- kept Backup Format Version 2 backward compatible; backups without `name` restore
  with an empty Box name
- preserved the existing ascending and descending Box-number sort options and their
  legacy settings mappings

## [1.1.0] - 2026-09-12

### Added

- added an enabled-by-default checkbox for creating a safety backup during destructive
  Restore confirmation
- added an About TerraManager dialog under Legal & Privacy with the installed version,
  build number and developer information
- added a dedicated Feeding Reminder action to active Animal details so an existing
  Animal's reminder can be configured without opening Edit Animal
- added a targeted repository operation for updating only an active Animal's reminder
  interval and baseline
- added current Animal picture thumbnails to the assigned-Animal list on Box details,
  with the existing Animal fallback icon when no usable picture is available
- added optional multiline Box notes to New Box and Edit Box
- added a non-empty Box notes section to Box details

### Changed

- made the pre-restore safety backup optional for the current operation so an empty
  database can be restored without creating an unnecessary archive
- kept backup validation, explicit confirmation, settings rollback and transactional
  database replacement unchanged when the safety backup is disabled
- replaced the accent-color chip group with one compact localized dropdown while
  preserving immediate application and existing preference persistence
- made the Latest Feeding card on Animal details open the complete feeding history
  directly
- removed reminder controls from Edit Animal while preserving the Animal's current
  reminder configuration during ordinary detail changes
- refreshed the Animal-detail reminder state immediately after its dedicated
  configuration is saved
- moved the Box QR code, permanent identifier and remaining export action into one
  section at the bottom of Box details so Box information and assigned Animals appear
  first
- moved QR export from the Box-detail app bar into the QR section
- added nullable `Box.notes` in Database Schema Version 6 with a data-preserving
  Version 5 to Version 6 migration
- extended Backup Format Version 2 with backward-compatible optional Box notes;
  backups without the field restore with empty notes
- moved Box deletion from the Box-detail app bar to a dedicated destructive action at
  the bottom of Edit Box
- distinguished saved and deleted Edit Box results so successful deletion closes the
  stale detail route and refreshes the originating overview
- disabled saving, picture changes and navigation while Box deletion is in progress to
  prevent conflicting actions

### Removed

- removed QR printing from Box details
- removed the obsolete QR print service and its `printing` and `pdf` dependencies
- removed print-only localization and automated tests

## [1.0.0] - 2026-09-09

### Added

- added a GitHub Actions quality-gate workflow for locked dependency resolution,
  localization generation, formatting, analysis, complete tests, Android Debug and Web
  Release builds
- added a documented Flutter 3.47.2, Dart 3.13, Java 17, Android Gradle Plugin 9.1.0
  and Gradle 9.3.1 baseline with an explicit upgrade procedure
- added the complete GNU General Public License under the `GPL-3.0-or-later`
  identifier
- added public privacy and permission documentation for local data, camera, gallery,
  file, printing and Web-hosting behaviour
- added Android and Web installation, update, artifact-verification and pre-v1.0
  transition guidance
- added support, private-first security-reporting and contribution policies

### Changed

- adopted `com.codefrog.terramanager` as the permanent application identifier and
  Android namespace
- replaced remaining Flutter placeholder names in the prepared platform projects with
  TerraManager identity
- replaced placeholder Web title, description and installation metadata
- replaced the default Flutter Web icons and favicon with TerraManager artwork
- configured Android Release builds to use a dedicated production signing
  configuration instead of the debug signing key
- added ignored local-property and environment-variable credential sources for Android
  release signing
- made Release builds fail with a clear configuration error when credentials or the
  configured keystore are missing while keeping Debug builds independent of release
  secrets
- corrected the recorded final publication actions for the completed v0.11.0 and
  v0.12.0 releases
- linked public project documentation from the project overview
- replaced the ambiguous Scan another Box Quick Feeding action with an explicit Scan a
  different Box cancellation action
- clarified that this action discards the unsaved Box-specific feeding form, returns
  to Feeding Mode and restarts the scanner without creating events
- made overview sort widget tests target stable menu-item keys instead of text render
  positions

### Compatibility

- Android installations using the previous `com.example.flutter_application_1`
  identifier cannot be updated in place; users must export a backup in v0.14.1 and
  restore it into the new application
- debug-signed permanent-ID builds through `0.14.2+34` cannot be updated in place by
  the production-signed build; the existing backup, uninstall, install and restore
  transition must be used once more
- every later directly distributed Android update must use the same production signing
  certificate introduced with `0.14.3+35`
- CI builds an unsigned Android Debug APK; production-signed APK and AAB artifacts
  remain part of the protected local release workflow
- the temporary Built-in Kotlin compatibility flags remain enabled because three
  resolved plugins still apply the Kotlin Gradle Plugin
- v1.0.0 establishes the stable MVP feature and compatibility baseline for Android and
  Web
- iOS, macOS, Linux and Windows identity metadata is prepared but those platforms are
  not newly validated or promoted to supported status

## [0.14.1] - 2026-09-09

### Changed

- feeding reminders now use the latest FeedingEvent whenever feeding history exists,
  even when that event predates the reminder baseline
- the reminder baseline is now used only for Animals without FeedingEvents
- the Box Overview sort menu now contains only ascending and descending natural
  Box-number ordering
- ascending Box number is the new default ordering

### Compatibility

- existing `createdOldestFirst` Box preferences map to `labelAscending`
- existing `createdNewestFirst` Box preferences map to `labelDescending`
- legacy Box sort values remain valid during backup validation and restore
- new backups write only `labelAscending` or `labelDescending`

## [0.14.0] - 2026-09-09

### Added

- localized Animal Overview sorting by creation time, displayed name, age or latest
  FeedingEvent in both relevant directions
- deterministic handling for Animals without a birth date or FeedingEvent
- localized Box Overview sorting by creation time or natural Box number in ascending
  and descending directions
- a checked sort menu in the Box Overview app bar
- Add Animal action below both empty and populated assigned-Animal sections on Box
  details
- optional initial Box selection for the existing New Animal workflow

### Changed

- the Animal name sort follows the currently preferred displayed primary name
- Animals without a birth date remain last for both age directions; never-fed Animals
  appear first for oldest-feeding-first and last for newest-first
- Animal Overview reminder calculation and FeedingEvent sorting share one bulk
  latest-feeding lookup instead of querying per Animal
- contextual Animal detail navigation now receives the exact visible sorted order
- the selected Box order is applied immediately and persisted between application
  restarts
- contextual Box detail navigation now receives the exact visible sorted order
- replaced raw English Animal sex values with Male, Female and Unknown
- removed the duplicate Unknown entry from the New Animal and Edit Animal sex
  selectors
- made Unknown the explicit default for newly created Animals and the UI fallback for
  legacy Animals without a stored sex value
- replaced raw English birth-date-accuracy values with Exact, Month known and Year
  known
- kept the existing localized German sex and birth-date-accuracy labels
- direct Animal creation returns to the originating Box and refreshes its
  assigned-Animal list immediately after saving
- repeated Add Animal actions are blocked while the creation route is open

### Compatibility

- Animal sorting is a UI preference and requires no database migration
- portable backups include the optional `animalSortOrder` setting; older backups
  default to oldest-created Animal first
- Box sorting is a UI preference and requires no database migration
- portable backups include the optional `boxSortOrder` setting; older backups default
  to oldest-created Box first
- persisted Sex and BirthDateAccuracy enum values remain unchanged
- legacy nullable Animal sex values display as Unknown

## [0.13.0] - 2026-09-08

### Added

- optional per-Animal feeding reminder configuration in the new and edited Animal
  workflows
- localized English and German controls for enabling reminders and entering a positive
  whole-day interval
- persisted reminder baseline captured at the time a reminder is enabled
- database schema Version 5 with nullable reminder interval and baseline columns on
  Animals
- portable backup export, validation and restore for reminder configuration
- centralized feeding-reminder calculation with an injectable clock
- efficient bulk lookup of the latest FeedingEvent for all configured active Animals
- due-state results containing the relevant Animal, reference timestamp and calculated
  due timestamp
- non-modal Feeding Reminder summary in the Animal Overview
- due markers on affected Animal list entries
- due and scheduled reminder status cards on Animal details
- localized English and German reminder counts, states and due-date labels

### Changed

- Animal archive and restore operations retain reminder configuration
- Animal repository writes reject incomplete or non-positive reminder configurations
- reminder calculations use the later of the configured baseline and latest
  FeedingEvent
- reminder timestamps are normalized to the injected clock's UTC or local
  representation so calculations remain consistent across platform time zones
- reminder states are recalculated from current feeding history after event creation,
  editing or deletion
- an Animal is considered due at the exact due timestamp and remains due after it
- due reminder results are ordered by due timestamp, with the most overdue Animal
  first
- reminder presentation refreshes after FeedingEvent creation, editing or deletion and
  after Quick Feeding submissions
- reminder entries open the corresponding Animal, whose reminder status card links
  directly to the existing feeding history workflow

### Compatibility

- existing databases migrate from schema Version 4 to Version 5 without changing
  existing Animal data
- existing Animals receive disabled reminders because both new columns default to
  `null`
- portable backup exports remain at Backup Format Version 2
- older backups without reminder fields remain restorable and produce disabled
  reminders
- reminder calculation adds no persisted derived state and requires no further schema
  or backup-format migration

## [0.12.0] - 2026-09-08

### Added

- shared free-form picture cropping screen for Android and Web
- picture cropping after Camera and Gallery selection in new and edited Box and Animal
  forms
- localized cropping instructions, confirmation and error states
- injectable picture-selection flow for focused form tests
- shared WebP picture optimizer for newly selected and captured Box and Animal
  pictures
- bounded image dimensions and configurable compression parameters
- localized picture-processing progress in all new and edited Box and Animal forms
- shared backup-media format mapping for legacy pictures and normalized WebP media

### Changed

- selected pictures reach the form preview and persistent `MediaAssets` storage only
  after the crop is confirmed
- cancelling the crop keeps the current picture and form state unchanged
- source image orientation is normalized before the crop is calculated
- confirmed crops are resized to a maximum 1920-pixel longest edge and encoded as WebP
  with quality 82 before reaching form previews and `MediaAssets`
- new picture filenames and MIME metadata are normalized to `.webp` and `image/webp`
- picture actions and form saving are blocked while normalization is running
- repeated processing and save calls are ignored to prevent duplicate media records
- Box and Animal picture replacement now commits the normalized media, record
  reference and old-media cleanup atomically
- backup export preserves matching legacy extensions and uses known MIME metadata to
  resolve stale filenames
- backup restore recreates the filename, MIME type and original bytes for mixed legacy
  and WebP media without recompression

### Compatibility

- portable backup exports remain at Backup Format Version 2
- cropped pictures use the existing media persistence and backup flow
- existing stored pictures remain unchanged and continue to support their original
  formats
- WebP pictures use the existing Backup Format Version 2 media paths
- mixed PNG, JPEG and WebP archives remain supported without changing Backup Format
  Version 2

## [0.11.0] - 2026-09-07

### Added

- context-sensitive Add Picture and Change Picture actions for new and edited Box and
  Animal pictures
- shared Camera and Gallery source menu across all Box and Animal forms
- iOS photo-library usage description for future platform validation
- camera-light controls for the Box scanner and QR Feeding Mode scanner
- localized camera-light actions with a shared scanner control
- persistent setting for displaying either the common or Latin Animal name first
- reusable Animal display-name mapping shared by overview, history, detail,
  Box-assignment and quick-feeding views
- stable Animal name-order values in portable backup settings

### Changed

- unsupported camera picture sources are disabled inside the source menu without
  blocking Gallery use
- captured pictures use the existing persistent `MediaAssets` storage and portable
  backup flow
- scanner camera-light controls are hidden when the active camera does not provide a
  torch
- Animal name-order changes are applied immediately without restarting the app
- newly created backups include the preferred Animal name order in `settings.json`

### Compatibility

- portable backup exports remain at Backup Format Version 2
- backups without an Animal name-order field remain restorable and default to common
  name first

## [0.10.0] - Localization

### Added

- Flutter localization generation based on ARB resources
- English localization template for all user-visible application text
- complete German application translations
- persistent `System`, `English` and `Deutsch` language selection in Settings
- stable application-language values for portable backup and restore
- localized backup-validation messages

### Changed

- user-visible text is now resolved through generated Flutter localizations
- language changes are applied immediately without restarting the application
- the default language setting follows the operating-system locale
- unsupported system locales fall back to English
- newly created backups include the selected application language in `settings.json`
- backup restore applies the stored language together with theme and accent

### Compatibility

- portable backup exports remain at Backup Format Version 2
- the language field is an additive application-setting field and does not require a
  new backup format version
- backups created before language selection was introduced remain restorable
- a missing language field is interpreted as `System`

## [0.9.0] - Feeding Workflow & Media

### Added

- full-screen viewer for Box and Animal detail pictures
- picture zooming and panning with a scale range from 1x to 5x
- dedicated QR Feeding Mode entry point from the Box Overview
- Box QR scanning that resolves the currently assigned active Animals
- empty state for scanned Boxes without active Animals
- quick feeding form with one- or multi-Animal selection
- current date and time as the default feeding timestamp
- optional shared notes for quick feeding entries
- atomic creation of one FeedingEvent per selected Animal

### Changed

- Box and Animal detail pictures are now interactive and open in a separate
  full-screen route
- all active Animals assigned to a scanned Box are selected by default for a
  minimal-tap feeding workflow
- the Feeding Mode scanner resumes immediately after saving or cancelling a
  Box-specific feeding workflow
- normal Box QR scanning remains separate and unchanged

### Reliability

- grouped feeding inserts run inside one database transaction
- a failed insert rolls back the complete grouped feeding
- empty and duplicate Animal ID collections are rejected by the repository
- save controls are disabled while a grouped feeding is being written
- repeated save submissions do not create duplicate FeedingEvents

### Compatibility

- portable backup exports remain at Backup Format Version 2
- quick feeding entries use the existing FeedingEvent data model and appear in the
  existing feeding history

## [0.8.0] - Contextual Navigation

### Added

- reusable `DetailNavigationContext` for ordered Animal and Box collections
- navigation sources for Active Animals, Animal History, Box-specific Animals and Box
  Overview
- horizontal swipe navigation between contextual Animal detail records
- horizontal swipe navigation between contextual Box detail records
- first and last record navigation boundaries

### Changed

- Animal detail actions continue to target the currently displayed Animal after
  swiping
- Box edit, delete and QR actions continue to target the currently displayed Box after
  swiping
- Animal detail navigation is disabled if an edited Animal leaves its original source
  collection
- missing adjacent Boxes are removed safely from the in-memory navigation context
- normal detail navigation without swipe context remains supported

### Compatibility

- portable backup exports remain at Backup Format Version 2

## [0.7.1] - Maintenance

### Fixed

- preserve Box Overview scroll position after returning from Box details
- preserve Box Overview scroll position after returning from Box scanner and
  successful Box creation refreshes

## [0.7.0] - Editing & Overview

### Added

- optional Box width, height and depth
- persistent Box pictures backed by `MediaAssets`
- Box editing workflow
- human-readable Box labels (`Box N`) while preserving permanent QR identifiers
- Animal and Box thumbnails in overview lists
- FeedingEvent editing
- FeedingEvent deletion with confirmation
- Backup Format Version 2
- portable Box dimensions and Box pictures in backups
- `media/boxes/` archive media support

### Changed

- Box QR identifiers remain immutable when Box metadata is edited
- Latest Feeding is recalculated after FeedingEvent edits and deletions
- Animal Overview preserves its scroll position after detail/history navigation
- archived-Animal restore dialogs use human-readable Box labels
- safety backups include Box dimensions and Box pictures
- current backups are created as Backup Format Version 2
- restore continues to accept Backup Format Version 1

### Data Migration

- database schema upgraded from version 3 to version 4
- added nullable `Box.widthCm`
- added nullable `Box.heightCm`
- added nullable `Box.depthCm`
- added nullable `Box.pictureMediaId` referencing `MediaAssets`
- existing Boxes, Animals, FeedingEvents and media remain preserved

### Backup Compatibility

- Backup Format Version 2 is the current export format
- Backup Format Version 1 remains supported for restore
- Version 1 Box records restore with dimensions and Box picture fields set to `null`
- Box and Animal pictures are restored as new local `MediaAssets`
- permanent Box QR identifiers remain unchanged
- generated QR images remain excluded from backups

## [0.6.0] - Backup & Restore

### Added

- portable versioned `.tmbackup` backup format
- backup manifest with application version, backup format version and database schema
  version
- Box, Animal and FeedingEvent backup export
- appearance settings backup export
- Animal picture backup support
- backup archive validation before restore
- validation of record IDs and relationships
- lifecycle invariant validation
- QR identifier validation
- enum and settings validation
- media reference validation
- archive path traversal protection
- duplicate archive entry protection
- backup information and confirmation dialogs
- automatic pre-restore safety backup
- full replacement restore workflow
- persistent `MediaAssets` storage for Animal pictures
- `Animal.pictureMediaId` relationship
- legacy Animal picture migration
- Android and Web backup file selection
- user-selectable backup destination on Android

### Changed

- Animal pictures are now stored persistently in Drift/SQLite instead of relying on
  temporary `image_picker` paths
- restored Animal pictures are stored as `MediaAssets`
- restored Animals reference pictures through `pictureMediaId`
- portable backups no longer depend on local picture paths
- backup restore media handling is now part of the transactional database replacement
- Android backup saving now uses a user-selectable system file destination
- backup format version remains independent from database schema version

### Data Migration

- database schema upgraded from version 2 to version 3
- added `MediaAssets` table
- added nullable `Animal.pictureMediaId`
- existing Animal data is preserved
- existing `picturePath` values are preserved during schema migration
- readable legacy Animal pictures are migrated to persistent `MediaAssets` after
  startup
- unreadable legacy picture paths are retained without causing startup failure

### Backup Compatibility

- backups created from database schema version 2 remain restorable
- generated QR images remain excluded from backups
- permanent Box QR identifiers are preserved unchanged
- internal `MediaAsset` IDs are not part of the portable backup format

## [0.5.0] - Usability & Settings

### Added

- assigned animals on the box detail screen
- safe deletion workflow for empty boxes
- deletion protection for boxes containing active animals
- animal lifecycle with active and archived states
- archive reasons, dates and optional archive notes
- dedicated Animal History view
- restore workflow for archived animals
- permanent deletion of archived animals
- latest feeding information on animal details
- persistent System, Light and Dark appearance settings
- selectable application accent colors

### Changed

- animal overview now displays active animals only
- box details only display active assigned animals
- archived animals are no longer associated with an active box
- animal detail refreshes latest feeding information after returning from feeding
  history
- application theme is generated dynamically from the selected accent color
- UI appearance preferences are stored separately from domain data

### Data Migration

- database schema upgraded from version 1 to version 2
- existing animals are migrated as active
- existing box assignments are preserved
- existing feeding history is preserved

## [0.4.0] - Platform Support

### Added

- Android platform validation
- Web platform validation
- SQLite WASM database support for Web
- persistent Web database storage
- platform-aware QR image storage
- Android gallery storage for QR images

### Known Limitations

- iOS has not yet been validated
- Web data can be removed when browser site data is cleared
- Web camera, download and printing behavior depends on browser capabilities

## [0.3.0] - QR Code

### Added

- automatic box QR ID generation
- UUID-based QR identifiers
- QR code display
- QR code PNG export
- local QR image storage
- QR printing
- QR scanning
- TerraManager QR validation
- unknown QR handling
- invalid QR handling

## [0.2.0] - User Interface

### Added

- application navigation
- box overview
- box detail screen
- animal overview
- animal detail screen
- animal editing
- new box workflow
- new animal workflow
- feeding history
- animal notes
- animal picture support

## [0.1.0] - Foundation

### Added

- Flutter project foundation
- Drift/SQLite database
- Box data model
- Animal data model
- FeedingEvent data model
- Box → Animal relationship
- Animal → FeedingEvent relationship
- Sex enum and converter
- birth date accuracy support
- repository layer
- database tests
- repository tests
- initial Material 3 theme
