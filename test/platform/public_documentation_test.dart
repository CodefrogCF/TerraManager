import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('publishes the selected GPL-3.0-or-later licence', () {
    final licence = read('LICENSE');
    final readme = read('README.md');
    final architectureDecisions = read('docs/architecture-decisions.md');

    expect(licence, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(licence, contains('Version 3, 29 June 2007'));
    expect(licence, contains('END OF TERMS AND CONDITIONS'));

    expect(readme, contains('GPL-3.0-or-later'));

    expect(architectureDecisions, contains('ADR-016'));
    expect(architectureDecisions, contains('GPL-3.0-or-later'));
  });

  test('keeps canonical documentation files available', () {
    const requiredFiles = [
      'README.md',
      'CHANGELOG.md',
      'PRIVACY.md',
      'PRIVACY.de.md',
      'SUPPORT.md',
      'SECURITY.md',
      'CONTRIBUTING.md',
      'LICENSE',
      'docs/project-documentation.md',
      'docs/development.md',
      'docs/release-checklist.md',
      'docs/documentation-maintenance.md',
      'docs/toolchain-baseline.md',
      'docs/installation-and-updates.md',
      'docs/platform-support.md',
      'docs/data-model.md',
      'docs/backup-format.md',
      'docs/architecture-decisions.md',
      'docs/android-release-signing.md',
      'docs/roadmap.md',
      'docs/functional-requirements-MVP.md',
      'docs/functional-requirements-non-MVP.md',
    ];

    for (final path in requiredFiles) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'Missing canonical documentation file: $path',
      );
    }
  });

  test('README links to the primary documentation entry points', () {
    final readme = read('README.md');

    const requiredLinks = [
      'docs/project-documentation.md',
      'docs/installation-and-updates.md',
      'PRIVACY.md',
      'PRIVACY.de.md',
      'SUPPORT.md',
      'SECURITY.md',
      'CONTRIBUTING.md',
      'LICENSE',
    ];

    for (final path in requiredLinks) {
      expect(
        readme,
        contains(']($path)'),
        reason: 'README should link to $path',
      );
    }
  });

  test('project documentation routes authoritative technical topics', () {
    final projectDocumentation = read('docs/project-documentation.md');

    const canonicalReferences = [
      'development.md',
      'release-checklist.md',
      'documentation-maintenance.md',
      'toolchain-baseline.md',
      'installation-and-updates.md',
      'platform-support.md',
      'data-model.md',
      'backup-format.md',
      'architecture-decisions.md',
      'android-release-signing.md',
      'roadmap.md',
    ];

    for (final path in canonicalReferences) {
      expect(
        projectDocumentation,
        contains(']($path)'),
        reason: 'project-documentation.md should reference $path',
      );
    }
  });

  test('release checks have one canonical documentation source', () {
    final releaseChecklist = read('docs/release-checklist.md');
    final development = read('docs/development.md');
    final projectDocumentation = read('docs/project-documentation.md');

    expect(
      releaseChecklist,
      contains('canonical release-validation checklist'),
    );

    expect(
      development,
      contains('[release-checklist.md](release-checklist.md)'),
    );

    expect(
      projectDocumentation,
      contains('[Release checklist](release-checklist.md)'),
    );

    expect(
      development,
      isNot(contains('## Recommended Release Validation')),
      reason: 'The complete release checklist should not be duplicated in development.md.',
    );
  });

  test(
    'documentation maintenance owns guides screenshots and localization',
    () {
      final maintenance = read('docs/documentation-maintenance.md');

      expect(maintenance, contains('Screenshot'));
      expect(maintenance, contains('English and German'));
      expect(maintenance, contains('visual user guides'));
      expect(maintenance, contains('downloadable manual'));
      expect(maintenance, contains('release-checklist.md'));
    },
  );

  test('installation and update information has one canonical source', () {
    final installation = read('docs/installation-and-updates.md');
    final projectDocumentation = read('docs/project-documentation.md');
    final platformSupport = read('docs/platform-support.md');

    expect(installation, contains('# Installation and Updates'));
    expect(installation, contains('com.codefrog.terramanager'));
    expect(installation, contains('production signing certificate'));
    expect(installation, contains('.tmbackup'));

    expect(
      projectDocumentation,
      contains('[Installation and updates](installation-and-updates.md)'),
    );

    expect(
      platformSupport,
      contains('[Installation and updates](installation-and-updates.md)'),
    );
  });

  test(
    'data model and backup format remain authoritative technical sources',
    () {
      final dataModel = read('docs/data-model.md');
      final backupFormat = read('docs/backup-format.md');

      expect(
        dataModel,
        contains('current Drift database schema version is **15**'),
      );
      expect(dataModel, contains('### Schema Version 15'));
      expect(dataModel, contains('SheddingEvents'));
      expect(dataModel, contains('Animal'));
      expect(dataModel, contains('Box'));
      expect(dataModel, contains('FeedingEvent'));

      expect(backupFormat, contains('Backup Format Version 2'));
      expect(backupFormat, contains('portable backup'));
      expect(backupFormat, contains('settings.json'));
      expect(backupFormat, contains('manifest.json'));
    },
  );

  test('documents local data permissions and unencrypted backups', () {
    final privacy = read('PRIVACY.md');
    final productionManifest = read('android/app/src/main/AndroidManifest.xml');

    expect(privacy, contains('local-first'));
    expect(privacy, contains('Camera'));
    expect(privacy, contains('photo picker'));
    expect(privacy, contains('file picker'));
    expect(privacy, contains('saving a QR-code image'));
    expect(privacy, isNot(contains('print service')));
    expect(privacy, contains('ZIP archives and A4 PDF sheets'));
    expect(privacy, contains('generated entirely'));
    expect(privacy, contains('operating-system save dialog'));
    expect(privacy, contains('additional broad storage, media or network'));
    expect(privacy, contains('not encrypted'));
    expect(privacy, contains('analytics'));
    expect(
      privacy,
      contains(
        RegExp(r'system[-\s]+notification\s+permission', caseSensitive: false),
      ),
    );

    bool removesPermission(String permission) {
      return RegExp(
        '<uses-permission\\s+'
        '[^>]*android:name="$permission"'
        '[^>]*tools:node="remove"'
        '[^>]*/>',
        multiLine: true,
      ).hasMatch(productionManifest);
    }

    expect(
      removesPermission('android.permission.INTERNET'),
      isTrue,
      reason: 'The production manifest must remove INTERNET from dependencies.',
    );

    expect(
      removesPermission('android.permission.ACCESS_NETWORK_STATE'),
      isTrue,
      reason: 'The production manifest must remove ACCESS_NETWORK_STATE from dependencies.',
    );

    expect(
      removesPermission('android.permission.READ_EXTERNAL_STORAGE'),
      isTrue,
      reason: 'The production manifest must remove unrestricted external-storage read access.',
    );
  });

  test('documents trusted installation and safe support reports', () {
    final installation = read('docs/installation-and-updates.md');
    final support = read('SUPPORT.md');
    final security = read('SECURITY.md');

    expect(installation, contains('com.codefrog.terramanager'));
    expect(installation, contains('production signing certificate'));
    expect(installation, contains('f9bcd66cf622597f'));
    expect(installation, contains('not encrypted'));

    expect(support, contains('GitHub Issues'));
    expect(support, contains('Never publish real'));

    expect(security, contains('private vulnerability reporting'));
    expect(security, contains('Never attach a real'));

    expect(
      security,
      isNot(contains('Before v1.0')),
      reason: 'The security policy must not retain the obsolete pre-v1.0 support wording.',
    );
  });

  test(
    'canonical Markdown documentation has no broken relative Markdown links',
    () {
      const documents = [
        'README.md',
        'docs/project-documentation.md',
        'docs/development.md',
        'docs/release-checklist.md',
        'docs/documentation-maintenance.md',
        'docs/toolchain-baseline.md',
        'docs/installation-and-updates.md',
        'docs/platform-support.md',
        'docs/data-model.md',
        'docs/backup-format.md',
        'docs/architecture-decisions.md',
        'docs/android-release-signing.md',
        'docs/roadmap.md',
      ];

      final markdownLinkPattern = RegExp(r'\[[^\]]+\]\(([^)]+)\)');

      for (final documentPath in documents) {
        final document = File(documentPath);
        final contents = document.readAsStringSync();

        for (final match in markdownLinkPattern.allMatches(contents)) {
          var target = match.group(1)!;

          if (target.startsWith('http://') ||
              target.startsWith('https://') ||
              target.startsWith('mailto:') ||
              target.startsWith('#') ||
              target.startsWith('/') ||
              target.endsWith('/')) {
            continue;
          }

          target = target.split('#').first;

          if (target.isEmpty) {
            continue;
          }

          final baseDirectory = document.parent.path;

          final resolvedPath = documentPath == 'README.md'
              ? target
              : '$baseDirectory/$target';

          final fileExists = File(resolvedPath).existsSync();
          final directoryExists = Directory(resolvedPath).existsSync();

          expect(
            fileExists || directoryExists,
            isTrue,
            reason:
                '$documentPath contains a broken relative link to $target '
                '(resolved as $resolvedPath)',
          );
        }
      }
    },
  );

  test('retired release-specific documentation is not reintroduced', () {
    final docsDirectory = Directory('docs');

    final obsoletePatterns = [
      RegExp(r'release[-_]?validation', caseSensitive: false),
      RegExp(r'v1[_\.-]?0[_\.-]?0.*checklist', caseSensitive: false),
      RegExp(r'issue[-_]?\d+.*\.md$', caseSensitive: false),
    ];

    for (final entity in docsDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.md')) {
        continue;
      }

      final normalizedPath = entity.path.replaceAll('\\', '/');

      for (final pattern in obsoletePatterns) {
        expect(
          pattern.hasMatch(normalizedPath),
          isFalse,
          reason:
              'Retired release- or issue-specific documentation found: '
              '$normalizedPath',
        );
      }
    }
  });
}
