# v0.11.0 Release Validation

This checklist records the completed validation for TerraManager `0.11.0+18`.

Validation completed successfully on 2026-09-07.

The release contains:

- configurable Common-name-first or Latin-name-first Animal presentation
- camera-light controls in both Box QR scanners
- Camera and Gallery sources for Box and Animal pictures
- compact Add Picture and Change Picture actions

Database Schema Version 4 and Portable Backup Format Version 2 remain
unchanged.

## Automated Validation

Result: all static-analysis checks and automated tests passed.

Run from a clean working tree:

```text
flutter clean
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Focused v0.11.0 coverage can additionally be run with:

```text
flutter test test/features/animals/presentation/animal_display_names_test.dart
flutter test test/features/settings/app_settings_controller_test.dart
flutter test test/features/settings/presentation/pages/settings_test.dart
flutter test test/features/scanning/presentation/widgets/scanner_torch_button_test.dart
flutter test test/features/boxes/presentation/pages/box_scanner_page_test.dart
flutter test test/features/feedings/presentation/pages/feeding_scanner_page_test.dart
flutter test test/features/media/presentation/widgets/picture_selection_controls_test.dart
flutter test test/features/animals/presentation/pages/new_animal_page_test.dart
flutter test test/features/animals/presentation/pages/animal_edit_page_test.dart
flutter test test/features/boxes/presentation/pages/new_box_page_test.dart
flutter test test/features/boxes/presentation/pages/box_edit_page_test.dart
flutter test test/features/backup
```

## Release Builds

```text
flutter build apk --debug
flutter build apk --release
flutter build web
```

Validated release artifacts:

- [x] Android debug APK
- [x] Android release APK
- [x] Web release build
- [x] Application reports Version `0.11.0` and Build `18`

## Android Manual Validation

### Upgrade and General Regression

- [x] Install the release candidate over the previous TerraManager version
- [x] Confirm that existing Boxes, Animals, FeedingEvents and pictures remain
- [x] Confirm that English and German navigation still work
- [x] Confirm that normal Box and Animal workflows still work
- [x] Confirm that contextual detail navigation and Back navigation still work
- [x] Confirm that portable backup creation and restore still work

### Preferred Animal Name

- [x] Change between Common name first and Latin name first in Settings
- [x] Confirm that the change is immediate without restarting
- [x] Confirm the selected order in overview, history and Animal details
- [x] Confirm the selected order for Animals assigned to a Box
- [x] Confirm the selected order in Quick Feeding Mode
- [x] Restart the application and confirm persistence
- [x] Restore a backup and confirm that the preference is restored

### Scanner Camera Light

- [x] Switch the camera light on and off in the normal Box scanner
- [x] Switch the camera light on and off in the Feeding Mode scanner
- [x] Confirm that scanning still works with the light on and off
- [x] Confirm that returning from a scan leaves the scanner usable

### Picture Sources

- [x] Confirm that an empty picture field shows only Add Picture
- [x] Confirm that an existing picture shows Change Picture and the delete icon
- [x] Confirm that Add Picture and Change Picture open the source menu
- [x] Capture and save a new Box picture with the camera
- [x] Select and save a new Box picture from the Gallery
- [x] Capture and save a new Animal picture with the camera
- [x] Select and save a new Animal picture from the Gallery
- [x] Replace existing Box and Animal pictures from both sources
- [x] Cancel the source menu and camera without changing the current picture
- [x] Deny camera permission and confirm that the form remains usable
- [x] Confirm that pictures survive an application restart
- [x] Confirm that captured pictures are included in backup and restore

## Web Manual Validation

- [x] Run the release candidate in a supported Chromium-based browser
- [x] Confirm preferred Animal-name switching and persistence after reload
- [x] Confirm Animal-name preference backup and restore
- [x] Confirm both QR scanners remain usable
- [x] Confirm the scanner camera-light control is hidden when unsupported
- [x] Confirm Add Picture and Change Picture use the compact layout
- [x] Confirm Gallery picture selection for new and edited Boxes and Animals
- [x] Confirm the Camera source is disabled when the browser reports it as
  unsupported
- [x] Confirm picture persistence after reload and backup/restore
- [x] Complete a general Box, Animal and Feeding workflow regression

## Final Release Actions

Complete only after every required validation succeeds:

- [x] Change the Changelog heading from `Unreleased` to the dated `0.11.0`
  release
- [x] Mark v0.11.0 release and validation tasks complete in the Roadmap
- [x] Update README Project Status to the completed v0.11.0 milestone
- [x] Commit and push the final release documentation
- [x] Create annotated tag `v0.11.0`
- [x] Push tag `v0.11.0`
- [x] Publish the GitHub v0.11.0 release with the release APK
- [x] Close the v0.11.0 milestone
