import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.2.0 release documentation consistently', () {
    final readme = read('README.md');
    final changelog = read('CHANGELOG.md');
    final roadmap = read('docs/roadmap.md');
    final release = read('docs/release-v1.2.0.md');

    expect(readme, contains('docs/release-v1.2.0.md'));
    expect(changelog, contains('## [1.2.0] - 2026-09-13'));
    expect(roadmap, contains('## v1.2.0 – Box Lifecycle & History'));
    expect(release, contains('Application Version: **1.2.0+54**'));
    expect(release, contains('Database Schema Version: **8**'));
    expect(release, contains('Portable Backup Format Version: **2**'));
    expect(release, contains('com.codefrog.terramanager'));
    expect(release, contains('f9bcd66cf622597f'));

    const requiredCommands = [
      'flutter pub get',
      'flutter gen-l10n',
      'dart format --output=none --set-exit-if-changed lib test',
      'flutter analyze --no-pub',
      'flutter test --no-pub',
      'flutter build apk --debug --no-pub',
      'flutter build apk --release --no-pub',
      'flutter build appbundle --release --no-pub',
      'flutter build web --release --no-pub',
      'apksigner.bat',
      'jarsigner -verify',
    ];

    for (final command in requiredCommands) {
      expect(release, contains(command), reason: command);
    }

    final recordedHashes = RegExp(
      r'^(?:APK|AAB|Web ZIP) SHA-256: [A-F0-9]{64}$',
      multiLine: true,
    ).allMatches(release);
    expect(recordedHashes.length, 3);
    expect(release, isNot(contains('TO_BE_RECORDED')));
  });
}
