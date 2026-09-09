# v0.13.0 Release Validation

This checklist records the completed validation and publication preparation of
TerraManager `0.13.0+27`.

Validation completed successfully on 2026-09-08.

The release introduces local, optional per-Animal feeding schedules and
non-modal in-app reminders. It contains:

- an optional positive whole-day feeding interval for each Animal
- a baseline captured when a reminder is enabled
- database persistence and Version 4 to Version 5 migration
- portable backup and legacy-backup compatibility
- due-state calculation from the later of baseline and latest FeedingEvent
- deterministic exact-boundary behavior with an injectable clock
- bulk latest-feeding lookup without an N+1 query pattern
- a non-modal due summary and due markers in the Animal Overview
- due or scheduled status with the calculated timestamp on Animal details
- direct navigation to the existing feeding workflow
- immediate recalculation after normal and QR Quick Feeding changes
- complete English and German reminder presentation

The milestone remains fully local and offline. It does not request system
notification permissions.

## Validation Result

The release validation completed successfully:

- Dart formatting and static analysis passed
- the complete automated test suite and focused reminder regressions passed
- schema migration and current/legacy backup compatibility passed
- Android debug APK, Android release APK and Web release builds completed
- Android and Web manual reminder and general regression checks passed
- English and German reminder text was reviewed

## Compatibility

- Database Schema Version: **5**
- Portable Backup Format Version: **2** (unchanged)
- Existing Version 4 databases migrate without losing domain or media data.
- Existing Animals receive disabled reminders after migration.
- Older backups without reminder fields restore with reminders disabled.
- Current backups preserve reminder interval and baseline values.
- Archived Animals retain their configuration but are excluded from active
  reminder results.
- Android and Web remain the validated target platforms.
- iOS and system notifications remain deferred stretch goals.

## Completed Implementation Baseline

The issue-level work completed before final release validation includes:

- [x] Issue #74: per-Animal configuration, schema migration and backup support
- [x] Issue #75: deterministic calculation, bulk query and recalculation tests
- [x] Issue #76: overview summary, list markers, detail status and navigation
- [x] English and German reminder catalogs
- [x] focused repository, migration, backup, service and widget tests
- [x] successful issue-level analysis, automated tests, build and manual checks

## Final Automated Validation

Run from the repository root after applying the release files:

```text
flutter clean
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
```

Run the focused database, backup and reminder regression:

```text
flutter test test/drift/app_database/migration_test.dart
flutter test test/core/database/repositories/animal_repository_test.dart
flutter test test/features/backup
flutter test test/features/animals/presentation/pages/new_animal_page_test.dart
flutter test test/features/animals/presentation/pages/animal_edit_page_test.dart
flutter test test/features/feedings/application/feeding_reminder_service_test.dart
flutter test test/features/feedings/presentation/pages/feeding_reminder_ui_test.dart
flutter test test/features/feedings/presentation/pages/quick_feeding_entry_test.dart
flutter test test/l10n/localization_infrastructure_test.dart
```

Finally, run the complete suite:

```text
flutter test
```

Required results:

- [x] Dart formatting check passes without changes
- [x] `flutter analyze` reports no issues
- [x] Version 4 to Version 5 migration tests pass
- [x] Animal reminder persistence tests pass
- [x] current and legacy backup tests pass
- [x] reminder calculation and exact-boundary tests pass
- [x] reminder presentation and refresh widget tests pass
- [x] English and German localization tests pass
- [x] complete automated test suite passes

## Release Builds

Build the supported release artifacts:

```text
flutter build apk --debug
flutter build apk --release
flutter build web
```

Required results:

- [x] Android debug APK builds successfully
- [x] Android release APK builds successfully
- [x] Web release build completes successfully
- [x] application reports Version `0.13.0` and Build `27`

The Android release artifact is normally created at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Record its SHA-256 checksum before attaching it to the GitHub release:

```powershell
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
```

## Android Manual Validation

### Upgrade and Migration

- [x] install `0.13.0+27` over a Version 4 TerraManager installation
- [x] confirm existing Boxes, Animals, FeedingEvents, settings and pictures
  remain available
- [x] confirm existing Animals initially have reminders disabled
- [x] restart the application and confirm all migrated data remains available

### Reminder Configuration

- [x] create an Animal with reminders disabled
- [x] create an Animal with a valid positive whole-day interval
- [x] confirm an empty, zero or negative enabled interval cannot be saved
- [x] enable a reminder on an existing Animal and confirm it is not immediately
  overdue without feeding history
- [x] change an enabled interval and confirm its baseline remains available
- [x] disable a reminder and confirm the reminder UI disappears
- [x] restart the application and confirm enabled configuration persists

### Due-State Calculation and Presentation

- [x] confirm an Animal without FeedingEvents uses its reminder baseline
- [x] confirm a later FeedingEvent replaces the baseline as calculation source
- [x] confirm the displayed due timestamp matches the configured interval
- [x] confirm the Animal Overview shows no summary when no Animal is due
- [x] confirm the summary displays the correct number of due Animals
- [x] confirm due entries are ordered from most overdue to least overdue
- [x] confirm due Animals are marked in the normal overview list
- [x] confirm Animals that are not due do not appear in the summary
- [x] tap a reminder and confirm the correct Animal opens
- [x] tap the detail status card and confirm Feeding History opens
- [x] confirm no automatic modal reminder dialog is displayed
- [x] confirm no system-notification permission is requested

### Feeding Changes

- [x] add a FeedingEvent and confirm the reminder disappears or is rescheduled
- [x] edit the latest FeedingEvent and confirm the due state recalculates
- [x] delete the latest FeedingEvent and confirm the previous event or baseline
  becomes the calculation source
- [x] create a QR Quick Feeding entry and confirm the Animal Overview refreshes
- [x] restart the application and confirm the recalculated state remains correct

### Animal Lifecycle

- [x] archive an Animal with an enabled reminder
- [x] confirm the archived Animal disappears from active reminder results
- [x] confirm its interval and baseline remain stored
- [x] restore the Animal into a Box
- [x] confirm its reminder configuration and calculated state return

### Localization

- [x] review all reminder configuration and validation text in English
- [x] review summary, count, due marker and detail status text in English
- [x] review all reminder configuration and validation text in German
- [x] review summary, count, due marker and detail status text in German
- [x] confirm singular and plural due counts are grammatically correct

## Backup Regression

- [x] create a backup containing enabled and disabled Animal reminders
- [x] restore it and confirm intervals and baselines are preserved
- [x] confirm restored reminder calculations use restored FeedingEvents
- [x] restore an older backup without reminder fields
- [x] confirm older-backup Animals receive disabled reminders
- [x] confirm invalid or incomplete reminder data is rejected before replacement
- [x] confirm the pre-restore safety backup is still created
- [x] confirm legacy and WebP pictures remain readable after restore

## Web Manual Validation

- [x] start the Web release in a supported Chromium-based browser
- [x] confirm existing browser data migrates and remains available
- [x] configure, change and disable an Animal reminder
- [x] confirm overview summary, due markers and detail status display correctly
- [x] confirm FeedingEvent creation, editing and deletion refresh reminders
- [x] confirm English and German reminder presentation
- [x] export and restore a current reminder backup
- [x] restore an older backup and confirm reminders default to disabled
- [x] complete a general Box, Animal, Feeding, Settings and media regression

## Documentation Review

- [x] version changed to `0.13.0+27`
- [x] Changelog finalized as `[0.13.0] - 2026-09-08`
- [x] README updated for the completed v0.13.0 release
- [x] Roadmap updated for Issue #77
- [x] reminder architecture and data-model documentation reviewed
- [x] functional requirements include configuration, calculation and UI
- [x] Backup Format Version 2 compatibility documented
- [x] Android/Web platform validation reference added
- [x] final validation results recorded after local testing

## GitHub Release Description

Use the following text after every required validation succeeds:

```markdown
## TerraManager v0.13.0 – Feeding Reminders

TerraManager v0.13.0 introduces optional, local feeding schedules and visible
in-app reminders for individual Animals.

### Highlights

- Configure an independent feeding interval for each Animal.
- Keep reminders disabled by default and validate positive whole-day intervals.
- Calculate the next feeding from the later of the reminder baseline and latest
  FeedingEvent.
- See due Animals in a non-modal, most-overdue-first overview summary.
- Identify due Animals directly in the normal Animal list.
- View the due or scheduled timestamp on Animal details.
- Open the existing feeding workflow directly from a reminder.
- Refresh reminders after feeding creation, editing, deletion and QR Quick
  Feeding.
- Use the complete reminder workflow in English or German.

### Compatibility

- Database Schema Version: 5
- Portable Backup Format Version: 2 (unchanged)
- Existing databases migrate with reminders disabled and without data loss.
- Current backups preserve reminder configuration.
- Older backups restore with reminders disabled.
- Archived Animals retain configuration but do not produce active reminders.
- Android and Web are supported and regression-tested.
- System notifications and iOS validation remain stretch goals.
```

## Final Release Actions

Complete only after every required validation succeeds:

- [x] record all confirmed results in this checklist
- [x] update README and Roadmap from release candidate to completed release
- [x] mark all validated Issue #77 Roadmap items complete
- [x] commit and push the final release documentation
- [x] create annotated tag `v0.13.0`
- [x] push tag `v0.13.0`
- [x] publish the GitHub v0.13.0 release with the release APK and checksum
- [x] close Issue #77
- [x] close the v0.13.0 milestone

Recommended Git commands after the final documentation commit:

```text
git tag -a v0.13.0 -m "TerraManager v0.13.0"
git push origin v0.13.0
```
