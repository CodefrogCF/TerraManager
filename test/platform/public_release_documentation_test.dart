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
    expect(readme, contains('Copyright (C) 2026 CodefrogCF'));
    expect(architectureDecisions, contains('ADR-016'));
    expect(architectureDecisions, contains('GPL-3.0-or-later'));
  });

  test('links the public release documents from the project overview', () {
    final readme = read('README.md');

    const requiredFiles = [
      'PRIVACY.md',
      'SUPPORT.md',
      'SECURITY.md',
      'CONTRIBUTING.md',
      'docs/installation-and-updates.md',
    ];

    for (final path in requiredFiles) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(readme, contains(']($path)'), reason: path);
    }
  });

  test('documents local data, permissions and unencrypted backups', () {
    final privacy = read('PRIVACY.md');
    final productionManifest = read('android/app/src/main/AndroidManifest.xml');

    expect(privacy, contains('local-first'));
    expect(privacy, contains('Camera'));
    expect(privacy, contains('Photos or gallery'));
    expect(privacy, contains('Files or documents'));
    expect(privacy, contains('Printing'));
    expect(privacy, contains('not encrypted'));
    expect(privacy, contains('analytics'));
    expect(privacy, contains(RegExp(r'system\s+notification\s+access')));
    expect(productionManifest, isNot(contains('android.permission.INTERNET')));
  });

  test('documents trusted installation and safe support reports', () {
    final installation = read('docs/installation-and-updates.md');
    final support = read('SUPPORT.md');
    final security = read('SECURITY.md');

    expect(installation, contains('com.codefrog.terramanager'));
    expect(installation, contains('same production signing certificate'));
    expect(installation, contains('f9bcd66cf622597f'));
    expect(installation, contains('not encrypted'));
    expect(support, contains('GitHub Issues'));
    expect(support, contains('Never publish real'));
    expect(security, contains('private vulnerability reporting'));
    expect(security, contains('Never attach a real'));
  });

  test('records the current development build and completed releases', () {
    final pubspec = read('pubspec.yaml');
    final roadmap = read('docs/roadmap.md');
    final releaseV011 = read('docs/release-v0.11.0.md');
    final releaseV012 = read('docs/release-v0.12.0.md');

    expect(pubspec, contains('version: 0.14.5+37'));
    expect(roadmap, contains('**v0.14.5+37**'));
    expect(releaseV011, contains('- [x] Publish the GitHub v0.11.0 release'));
    expect(releaseV012, contains('- [x] Close Issue #73'));
    expect(releaseV012, contains('- [x] Close the v0.12.0 milestone'));
  });
}
