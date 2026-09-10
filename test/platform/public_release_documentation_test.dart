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
      'docs/toolchain-baseline.md',
      'docs/release-v1.0.0.md',
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
    expect(privacy, contains('photo picker'));
    expect(privacy, contains('file picker'));
    expect(privacy, contains('print service'));
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
    expect(installation, contains('same production signing certificate'));
    expect(installation, contains('f9bcd66cf622597f'));
    expect(installation, contains('not encrypted'));
    expect(support, contains('GitHub Issues'));
    expect(support, contains('Never publish real'));
    expect(security, contains('private vulnerability reporting'));
    expect(security, contains('Never attach a real'));
  });
}
