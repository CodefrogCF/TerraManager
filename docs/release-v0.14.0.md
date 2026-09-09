# v0.14.0 Release Validation

This document records the completed validation and publication preparation for
TerraManager `0.14.0+32`.

Validation completed successfully on 2026-09-09.

The release completes the Pre-1.0 UX Polish milestone. It improves everyday
Animal and Box workflows without changing the database schema or portable
backup format.

## Release Highlights

- localized Male, Female and Unknown Animal sex labels without duplicate
  Unknown entries
- localized Exact, Month known and Year known birth-date-accuracy labels
- an Add Animal action below empty and populated Box assignment sections
- direct New Animal navigation with the originating Box preselected and still
  editable
- immediate Box detail refresh after saving the new Animal
- persistent Box Overview sorting by creation time or natural Box number
- persistent Animal Overview sorting by creation time, displayed name, age or
  latest FeedingEvent
- deterministic placement of Animals without birth dates or FeedingEvents
- efficient bulk latest-feeding lookup shared by overview sorting and reminder
  calculation
- contextual Box and Animal detail navigation following the visible sorted
  order
- portable backup and restore support for both overview sort preferences
- complete English and German presentation for the new controls

## Validation Result

The final release regression completed successfully:

- `flutter analyze` reported no issues
- the complete automated test suite passed with 430 tests
- focused Animal and Box sorting, settings, localization and backup tests passed
- supported release builds completed successfully
- manual Box, Animal, sorting, navigation and persistence checks passed
- English and German labels and sorting controls were reviewed

The two Flutter widget-test hit-test messages emitted while selecting popup-menu
entries are non-failing test-harness warnings. They do not represent analyzer,
application or test failures.

## Compatibility

- Application Version: **0.14.0+32**
- Database Schema Version: **5** (unchanged)
- Portable Backup Format Version: **2** (unchanged)
- No database migration is required for v0.14.0.
- Persisted Sex and BirthDateAccuracy enum values remain unchanged.
- Legacy nullable Animal sex values display as Unknown.
- Current backups preserve Animal name order and both overview sort orders.
- Older backups without sort-order settings restore oldest-created-first
  defaults.
- Existing Animals, Boxes, FeedingEvents and media remain unchanged.
- Android and Web remain the supported and validated target platforms.
- iOS validation remains a stretch goal.

## Completed Issues

- [x] Issue #78: consistent Animal sex and birth-date-accuracy labels
- [x] Issue #79: direct Animal creation from Box details
- [x] Issue #80: persistent Box Overview sorting
- [x] Issue #81: persistent Animal Overview sorting
- [x] Issue #82: regression, documentation and v0.14.0 release preparation

## Final Automated Validation

The release was validated from the repository root with:

```text
flutter clean
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Focused v0.14.0 regression commands are:

```text
flutter test test/features/animals/presentation/animal_overview_sorting_test.dart
flutter test test/features/animals/presentation/pages/animals_page_test.dart
flutter test test/features/animals/presentation/pages/new_animal_page_test.dart
flutter test test/features/animals/presentation/pages/animal_edit_page_test.dart
flutter test test/features/animals/presentation/pages/animal_detail_page_test.dart
flutter test test/features/boxes/presentation/box_overview_sorting_test.dart
flutter test test/features/boxes/presentation/pages/boxes_page_test.dart
flutter test test/features/boxes/presentation/pages/box_detail_management_test.dart
flutter test test/features/settings/app_settings_controller_test.dart
flutter test test/features/settings/presentation/pages/settings_backup_test.dart
flutter test test/features/backup
flutter test test/l10n/localization_infrastructure_test.dart
```

Confirmed results:

- [x] Dart formatting check completed without changes
- [x] `flutter analyze` reported no issues
- [x] complete automated test suite passed with 430 tests
- [x] Animal and Box sorting unit tests passed
- [x] overview persistence and contextual-navigation widget tests passed
- [x] settings backup, validation, restore and legacy-default tests passed
- [x] English and German localization tests passed

## Release Builds

The supported artifacts are built with:

```text
flutter build apk --debug
flutter build apk --release
flutter build web
```

Confirmed results:

- [x] supported builds completed successfully
- [x] application reports Version `0.14.0` and Build `32`

The Android release artifact is normally created at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Record its SHA-256 checksum before attaching it to the GitHub release:

```powershell
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
```

## Manual Regression

### Animal Forms and Box Assignment

- [x] New Animal shows exactly Male, Female and Unknown
- [x] Edit Animal shows exactly Male, Female and Unknown
- [x] birth-date accuracy uses localized human-readable labels
- [x] legacy missing-sex data displays as Unknown
- [x] an empty Box detail displays Add Animal
- [x] a populated Box detail displays Add Animal below assigned Animals
- [x] New Animal opens with the originating Box preselected
- [x] the preselected Box remains editable
- [x] saving returns to the Box and refreshes its assigned-Animal list
- [x] cancelling leaves the Box unchanged

### Box Overview Sorting

- [x] oldest-created-first ordering
- [x] newest-created-first ordering
- [x] ascending natural Box-number ordering
- [x] descending natural Box-number ordering
- [x] selected order persists after an application restart
- [x] contextual detail swiping follows the visible Box order

### Animal Overview Sorting

- [x] oldest-created-first ordering
- [x] newest-created-first ordering
- [x] displayed-name A-Z and Z-A ordering
- [x] oldest-Animal-first and youngest-Animal-first ordering
- [x] newest-feeding-first and oldest-feeding-first ordering
- [x] name sorting follows the selected common or Latin primary name
- [x] Animals without birth dates remain in the documented position
- [x] never-fed Animals remain in the documented position
- [x] selected order persists after an application restart
- [x] contextual detail swiping follows the visible Animal order

### Settings and Backup

- [x] Animal and Box sort preferences persist locally
- [x] a current backup preserves both sort preferences
- [x] restoring a current backup restores both sort preferences
- [x] an older backup without sort settings restores successfully
- [x] older backups use oldest-created-first defaults
- [x] existing database and media content remains intact

## Documentation Review

- [x] version changed to `0.14.0+32`
- [x] Changelog finalized as `[0.14.0] - 2026-09-09`
- [x] README updated for the completed v0.14.0 release
- [x] Roadmap updated for Issues #78 through #82
- [x] platform validation updated for the new workflows
- [x] backup compatibility and development documentation reviewed
- [x] final validation results recorded