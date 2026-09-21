# TerraManager

TerraManager is a cross-platform, local-first application for managing terrarium boxes, animals and feeding records.

The application is developed with Flutter and currently supports Android and Web.

iOS support is planned, but has not yet been validated because no macOS build environment or physical iOS test device is currently available.

Public project information:

- [Project homepage](https://codefrogcf.github.io/TerraManager/)
- [Project documentation](docs/project-documentation.md)
- [Installation and updates](docs/installation-and-updates.md)
- [Privacy](PRIVACY.md)
- [Datenschutz (Deutsch)](PRIVACY.de.md)
- [Support](SUPPORT.md)
- [Security](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
- [GPL-3.0-or-later license](LICENSE)

## Project Status

Latest published application version: **v1.10.3+77**.

- Animal category grouping is controlled independently beside the sort menu;
- creation time, displayed name, age and latest feeding work in flat and
  category-grouped views;
- legacy Category sort preferences migrate safely to the grouped view;
- Edit Box places the immutable QR identifier below Notes and above the bottom
  Save and Archive actions;
- Animal shedding documentation now uses timestamped history instead of the
  legacy free-form shedding-note field;
- Database Schema Version 15 and Portable Backup Format Version 2 remain
  current and backward compatible;
- no new device permission is required.

Android and Web are the validated platforms. iOS remains planned and has not
been validated. The complete version history is maintained in
[CHANGELOG.md](CHANGELOG.md), while completed and planned work is maintained in
the [roadmap](docs/roadmap.md).

## Features

TerraManager currently provides:

- local management of Boxes and Animals
- permanent QR identifiers and QR scanning
- Animal taxonomy and husbandry data
- feeding history and configurable feeding reminders
- weight and shedding histories
- ordered Animal and Box picture galleries
- archive and restore workflows
- batch QR export as PNG, ZIP and A4 PDF
- portable local backups and restore
- English and German interfaces
- Android and Web support

For user workflows see the
[visual guide](https://codefrogcf.github.io/TerraManager/guide/).

For technical details see
[Project documentation](docs/project-documentation.md).

For the complete version history see
[CHANGELOG.md](CHANGELOG.md).
