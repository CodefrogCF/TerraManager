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

Latest published application version: **v1.10.4+78**.

- Box and Animal overviews provide an optional persistent Big Picture Mode;
- Animal and Box archives provide matching history views, thumbnails,
  persistent sorting and direct Restore and Duplicate actions;
- Animal care records include timestamped weight, feeding and shedding
  histories;
- Animal details can optionally hide Weight and Shedding sections for each
  Animal;
- the Animal Overview can optionally show the next upcoming feeding in addition
  to existing due reminders;
- Edit Animal supports local QR-based reassignment to an active Box;
- Animal details omit unset or Unknown sex information;
- Database Schema Version 16 and Portable Backup Format Version 2 are current
  and backward compatible;
- the current workflows remain local-first and require no new device
  permission.

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
- optional self-hosted Shared Care Web mode with one server-owned collection

The standalone Android and Web applications keep their own local collections.
For multiple caregivers on one LAN, the separately built
[Shared Care Web mode](docs/shared-care-deployment.md) uses the Pi server
instead. The Android Settings link opens that mode in the external browser
without giving the Android app network access.

For user workflows see the
[visual guide](https://codefrogcf.github.io/TerraManager/guide/).

For technical details see
[Project documentation](docs/project-documentation.md).

For the complete version history see
[CHANGELOG.md](CHANGELOG.md).
