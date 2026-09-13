import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the current v1.1 development build consistently', () {
    final pubspec = read('pubspec.yaml');
    final readme = read('README.md');
    final changelog = read('CHANGELOG.md');

    expect(pubspec, contains('version: 1.1.1+51'));
    expect(readme, contains('docs/release-v1.1.0.md'));
    expect(readme, contains('Database Schema Version 7'));
    expect(readme, contains(RegExp(r'Portable\s+Backup Format Version 2')));
    expect(changelog, contains('## [1.1.1] - 2026-09-13'));
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
    expect(
      release,
      contains(
        'E523032E398CBBCA832464E6A06474D23ED8345D20926D2BE217F52299FF65B1',
      ),
    );
    expect(
      release,
      contains(
        'E42BA3C7149CDC32CB805A9E33A6EEC95486DD93038AC438A6DFDCA090EFD828',
      ),
    );
  });
}
