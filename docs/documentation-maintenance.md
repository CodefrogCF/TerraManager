# Documentation Maintenance

This document defines the responsibilities of TerraManager documentation.

## Documentation map

### End-user documentation

The end-user documentation consists of:

- `/` and `/en/` — public homepage
- `/guide/` and `/guide/en/` — visual user guides
- `guide/TerraManager-Handbuch.pdf` — German downloadable manual
- `guide/TerraManager-User-Manual.pdf` — English downloadable manual

The visual guides and manuals must describe the same current workflows but do
not need to duplicate each other word for word.
The localized guide entry pages are `guide/index.md` and `guide/en/index.md`;
both use `_layouts/guide.html` and `_data/guide.yml`. Do not add a second
`guide/index.html` with the same output path.

### Installation and updates

`installation-and-updates.md` is the canonical source for:

- Android installation
- Android updates
- Web deployment and updates
- application-ID transition guidance
- update backup recommendations

Other documents should link to it instead of repeating these procedures.

### Release validation

`release-checklist.md` is the canonical release checklist.

Release-specific validation steps should not be duplicated in development,
project or platform documentation.

### Development documentation

`development.md` covers:

- local development setup
- generated code
- issue-level validation
- development workflow

Toolchain-specific requirements are maintained in `toolchain-baseline.md`.

### Architecture and technical model

The authoritative technical documents are:

- `architecture-decisions.md` — architectural decisions and their rationale
- `data-model.md` — current database model and schema history
- `backup-format.md` — portable backup format and restore rules
- `platform-support.md` — platform validation status and platform limitations
- `android-release-signing.md` — Android production signing procedure

### Project overview

`project-documentation.md` provides a technical project overview and links to
the authoritative documents above.

It should not duplicate complete specifications maintained elsewhere.

### Project policy documents

Repository-root documents remain authoritative for:

- `PRIVACY.md`
- `PRIVACY.de.md`
- `SUPPORT.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `LICENSE`

### Release history and planning

`CHANGELOG.md` records published changes.

`roadmap.md` records milestone and future-work planning.

Neither should be treated as the authoritative current technical specification.

## Screenshot and guide maintenance

Review screenshots and guides whenever a release changes:

- visible navigation
- labels
- dialogs
- forms
- list layouts
- user workflows
- settings
- archive or restore behaviour

Replace screenshots when the current image could mislead users.

Minor cosmetic changes do not automatically require replacement.

Screenshots must not contain private user data.

Keep filenames stable where practical to avoid broken references.

## English and German alignment

When a documented workflow changes:

1. update the English and German guide text
2. update both manuals where the workflow is covered
3. verify screenshots still match both versions
4. verify internal links and downloads
5. confirm the public homepage still describes the current feature correctly

## Link maintenance

Use relative repository links for repository documentation.

Use Jekyll `relative_url` or `absolute_url` filters for GitHub Pages content.

Remove links to retired release-specific documents instead of leaving redirect
chains inside the repository.

## Release responsibility

Documentation review is part of the release process.

The authoritative release checklist is:

[Release checklist](release-checklist.md)
