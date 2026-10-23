# Development Guide

Use the pinned [toolchain baseline](toolchain-baseline.md). On Windows, enable
Developer Mode before dependency resolution so Flutter can create plugin symlinks.
Read [CONTRIBUTING.md](../CONTRIBUTING.md) before substantial contributions.

## Setup and run

```sh
flutter pub get
flutter gen-l10n
flutter run
```

`lib/main.dart` starts standalone; `lib/main_shared.dart` starts Shared Care Web.
Use `flutter run -d chrome --target lib/main_shared.dart` for the shared client
against a correctly configured same-origin API. Server startup and environment
variables are documented in the [API reference](shared-care-api.md).

## Structure

| Path | Purpose |
| --- | --- |
| `lib/features/` | Standalone features and reusable presentation/application code |
| `lib/core/database/` | Drift tables, migrations and repositories |
| `lib/shared_client/` | Shared Care browser features and synchronization |
| `lib/shared_server/` | Server routing, operations and infrastructure |
| `lib/l10n/` | English/German ARB catalogs |
| `test/` | Unit, widget, architecture and platform checks |
| `deploy/` | Shared Care containers and gateway |
| `tool/` | Build, validation and evaluation tools |

Keep database access behind repositories and HTTP handling outside server
application operations. Follow the [Shared Care boundaries](shared-care-architecture.md).

## Generated code

After editing ARB catalogs, run `flutter gen-l10n`. For Drift changes:

```sh
dart run build_runner build
dart run drift_dev make-migrations
```

Review generated migrations and test upgrades from supported schemas. Do not edit
generated localization, `.g.dart` or migration-step files by hand.

Standalone Web needs `web/sqlite3.wasm` matching the resolved `sqlite3` package
and a compiled worker:

```sh
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
flutter build web --release --no-web-resources-cdn
flutter build web --release --target lib/main_shared.dart --output build/web-shared --no-web-resources-cdn
```

The shared build needs locally bundled rendering/fonts; it does not open a browser
collection database. Generated workers and build output stay out of Git.

## Verify a change

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Run focused tests while developing and the quality gates before merging.
For documentation, run `flutter test test/platform`; check local links and both
guide languages. For platform changes, test the affected camera, file, media or
storage workflow on its target. Record the issue requirement, result and any
unverified boundary in the corresponding GitHub issue.

## Documentation maintenance

Each technical topic has one reference linked from the
[documentation index](project-documentation.md). Use the changelog for release
history and GitHub Issues for work tracking.

The public site uses Jekyll: `docs/index.md` and `docs/en/index.md` select localized
homepage data in `_data/home.yml`; both visual user guides use `_data/guide.yml`
and `_layouts/guide.html`. Keep English and German aligned. Screenshot changes
are needed when an image would misrepresent a workflow. Update the downloadable
manuals with the guide and inspect their rendered pages. Use demonstration data.

Regenerate both manuals from the same guide source:

```sh
python -m pip install reportlab PyYAML Pillow
python tool/docs/build_user_manuals.py
```

These are documentation tooling dependencies, separate from the app.

GitHub Pages publishes `main:/docs` below `/TerraManager/`. Use `relative_url` /
`absolute_url` for site links and local assets. Keep the site free of trackers,
remote scripts and remote fonts. Root privacy policies are also bundled in the
app; preserve identical bodies in `docs/privacy/index.md` and
`docs/privacy/de/index.md`. The local license page mirrors `LICENSE`.
