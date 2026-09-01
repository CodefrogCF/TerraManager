# TerraManager Roadmap

## Current Status

Current completed release milestone:

**v0.4.0 – Platform Support**

Completed development areas:

- database foundation
- repository layer
- application navigation
- box and animal workflows
- feeding history
- notes and animal pictures
- QR generation, export, storage, printing and scanning
- Android validation
- Web validation

The next development milestone is:

**v0.5.0 – Usability & Settings**

---

## v0.1.0 – Foundation

### Database

- [x] Define box data model
- [x] Define animal data model
- [x] Define Box → Animal relationship
- [x] Add Sex enum
- [x] Add Sex converter
- [x] Add birth date
- [x] Add birth date accuracy
- [x] Add BirthDateAccuracy converter
- [x] Define feeding events
- [x] Implement latest feeding lookup
- [x] Add database tests
- [x] Add repository tests
- [x] Complete initial repository layer

---

## v0.2.0 – User Interface

- [x] Basic application navigation
- [x] Box overview
- [x] Box detail screen
- [x] Animal overview
- [x] Animal detail screen
- [x] Animal editing
- [x] New box workflow
- [x] New animal workflow
- [x] Feeding history
- [x] Notes
- [x] Animal picture support

---

## v0.3.0 – QR Code

- [x] Generate unique QR IDs
- [x] Generate QR codes
- [x] Export QR codes as PNG
- [x] Save QR code locally
- [x] Print QR codes
- [x] Implement QR scanner
- [x] Validate TerraManager QR IDs
- [x] Handle invalid QR codes
- [x] Handle unknown box QR codes

---

## v0.4.0 – Platform Support

### Android

- [x] Android debug build
- [x] Android release build
- [x] Application startup
- [x] Core navigation
- [x] Database persistence
- [x] Animal picture support
- [x] Local QR image storage
- [x] Camera permissions
- [x] QR scanning
- [x] QR printing
- [x] Relevant tests

### Web

- [x] Web build
- [x] Application startup
- [x] Core navigation
- [x] Drift Web database
- [x] Persistent data after browser reload
- [x] Animal picture support
- [x] QR image download
- [x] Camera permissions
- [x] QR scanning
- [x] QR printing
- [x] Known Web limitations documented
- [x] Relevant tests

### iOS

- [ ] Validate iOS build
- [ ] Validate application startup
- [ ] Validate database persistence
- [ ] Validate animal pictures
- [ ] Validate QR storage
- [ ] Validate camera permissions
- [ ] Validate QR scanning
- [ ] Validate printing

iOS validation is currently deferred because no macOS development environment or physical iOS test device is available.

---

## v0.5.0 – Usability & Settings

### Box Detail Improvements

- [ ] Show animals assigned to the box
- [ ] Show empty state when no animals are assigned
- [ ] Open animal detail from assigned animal list
- [ ] Add box deletion action
- [ ] Require confirmation before deletion
- [ ] Prevent accidental deletion of boxes containing animals
- [ ] Refresh box overview after deletion

### Animal Detail Improvements

- [ ] Show latest feeding below Notes
- [ ] Show date and time of latest feeding
- [ ] Show suitable empty state when no feeding exists
- [ ] Refresh latest feeding after feeding history changes

### Settings

- [ ] Implement appearance settings
- [ ] System theme mode
- [ ] Light theme mode
- [ ] Dark theme mode
- [ ] Selectable accent colors
- [ ] Apply theme changes immediately
- [ ] Persist settings
- [ ] Validate settings on Android
- [ ] Validate settings on Web

### Release

- [ ] Regression test Android
- [ ] Regression test Web
- [ ] Update documentation
- [ ] Update changelog
- [ ] Release v0.5.0

---

## Future Development

Planned future features include:

- iOS validation
- sensors
- automatic temperature and humidity tracking
- smart-home integration
- backup and restore
- data import/export
- user accounts
- cloud synchronization
- multi-device synchronization

The exact order of future milestones will be decided after v0.5.0.