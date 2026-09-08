# v0.12.0 Release Validation

This checklist tracks the final validation and publication of TerraManager
`0.12.0+23`.

Release-candidate preparation started on 2026-09-08. The final release date is
recorded after every required Android and Web check has succeeded.

The release contains:

- free-form cropping for Camera and Gallery pictures in all new and edited Box
  and Animal workflows
- source-orientation normalization before cropping
- WebP encoding at quality 82 with a maximum 1920-pixel longest edge and no
  upscaling
- visible picture-processing progress and duplicate-action protection
- atomic replacement that preserves the previous picture after a failure
- unchanged display support for legacy pictures
- mixed legacy and WebP media in portable Backup Format Version 2 archives

Database Schema Version 4 and Portable Backup Format Version 2 remain
unchanged. Existing pictures are not converted automatically; they enter the
optimized workflow only when the user replaces them.

## Completed Implementation Baseline

The issue-level validation completed before this release candidate includes:

- [x] focused crop-screen and form-integration tests
- [x] focused picture-optimizer tests
- [x] normalized picture integration for new and edited Boxes and Animals
- [x] legacy and WebP display tests
- [x] mixed-media backup export, validation and restore tests
- [x] complete automated suite with 375 passing tests after backup compatibility
- [x] Android builds and manual feature checks for the completed media issues
- [x] real-world backup measurement using 44 Boxes, 45 Animals, 20
  FeedingEvents and 67 pictures

The measured backup decreased from approximately 140 MB to 22.7 MB: about
117.3 MB or 83.8% smaller, reducing it to roughly one sixth of its previous
size.

## Final Automated Validation

Run the final regression from a clean working tree after applying the release
candidate files:

```text
flutter clean
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Focused v0.12.0 coverage can additionally be run with:

```text
flutter test test/features/media/presentation/pages/picture_crop_page_test.dart
flutter test test/features/media/application/picture_optimizer_test.dart
flutter test test/features/media/presentation/widgets/picture_selection_controls_test.dart
flutter test test/features/media/presentation/pages/full_screen_image_page_test.dart
flutter test test/features/animals/presentation/pages/new_animal_page_test.dart
flutter test test/features/animals/presentation/pages/animal_edit_page_test.dart
flutter test test/features/animals/presentation/pages/animals_page_test.dart
flutter test test/features/boxes/presentation/pages/new_box_page_test.dart
flutter test test/features/boxes/presentation/pages/box_edit_page_test.dart
flutter test test/features/boxes/presentation/pages/boxes_page_test.dart
flutter test test/features/backup/domain/backup_media_format_test.dart
flutter test test/features/backup
```

Required results:

- [x] Dart formatting check passes without changes
- [x] Flutter analysis reports no issues
- [x] Complete automated test suite passes
- [x] Focused crop and optimizer tests pass
- [x] All four Box and Animal picture-workflow test files pass
- [x] Complete backup test directory passes

## Release Builds

```text
flutter build apk --debug
flutter build apk --release
flutter build web
```

Required results:

- [x] Android debug APK builds successfully
- [x] Android release APK builds successfully
- [x] Web release build completes successfully
- [x] Application reports Version `0.12.0` and Build `23`

## Android Manual Validation

### Upgrade and General Regression

- [x] Install the release candidate over the previous TerraManager version
- [x] Confirm existing Boxes, Animals, FeedingEvents, settings and pictures
  remain available
- [x] Confirm English and German navigation still work
- [x] Confirm Box, Animal and Feeding workflows still work
- [x] Confirm contextual swipe navigation and normal Back navigation still work
- [x] Restart the application and confirm database, settings and media
  persistence

### Cropping and Normalization

- [x] Add a Box picture from the Camera, crop it and save the Box
- [x] Add a Box picture from the Gallery, crop it and save the Box
- [x] Add an Animal picture from the Camera, crop it and save the Animal
- [x] Add an Animal picture from the Gallery, crop it and save the Animal
- [x] Replace existing Box and Animal pictures from Camera and Gallery
- [x] Move and resize the free-form crop area
- [x] Pan and zoom the source picture in the crop screen
- [x] Confirm portrait and landscape source orientation is displayed correctly
- [x] Cancel cropping and confirm the current form picture remains unchanged
- [x] Confirm processing progress is shown for a sufficiently large picture
- [x] Confirm picture and save actions cannot be submitted repeatedly while
  processing
- [x] Confirm new pictures display in overview, detail and full-screen views
- [x] Confirm new pictures remain after an application restart
- [x] Confirm an existing legacy JPEG or PNG remains readable and unchanged

### Backup Compatibility

- [x] Create a backup containing at least one legacy picture and one new WebP
  picture
- [x] Restore the mixed-format backup and confirm both pictures display
- [x] Confirm restored pictures display in overview, detail and full-screen
  views
- [x] Confirm Boxes, Animals, FeedingEvents and settings survive the restore
- [x] Confirm an invalid backup still fails before local data is replaced
- [x] Confirm the automatic pre-restore safety backup is created

## Web Manual Validation

- [x] Open the release build in a supported Chromium-based browser
- [x] Confirm application startup and existing data after a browser reload
- [x] Select, crop and save Gallery pictures for new and edited Boxes
- [x] Select, crop and save Gallery pictures for new and edited Animals
- [x] Confirm crop movement, resizing, panning, zooming and cancellation
- [x] Confirm portrait and landscape source orientation is displayed correctly
- [x] Confirm processing progress and duplicate-action protection
- [x] Confirm new WebP and existing legacy pictures in overview, detail and
  full-screen views
- [x] Confirm pictures remain available after a browser reload
- [x] Confirm the Camera source is disabled when browser capture is unsupported
- [x] Export and restore a mixed legacy/WebP backup
- [x] Restore an Android-created mixed-media backup on Web
- [x] Restore a Web-created mixed-media backup on Android
- [x] Complete a general Box, Animal, Feeding, Settings and QR regression

## Documentation Review

- [x] Confirm README feature and project-status information
- [x] Confirm Roadmap v0.12.0 scope and validation status
- [x] Confirm architecture, data-model and functional-requirement documentation
- [x] Confirm Android/Web platform notes
- [x] Confirm Backup Format Version 2 mixed-media compatibility documentation
- [x] Confirm Changelog v0.12.0 release date and validation results