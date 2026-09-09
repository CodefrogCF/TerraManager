# v0.14.1 Release Validation

This document records the completed validation and publication preparation for
TerraManager `0.14.1+33`.

Validation completed successfully on 2026-09-09.

The release is a focused post-release patch for feeding reminder calculation
and Box Overview sorting. It does not change the database schema or portable
backup format.

## Release Highlights

- use the latest FeedingEvent as the reminder reference whenever feeding
  history exists, even when the event predates reminder activation
- use the reminder baseline only for Animals without FeedingEvents
- allow existing feeding history to make a newly enabled reminder immediately
  due when its interval has already elapsed
- reduce Box Overview sorting to ascending or descending natural Box number
- use ascending Box number as the default
- migrate stored legacy Box creation-order preferences to the corresponding
  Box-number direction
- accept and map legacy Box sort values while restoring older backups
- write only current Box sort values to new backups

## Validation Result

The final patch regression completed successfully:

- `flutter analyze` reported no issues
- the complete automated test suite passed with 433 tests
- Dart formatting completed without changes
- Android and Web builds completed successfully
- the Android release APK built successfully at 82.8 MB
- manual reminder, Box sorting, persistence and backup checks passed
- English and German presentation remained functional

The two Flutter widget-test hit-test messages emitted while selecting popup-menu
entries are non-failing test-harness warnings. They do not represent analyzer,
application or test failures.

The dependency update notices and Gradle/Kotlin compatibility notices emitted
during the build are advisory. They did not prevent this release from building
or passing its regression suite.

## Compatibility

- Application Version: **0.14.1+33**
- Database Schema Version: **5** (unchanged)
- Portable Backup Format Version: **2** (unchanged)
- No database migration is required for v0.14.1.
- Existing Animals, Boxes, FeedingEvents and media remain unchanged.
- Stored `createdOldestFirst` Box preferences migrate to `labelAscending`.
- Stored `createdNewestFirst` Box preferences migrate to `labelDescending`.
- Legacy Box sort values remain accepted during backup validation and restore.
- New backups write only `labelAscending` or `labelDescending`.
- Android and Web remain the supported and validated target platforms.
- iOS validation remains a stretch goal.

## Final Automated Validation

The release was validated from the repository root with:

```text
flutter pub get
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter build apk --release
```

The remaining supported builds and manual regression checks also completed
successfully.

Confirmed results:

- [x] Dart formatting completed without changes
- [x] `flutter analyze` reported no issues
- [x] complete automated test suite passed with 433 tests
- [x] reminder calculation regression tests passed
- [x] Box Overview sorting and persistence tests passed
- [x] settings migration and backup compatibility tests passed
- [x] English and German localization tests passed

## Release Builds

The supported artifacts were built with:

```text
flutter build apk --debug
flutter build apk --release
flutter build web
```

Confirmed results:

- [x] debug APK build completed successfully
- [x] release APK build completed successfully
- [x] Web release build completed successfully
- [x] application version and build are `0.14.1+33`

The Android release artifact is normally created at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Record its SHA-256 checksum before attaching it to the GitHub release:

```powershell
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
```

## Manual Regression

### Feeding Reminders

- [x] an Animal with existing feeding history uses its latest FeedingEvent
- [x] an older FeedingEvent remains authoritative after enabling a reminder
- [x] an Animal without feeding history uses the reminder baseline
- [x] adding or editing the latest FeedingEvent reschedules the reminder
- [x] deleting the final FeedingEvent falls back to the reminder baseline
- [x] the reminder summary and Animal detail status refresh correctly

### Box Overview Sorting

- [x] the sort menu contains only ascending and descending Box-number options
- [x] ascending Box-number sorting works correctly
- [x] descending Box-number sorting works correctly
- [x] the selected order persists after an application restart
- [x] contextual Box detail navigation follows the visible order
- [x] legacy local sort preferences migrate to the documented direction

### Settings and Backup

- [x] current backups write only current Box sort values
- [x] current backups restore both Box sort directions
- [x] legacy Box sort values validate and restore successfully
- [x] existing database and media content remains intact

## Documentation Review

- [x] version confirmed as `0.14.1+33`
- [x] Changelog finalized as `[0.14.1] - 2026-09-09`
- [x] README updated for the completed v0.14.1 release
- [x] Roadmap updated for the completed post-release patch
- [x] platform validation updated
- [x] reminder and backup compatibility documentation reviewed
- [x] final validation results recorded

## GitHub Release Description

Use the following text for the GitHub release:

```markdown
## TerraManager v0.14.1 – Post-release Fixes

TerraManager v0.14.1 is a focused compatibility patch for feeding reminders and
Box Overview sorting.

### Highlights

- Calculate reminders from the latest FeedingEvent whenever feeding history
  exists, including events recorded before reminder activation.
- Use the reminder baseline only for Animals without feeding history.
- Sort Boxes by ascending or descending natural Box number.
- Replace the redundant Box creation-time choices with the two meaningful
  Box-number directions.
- Migrate existing Box sort preferences automatically.
- Preserve compatibility with older backups containing legacy Box sort values.

### Compatibility

- Database Schema Version: 5 (unchanged)
- Portable Backup Format Version: 2 (unchanged)
- No database migration is required.
- Existing data and media remain unchanged.
- Android and Web remain supported and regression-tested.
- iOS validation remains a stretch goal.
```

## Final Git and GitHub Actions

Confirm that the worktree contains only the intended patch and release changes.
Then commit and push the finalized source, tests and documentation before
creating the tag:

```text
git status
git add -A
git diff --cached --stat
git commit -m "release: prepare TerraManager v0.14.1"
git push origin main
```

Create and push the annotated release tag from that exact commit:

```text
git status
git tag -a v0.14.1 -m "TerraManager v0.14.1"
git push origin v0.14.1
```

After the tag is visible on GitHub:

1. Create the GitHub release from tag `v0.14.1`.
2. Use the release description above.
3. Attach the release APK and its SHA-256 checksum.
4. Close the v0.14.1 milestone if one was created for the patch.
