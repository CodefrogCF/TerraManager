import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.1.0 release candidate consistently', () {
    final pubspec = read('pubspec.yaml');
    final readme = read('README.md');
    final changelog = read('CHANGELOG.md');

    expect(pubspec, contains('version: 1.1.0+50'));
    expect(readme, contains('docs/release-v1.1.0.md'));
    expect(changelog, contains('## [1.1.0] - 2026-09-12'));
  });

  test('documents final validation and compatibility checks', () {
    final release = read('docs/release-v1.1.0.md');

    const requiredCommands = [
      'flutter clean',
      'flutter pub get',
      'flutter gen-l10n',
      'dart format --output=none --set-exit-if-changed lib test',
      'flutter analyze',
      'flutter test',
      'flutter build apk --debug',
      'flutter build apk --release',
      'flutter build appbundle --release',
      'flutter build web --release',
    ];

    for (final command in requiredCommands) {
      expect(release, contains(command), reason: command);
    }

    expect(release, contains('Database Schema Version: **6**'));
    expect(release, contains('Portable Backup Format Version: **2**'));
    expect(release, contains('com.codefrog.terramanager'));
    expect(release, contains('f9bcd66cf622597f'));
    expect(release, contains('Version 5 to Version 6'));
    expect(release, contains('APK SHA-256:'));
    expect(release, contains('AAB SHA-256:'));
  });
}
