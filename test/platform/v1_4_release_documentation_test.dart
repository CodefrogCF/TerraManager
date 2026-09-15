import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.4.0 source release documentation consistently', () {
    final readme = read('README.md');
    final changelog = read('CHANGELOG.md');
    final roadmap = read('docs/roadmap.md');
    final dataModel = read('docs/data-model.md');
    final backup = read('docs/backup-format.md');
    final architecture = read('docs/architecture-decisions.md');
    final release = read('docs/release-v1.4.0.md');

    expect(readme, contains('docs/release-v1.4.0.md'));
    expect(changelog, contains('## [1.4.0] - 2026-09-14'));
    expect(roadmap, contains('## v1.4.0 – Animal Profiles and Input Quality'));
    expect(dataModel, contains('current Drift database schema version is 9'));
    expect(backup, contains('TerraManager 1.4.0'));
    expect(architecture, contains('ADR-019'));
    expect(architecture, contains('ADR-020'));
    expect(release, contains('Application Version: **1.4.0+59**'));
    expect(release, contains('Database Schema Version: **9**'));
    expect(release, contains('Portable Backup Format Version: **2**'));
    expect(release, contains('Issues #108–#113'));
    expect(release, contains('release-owner workflow'));
    expect(release, contains('PENDING RELEASE-OWNER ARTIFACT'));

    for (final command in [
      'flutter pub get',
      'flutter gen-l10n',
      'dart run build_runner build',
      'dart run drift_dev make-migrations',
      'dart format --output=none --set-exit-if-changed lib test',
      'flutter analyze --no-pub',
      'flutter test --no-pub',
      'apksigner.bat',
    ]) {
      expect(release, contains(command), reason: command);
    }
  });
}
