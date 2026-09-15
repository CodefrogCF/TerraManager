import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.5.0 source release documentation consistently', () {
    final readme = read('README.md');
    final changelog = read('CHANGELOG.md');
    final roadmap = read('docs/roadmap.md');
    final dataModel = read('docs/data-model.md');
    final architecture = read('docs/architecture-decisions.md');
    final platformSupport = read('docs/platform-support.md');
    final release = read('docs/release-v1.5.0.md');

    expect(readme, contains('docs/release-v1.5.0.md'));
    expect(changelog, contains('## [1.5.0] - 2026-09-15'));
    expect(roadmap, contains('## v1.5.0 – Overview Quick Actions'));
    expect(dataModel, contains('## Record Duplication (Issues #114 and #115)'));
    expect(architecture, contains('ADR-021'));
    expect(platformSupport, contains('release-v1.5.0.md'));
    expect(release, contains('Application Version: **1.5.0+60**'));
    expect(release, contains('Database Schema Version: **9**'));
    expect(release, contains('Portable Backup Format Version: **2**'));
    expect(release, contains('Issues #114 and #115'));
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
