# Development Guide

## Requirements

Supported toolchain baseline:

- Windows 11
- Flutter 3.47.2 stable
- the Dart SDK bundled with Flutter 3.47.2
- Java 17
- Android Studio
- Visual Studio Code
- Git

On Windows, enable **Developer Mode** so Flutter can create the symbolic links
required by plugin builds:

```powershell
start ms-settings:developers
```

Enable **Developer Mode** in the opened Windows settings page before running
`flutter pub get` or rebuilding after `flutter clean`.

The complete Flutter, Android, Java, dependency and CI baseline is maintained
in [toolchain-baseline.md](toolchain-baseline.md). Use a separate maintenance
change for upgrades; do not change the toolchain implicitly while closing a
feature or release Issue.

## Initial Setup

Clone the repository and install dependencies:

```text
flutter pub get
```

Run static analysis:

```text
flutter analyze
```

Run tests:

```text
flutter test
```

The same core checks and Android Debug/Web Release builds run in GitHub Actions
for every push and pull request. Production Android signing remains a local,
protected release task and is never required by the public quality-gate job.

## Public Project Documentation

The public repository must keep these root documents current:

- `LICENSE` — GPL-3.0-or-later licence text
- `PRIVACY.md` — local data, permissions, exports and Web-hosting boundaries
- `SUPPORT.md` — supported platforms and useful issue reports
- `SECURITY.md` — private-first vulnerability reporting
- `CONTRIBUTING.md` — contribution and copyright policy

User-facing installation and update guidance is maintained in
`docs/installation-and-updates.md`. A release change affecting persistence,
permissions, platform services, distribution, signing, network behaviour or
support must review these documents before the issue is closed.

TerraManager is licensed under GPL-3.0-or-later. Do not copy code, artwork,
translations or documentation from an incompatible or unknown source. The
current contribution policy requires prior agreement for substantial external
contributions so that copyright ownership remains suitable for a possible
future commercial dual-licensing model.

## Localization Generation

English and German source messages are stored in:

```text
lib/l10n/app_en.arb
lib/l10n/app_de.arb
```

After changing either catalog, regenerate the Flutter localization classes:

```text
flutter gen-l10n
```

Generated files in `lib/l10n/generated/` must not be edited manually.

## Drift Code Generation

When Drift tables, converters or database definitions change:

```text
dart run build_runner build
```

Generated files such as:

```text
lib/core/database/app_database.g.dart
```

must not be edited manually.

When the Drift schema changes, also update generated migration steps with:

```text
dart run drift_dev make-migrations
```

Migration output must be reviewed and covered by schema migration tests.

Schema Version 5 adds the nullable Animal columns
`feedingReminderIntervalDays` and `feedingReminderBaseline`. Migration tests
must verify that Version 4 data is preserved and both fields are initialized to
`null` for existing Animals.

Schema Version 8 adds Box lifecycle state and archive metadata for Issue #102.
Regenerate Drift output and migration helpers after changing this schema.
Migration coverage includes all prior schema paths and a populated Version 7
database; restart and backup tests cover every Box archive reason and legacy
Format 1/2 defaults.

Issue #103 adds archive and restore UI workflows without another schema change.
Regression must cover occupied Boxes, assignments made while confirmation is
open, duplicate archive/restore calls, active-only assignment choices and stale
Animal forms. Test both QR scanners with archived and restored identifiers in
English and German. Confirm archive/restore navigation from a contextually
swiped Box and preservation of pictures, QR identifiers and ordinary notes.
Verify that active Boxes have no permanent-delete action, while archived Box
details offer the confirmed destructive action only at the bottom of the page.
Verify that active Animal details no longer expose archive directly and that
Edit Animal places the archive action after the save action with draft warning.
Physical camera behavior remains part of Android and Web manual validation.

Schema Version 9 adds the nullable Animal fields `originHabitat`, `weight`,
`sheddingNotes`, `restOrDormancyPeriods` and `temperatureZones` for Issue #112.
Regenerate Drift output, create the v9 schema snapshot and verify a populated
v8 database before changing the migration baseline. Existing values must remain
untouched and all five new fields must begin as `null`.

Portable Backup Format Version 2 carries these fields as optional strings.
Keep absent keys compatible with older Format 1 and Format 2 backups, reject
present non-string values and cover export, validation and restore together.
New Animal and Edit Animal share one additional-characteristics widget so their
labels, expansion behavior and field keys stay aligned. Detail pages must omit
the complete section when every value is empty.

Issue #113 uses the shared legal-document page for Privacy Policy and License.
The app bundles the root `LICENSE` directly instead of maintaining a second
copy. References are displayed as part of the local document without opening
an external application, matching the Privacy Policy behavior.

Issue #106 keeps Box Overview, Animal Overview and Settings in one
`IndexedStack` and adds horizontal root-page gestures around that container.
Do not replace the stack with independently rebuilt routes: overview scroll
controllers, sort choices and transient Settings state must survive both swipe
and navigation-bar changes. Keep horizontal drag thresholds separate from
vertical scrolling, and keep dialogs, dropdowns, crop routes and contextual
detail gestures above the root shell. The Box and Animal overview floating
actions require distinct Hero tags while both pages remain mounted.

Changes made from one retained page must explicitly refresh affected sibling
data. Direct Animal creation from Box details increments the Animal data
revision; `AnimalsPage.didUpdateWidget` reloads its query and restores the
existing scroll offset. Regression tests must first load Animal Overview, create
an Animal from Box details, and then prove that the same overview instance shows
the new record without restarting the application.

Schema Version 10 adds the required Animal category and nullable subcategory.
Regenerate Drift output, preserve the released v10 schema snapshot and verify a
populated v9 database. Existing Animals must migrate to `other` with a null
subcategory. New Animal and Edit Animal share one taxonomy widget and must offer
only category-compatible values. Repository, backup and restore paths must
reject unsupported or incompatible combinations while accepting missing
taxonomy values from older Format 1 and Format 2 backups.

Schema Version 11 adds the nullable Box temperature-zone note. Verify a direct
populated v10 migration: the first non-empty legacy Animal value by Animal ID
seeds its assigned Box only when the Box has no value, while Boxes without a
source stay empty and foreign keys remain valid. Current Animal forms and
details no longer expose the legacy column. Backup restore follows the same
non-destructive rule and accepts missing Box temperature-zone keys from older
Format 1 and Format 2 backups. Migration regressions assert data behavior and
snapshot transitions without hard-coding the current schema number.

Issue #128 derives category groups from the current filtered Animal list. Cover
the complete Issue #127 category order, reversed primary order, localized
headings, conditional subcategory headings, named subcategories followed by
Other and Not specified, and natural A–Z Animal ordering with ID tie breaking.
The row widgets retain thumbnails, reminders and quick actions, and contextual
detail navigation receives the flattened visible group order.

The three Settings QR export actions retain the shared selection workflow.
Keep the individual PNG description concise and use the same dividers as other
Settings action lists between PNG, ZIP and PDF.

## Android Development

TerraManager uses the permanent Android namespace and application ID:

```text
com.codefrog.terramanager
```

The main Activity is located at:

```text
android/app/src/main/kotlin/com/codefrog/terramanager/MainActivity.kt
```

Do not change the application ID after v1.0. Android uses it as part of the
installed application's identity, storage isolation and update path.

Builds through v0.14.1 used the temporary identifier
`com.example.flutter_application_1`. They cannot be updated in place by a build
using the permanent identifier. Export a `.tmbackup` from the old installation,
install the permanent-ID build and restore that backup before removing the old
application. Database Schema Version 5 and Portable Backup Format Version 2 do
not change for this transition.

Android Debug builds remain available without release credentials. Android
Release builds require a dedicated local production key and refuse to fall back
to the debug certificate. Follow `android-release-signing.md` to create the
keystore, configure either `android/key.properties` or environment variables,
back up the key and verify the resulting artifacts. Never commit the real
keystore or passwords.

List available devices:

```text
flutter devices
```

Run on Android:

```text
flutter run
```

Build debug APK:

```text
flutter build apk --debug
```

Build release APK:

```text
flutter build apk --release
```

Build release Android App Bundle:

```text
flutter build appbundle --release
```

Generated Android artifacts are located under:

```text
build/app/outputs/flutter-apk
build/app/outputs/bundle/release
```

## Web Development

TerraManager uses SQLite WASM through Drift on Web.

Repository-managed Web assets:

```text
web/sqlite3.wasm
web/drift_worker.dart
```

The compiled Drift worker is generated locally and in CI before a Web build.
The generated JavaScript, dependency list and source map are intentionally not
committed because they contain bundled dependency and Dart runtime code.

## Drift Worker

Source:

```text
web/drift_worker.dart
```

Compile the worker with:

```text
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
```

Run this command after `flutter pub get` and before `flutter build web`.

## SQLite WASM

`sqlite3.wasm` must match the compatible version of the resolved Dart `sqlite3` package.

Check the current dependency version with:

```text
flutter pub deps
```

After upgrading `sqlite3`, verify whether the Web WASM asset also needs to be updated.

Run Web Application:

```text
flutter run -d chrome
```

Build Web Application:

```text
flutter build web
```

## Recommended Validation Before Closing an Issue

Run:

```text
flutter analyze
flutter test
```

If platform-related code changed, additionally validate the affected platform manually.

For public-documentation changes, also run:

```text
flutter test test/platform/public_documentation_test.dart
```

For CI or toolchain changes, also run:

```text
flutter test test/platform/toolchain_quality_gates_test.dart
```

Review all Markdown links in the rendered GitHub repository and confirm that
no example contains a real password, backup, private path or signing secret.

Examples:

- camera access
- gallery storage
- browser downloads
- printing
- image picker
- picture cropping after Camera and Gallery selection
- WebP encoding of confirmed crops on Android and Web
- maximum 1920-pixel longest edge without upscaling
- `.webp` filename and `image/webp` MediaAsset metadata
- visible processing feedback and disabled picture/save actions during encoding
- duplicate-tap protection for picture processing and form saving
- reminder controls disabled by default for new Animals
- positive whole-day validation when a reminder is enabled
- reminder interval and baseline persistence after an application restart
- reminder configuration retention across archive and restore
- current and legacy backup round trips for reminder configuration
- reminder calculation from the latest FeedingEvent when present, otherwise
  from the reminder baseline
- exact due-boundary behavior with an injected clock
- recalculation after FeedingEvent creation, editing and deletion
- disabled and archived Animal exclusion from reminder results
- due ordering from most overdue to least overdue
- reminder calculation after restoring current backup data
- absence of a reminder summary when no active Animal is due
- Debug Android build without `android/key.properties`
- production-signed APK and AAB builds with local release credentials
- APK certificate verification and SHA-256 checksums
- non-modal due summary, due count and due markers in the Animal Overview
- most-overdue-first order and navigation to the correct Animal
- due and scheduled status cards with the calculated due timestamp on Animal
  details
- immediate refresh after FeedingEvent creation, editing and deletion
- Animal Overview refresh after a QR Quick Feeding submission
- English and German reminder counts and status labels
- absence of automatically opened dialogs or system-notification permission
  requests
- atomic replacement that retains the old picture after processing/save errors
- migration of existing Animal and Box pictures into one-entry galleries
- stable gallery ordering and capture/import timestamps
- adding a picture without deleting earlier gallery entries
- changing the primary picture and confirmed individual deletion
- gallery order and primary-selection backup round trips
- WebP and legacy image display in overview, detail and full-screen contexts
- unchanged display and backup behavior for existing JPEG and PNG pictures
- mixed PNG/JPEG and WebP backup export, validation and restore
- restored filename, MIME type and byte-for-byte media equality
- persistent database storage
- System, English and German language selection
- language persistence and unsupported-locale fallback
- language-setting backup and restore
- natural ascending/descending Box Overview sorting
- Box sort-order persistence after an application restart
- contextual Box detail swiping in the currently visible order
- Box sort-order backup, restore and legacy creation-order migration behavior
- oldest/newest creation order and natural ascending/descending Animal sorting
- oldest/youngest Animal sorting with missing birth dates placed deterministically
- newest/oldest FeedingEvent sorting with never-fed Animals placed deterministically
- Animal sorting based on the currently selected common/Latin primary name
- complete Animal taxonomy creation, editing, details and duplication
- populated v9 to v10 taxonomy migration with legacy `other` defaults
- taxonomy backup export, validation, restore and incompatible-value rejection
- category grouping in both primary directions with conditional localized
  subcategory headings and natural A–Z row ordering
- Animal sort-order persistence after an application restart
- contextual Animal detail swiping in the currently visible order
- Animal sort-order backup, restore and legacy-backup default behavior
- one bulk latest-feeding lookup for Animal sorting and reminder summaries

For image-storage measurements, use the same source picture and equivalent crop
before and after optimization. Record:

- source file byte size and dimensions
- stored WebP byte size and dimensions
- `.tmbackup` size or the corresponding archive media-entry size
- percentage reduction: `(originalBytes - webpBytes) / originalBytes * 100`

Test at least one landscape and one portrait photo. Also confirm that an
existing JPEG or PNG still opens and survives backup restore without being
rewritten.

The completed real-world measurement used a data set containing 44 Boxes, 45
Animals, 20 FeedingEvents and 67 pictures. Its portable backup decreased from
approximately 140 MB to 22.7 MB after normalization: about 117.3 MB or 83.8%
smaller, and roughly 6.2 times smaller overall.

## Recommended Release Validation

Before a milestone release, the release owner should run the supported quality
gates and platform checks for the affected source state:

```text
flutter clean
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build web
```

Then perform manual regression testing on every validated target platform,
verify signed artifacts and backups, and record the user-visible result in the
GitHub Release and `CHANGELOG.md`. Release-specific validation files are not
kept under `docs/`.

## Git Workflow

Recommended workflow:

```text
Issue
  ↓
Implementation
  ↓
Tests
  ↓
Manual validation
  ↓
Commit
  ↓
Push
  ↓
Close issue
```

Use focused commits where practical.

Generated build output should not be committed. This includes
`web/drift_worker.dart.js`, `web/drift_worker.dart.js.deps` and
`web/drift_worker.dart.js.map`; the quality-gate workflow regenerates them
before building the Web release.

Web runtime assets required by the application, such as `sqlite3.wasm` and the
compiled Drift worker, must be present in the generated Web build output.
