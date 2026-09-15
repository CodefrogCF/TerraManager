import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.6.1 source release documentation consistently', () {
    final pubspec = read('pubspec.yaml');
    final readme = read('README.md');
    final changelog = read('CHANGELOG.md');
    final roadmap = read('docs/roadmap.md');
    final platformSupport = read('docs/platform-support.md');
    final release = read('docs/release-v1.6.1.md');

    expect(pubspec, contains('version: 1.6.1+63'));
    expect(readme, contains('docs/release-v1.6.1.md'));
    expect(changelog, contains('## [1.6.1] - 2026-09-15'));
    expect(roadmap, contains('## v1.6.1 – UX Consistency & Localization'));
    expect(platformSupport, contains('release-v1.6.1.md'));
    expect(release, contains('Application Version: **1.6.1+63**'));
    expect(release, contains('Database Schema Version: **9**'));
    expect(release, contains('Portable Backup Format Version: **2**'));
    expect(release, contains('Issues #122–#126'));
    expect(release, contains('one directional toggle per'));
    expect(release, contains('complete automated test suite passed with 653'));
    expect(release, contains('release-owner workflow'));
    expect(release, contains('PENDING RELEASE-OWNER ARTIFACT'));

    for (final command in [
      'flutter pub get',
      'flutter gen-l10n',
      'dart format --output=none --set-exit-if-changed lib test',
      'flutter analyze --no-pub',
      'flutter test --no-pub',
      'flutter build appbundle --release --no-pub',
    ]) {
      expect(release, contains(command), reason: command);
    }
  });
}
