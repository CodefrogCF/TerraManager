# v1.7.0 Release Validation

This document records the source and release-owner validation boundary for
TerraManager `1.7.0+64`. Version 1.7.0 completes the Animal Taxonomy & Category
Views milestone delivered by Issues #127 and #128. Automated source checks are
recorded independently from signed artifacts, which are created only in the
release owner's protected environment.

## Release Highlights

- require a localized primary category in New Animal and Edit Animal
- offer an optional subcategory only when it is compatible with that category
- display the stored category and optional subcategory on Animal details
- preserve taxonomy through editing and Animal duplication
- migrate existing Animals to Other without a subcategory
- carry stable taxonomy values in backward-compatible Format 2 backups
- add a Category criterion to Animal Overview
- group every visible Animal under localized, accessible category headings
- show subcategory headings only when they distinguish Animals in a category
- retain natural A–Z Animal order, thumbnails, reminders and quick actions
- use the flattened visible grouping for contextual detail navigation
- add no storage, media, network or other device permission

## Compatibility Baseline

- Application Version: **1.7.0+64**
- Database Schema Version: **10**
- Portable Backup Format Version: **2**
- Android application ID: `com.codefrog.terramanager`
- Production certificate SHA-256:
  `f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748`
- Supported release platforms: Android and Web
- iOS, macOS, Linux and Windows remain unvalidated release platforms.

A production-signed v1.6.x installation can be updated directly. The v9 to v10
migration adds one non-null category column with default `other`, one nullable
subcategory column. Existing Boxes, Animals, FeedingEvents, settings and media
remain available; existing Animals begin as Other without a subcategory. The
released Schema Version 10 snapshot retains the existing Animal
temperature-zone column and has no Box temperature-zone column.

Portable Backup Format Version 2 adds `category` and `subcategory` to Animal
records. Missing taxonomy keys in Format 1 and older Format 2 records restore
with safe defaults. Present unknown, localized or incompatible taxonomy values
fail validation before current application data is modified.

## Stable Animal Taxonomy

The primary categories use this canonical order:

```text
amphibian
reptile
arachnid
insect
myriapod
crustacean
mollusc
otherInvertebrate
other
```

Optional compatible subcategories are:

```text
amphibian: frogOrToad, newtOrSalamander, other
reptile: snake, lizard, turtle, other
arachnid: tarantula, otherSpider, scorpion,
          whipSpiderOrWhipScorpion, other
insect: beetle, cockroach, mantis, grasshopperOrCricket, other
myriapod: millipede, centipede, other
crustacean: isopod, crab, other
mollusc: snail, other
otherInvertebrate: no subcategory
other: no subcategory
```

`otherSpider` covers spiders that do not use the separately represented
Tarantula value. Localized English and German labels are presentation data and
are not written to the database or portable backup.

## Category Overview Behavior

Category sorting includes all primary categories from Issue #127 and omits
empty groups. Reversing the active criterion reverses only primary category
order. Animal order inside every final group remains natural A–Z according to
the selected common-name-first or Latin-name-first setting, with database ID as
the deterministic final tie breaker.

When no Animal in a category has a subcategory, the category contains rows
directly without redundant detail headings. Once a subcategory is present,
localized named subcategories are ordered by their headings, followed by Other
and then Not specified when present. The same flattened row order is supplied
to contextual detail navigation.

## Automated Source Validation

Run from the repository root using the supported toolchain documented in
[toolchain-baseline.md](toolchain-baseline.md):

```text
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev make-migrations
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Recorded source result:

- [x] dependencies were resolved for source validation
- [x] localization generation completed successfully
- [x] Drift Schema Version 10 and migration helpers were generated
- [x] Dart formatting completed without changes
- [x] `flutter analyze --no-pub` reported no issues
- [x] complete automated test suite passed
- [x] Android and iOS permission declarations remained unchanged
- [x] final GitHub Actions **Quality gates** run passed on the release commit

Focused milestone coverage includes:

```text
flutter test test/drift/app_database/animal_taxonomy_migration_test.dart
flutter test test/features/animals/presentation/widgets/animal_taxonomy_fields_test.dart
flutter test test/features/animals/presentation/pages/new_animal_page_test.dart
flutter test test/features/animals/presentation/pages/animal_detail_page_test.dart
flutter test test/features/animals/presentation/pages/animals_page_test.dart
flutter test test/features/animals/presentation/animal_overview_sorting_test.dart
flutter test test/features/backup/domain/backup_enum_codec_test.dart
flutter test test/features/backup/application/backup_validation_service_test.dart
flutter test test/features/backup/application/backup_export_service_test.dart
flutter test test/features/backup/application/backup_restore_service_test.dart
flutter test test/platform/v1_7_release_documentation_test.dart
```

- [x] shared taxonomy controls and incompatible-value clearing passed
- [x] New/Edit persistence, details and Animal duplication passed
- [x] populated v9 to v10 migration and legacy defaults passed
- [x] taxonomy backup export, validation and restore passed
- [x] complete category order and reversed primary order passed
- [x] conditional headings, natural row sorting and deterministic ties passed
- [x] persisted sort settings and flattened contextual navigation passed
- [x] existing thumbnail, reminder and quick-action behavior passed
- [x] no new device or network permission passed

## Release-owner Builds

The following commands document the protected release-owner workflow. They are
not part of automated update-package preparation. Automated assistants must not
create TerraManager release artifacts because they do not have the
authoritative signing environment.

```text
flutter build apk --debug --no-pub
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
flutter build web --release --no-pub
```

- [x] release owner produced and verified the supported artifacts
- [x] release APK reports Version `1.7.0` and Build `64`
- [x] release AAB reports Version `1.7.0` and Build `64`
- [x] Web release completed from the same source commit

## Signature and Artifact Verification

Verification follows
[android-release-signing.md](android-release-signing.md). Record only artifacts
created in the release owner's protected environment.

```text
APK SHA-256: PENDING RELEASE-OWNER ARTIFACT
AAB SHA-256: PENDING RELEASE-OWNER ARTIFACT
Web archive SHA-256: PENDING RELEASE-OWNER ARTIFACT
```

- [ ] APK signature verification succeeded
- [ ] certificate digest matches the permanent production certificate
- [ ] final artifact hashes were recorded
- [x] no signing credential or private key entered the source package

## Manual Android and Web Validation

- [x] create and edit Animals in each primary category
- [x] verify every category-specific subcategory list in English and German
- [x] change a category and confirm an incompatible subcategory is cleared
- [x] duplicate an Animal and confirm its taxonomy is preserved
- [x] inspect category and optional subcategory on Animal details
- [x] group Animal Overview in both primary directions
- [x] confirm empty categories and unnecessary subcategory headings are omitted
- [x] confirm Other and Not specified remain last within detailed categories
- [x] open and swipe details to confirm they follow the grouped visible order
- [x] restore one legacy backup and one current taxonomy backup
- [x] update a production-signed v1.6.x Android installation without data loss

## Documentation and Publication

- [x] source version is `1.7.0+64`
- [x] `CHANGELOG.md` contains `[1.7.0] - 2026-09-15`
- [x] README, documentation index and roadmap describe Issues #127 and #128
- [x] Schema Version 10 and Backup Format Version 2 behavior are documented
- [x] the complete Issue #127 taxonomy is documented consistently
- [x] annotated `v1.7.0` tag identifies the release source commit
- [x] GitHub release is published with the final release description
- [x] Google Play update is submitted with localized release notes
- [ ] release-owner artifact links and hashes are recorded
