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

- [ ] Dart formatting check passes without changes
- [ ] Flutter analysis reports no issues
- [ ] Complete automated test suite passes
- [ ] Focused crop and optimizer tests pass
- [ ] All four Box and Animal picture-workflow test files pass
- [ ] Complete backup test directory passes

## Release Builds

```text
flutter build apk --debug
flutter build apk --release
flutter build web
```

Required results:

- [ ] Android debug APK builds successfully
- [ ] Android release APK builds successfully
- [ ] Web release build completes successfully
- [ ] Application reports Version `0.12.0` and Build `23`

## Android Manual Validation

### Upgrade and General Regression

- [ ] Install the release candidate over the previous TerraManager version
- [ ] Confirm existing Boxes, Animals, FeedingEvents, settings and pictures
  remain available
- [ ] Confirm English and German navigation still work
- [ ] Confirm Box, Animal and Feeding workflows still work
- [ ] Confirm contextual swipe navigation and normal Back navigation still work
- [ ] Restart the application and confirm database, settings and media
  persistence

### Cropping and Normalization

- [ ] Add a Box picture from the Camera, crop it and save the Box
- [ ] Add a Box picture from the Gallery, crop it and save the Box
- [ ] Add an Animal picture from the Camera, crop it and save the Animal
- [ ] Add an Animal picture from the Gallery, crop it and save the Animal
- [ ] Replace existing Box and Animal pictures from Camera and Gallery
- [ ] Move and resize the free-form crop area
- [ ] Pan and zoom the source picture in the crop screen
- [ ] Confirm portrait and landscape source orientation is displayed correctly
- [ ] Cancel cropping and confirm the current form picture remains unchanged
- [ ] Confirm processing progress is shown for a sufficiently large picture
- [ ] Confirm picture and save actions cannot be submitted repeatedly while
  processing
- [ ] Confirm new pictures display in overview, detail and full-screen views
- [ ] Confirm new pictures remain after an application restart
- [ ] Confirm an existing legacy JPEG or PNG remains readable and unchanged

### Backup Compatibility

- [ ] Create a backup containing at least one legacy picture and one new WebP
  picture
- [ ] Restore the mixed-format backup and confirm both pictures display
- [ ] Confirm restored pictures display in overview, detail and full-screen
  views
- [ ] Confirm Boxes, Animals, FeedingEvents and settings survive the restore
- [ ] Confirm an invalid backup still fails before local data is replaced
- [ ] Confirm the automatic pre-restore safety backup is created

## Web Manual Validation

- [ ] Open the release build in a supported Chromium-based browser
- [ ] Confirm application startup and existing data after a browser reload
- [ ] Select, crop and save Gallery pictures for new and edited Boxes
- [ ] Select, crop and save Gallery pictures for new and edited Animals
- [ ] Confirm crop movement, resizing, panning, zooming and cancellation
- [ ] Confirm portrait and landscape source orientation is displayed correctly
- [ ] Confirm processing progress and duplicate-action protection
- [ ] Confirm new WebP and existing legacy pictures in overview, detail and
  full-screen views
- [ ] Confirm pictures remain available after a browser reload
- [ ] Confirm the Camera source is disabled when browser capture is unsupported
- [ ] Export and restore a mixed legacy/WebP backup
- [ ] Restore an Android-created mixed-media backup on Web
- [ ] Restore a Web-created mixed-media backup on Android
- [ ] Complete a general Box, Animal, Feeding, Settings and QR regression

## Documentation Review

- [ ] Confirm README feature and project-status information
- [ ] Confirm Roadmap v0.12.0 scope and validation status
- [ ] Confirm architecture, data-model and functional-requirement documentation
- [ ] Confirm Android/Web platform notes
- [ ] Confirm Backup Format Version 2 mixed-media compatibility documentation
- [ ] Confirm Changelog v0.12.0 release date and validation results

## GitHub Release Description

Use the following text for the GitHub release after final validation:

```markdown
## TerraManager v0.12.0 – Media Optimization

TerraManager v0.12.0 adds a complete picture-processing workflow for Box and
Animal media.

### Highlights

- Crop Camera and Gallery pictures before saving them.
- Normalize source orientation and limit the longest edge to 1920 pixels.
- Store new and replaced pictures as WebP at quality 82.
- Show processing progress and prevent duplicate picture or save actions.
- Replace pictures atomically so a failed update keeps the previous picture.
- Continue displaying and restoring existing legacy picture formats.
- Export and restore mixed legacy/WebP media with Backup Format Version 2.

In a real TerraManager data set with 67 pictures, the portable backup decreased
from approximately 140 MB to 22.7 MB after replacing the pictures through the
optimized workflow—about 83.8% smaller.

### Compatibility

- Database Schema Version: 4 (unchanged)
- Portable Backup Format Version: 2 (unchanged)
- Existing pictures are not converted automatically.
- Android and Web are supported and regression-tested.
- iOS validation remains a stretch goal.
```

## Final Release Actions

Complete only after every required validation succeeds:

- [ ] Replace the Changelog `Unreleased` heading with
  `[0.12.0] - 2026-09-08`
- [ ] Record the successful results in this checklist
- [ ] Mark v0.12.0 validation and release tasks complete in the Roadmap
- [ ] Update README Project Status to the completed v0.12.0 milestone
- [ ] Update platform validation notes with the v0.12.0 regression
- [ ] Commit and push the final release documentation
- [ ] Create annotated tag `v0.12.0`
- [ ] Push tag `v0.12.0`
- [ ] Publish the GitHub v0.12.0 release with the release APK
- [ ] Close Issue #73
- [ ] Close the v0.12.0 milestone

Recommended Git commands after the documentation commit:

```text
git tag -a v0.12.0 -m "TerraManager v0.12.0"
git push origin v0.12.0
```
