import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.6.0 source release documentation consistently', () {
    final readme = read('README.md');
    final changelog = read('CHANGELOG.md');
    final roadmap = read('docs/roadmap.md');
    final architecture = read('docs/architecture-decisions.md');
    final platformSupport = read('docs/platform-support.md');
    final privacy = read('PRIVACY.md');
    final release = read('docs/release-v1.6.0.md');

    expect(readme, contains('docs/release-v1.6.0.md'));
    expect(changelog, contains('## [1.6.0] - 2026-09-15'));
    expect(roadmap, contains('## v1.6.0 – Batch QR Export'));
    expect(architecture, contains('ADR-022'));
    expect(platformSupport, contains('release-v1.6.0.md'));
    expect(privacy, contains('ZIP archives and A4 PDF sheets'));
    expect(privacy, contains('generated entirely'));
    expect(release, contains('Application Version: **1.6.0+62**'));
    expect(release, contains('Database Schema Version: **9**'));
    expect(release, contains('Portable Backup Format Version: **2**'));
    expect(release, contains('Issues #116 and #117'));
    expect(release, contains('reuse one active and archived Box checklist'));
    expect(release, contains('6 mm to 20 mm'));
    expect(release, contains('643 tests'));
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
