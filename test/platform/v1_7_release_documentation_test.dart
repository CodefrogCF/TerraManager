import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.7.0 source release documentation consistently', () {
    final changelog = read('CHANGELOG.md');
    final readme = read('README.md');
    final roadmap = read('docs/roadmap.md');
    final platformSupport = read('docs/platform-support.md');
    final release = read('docs/release-v1.7.0.md');
    final dataModel = read('docs/data-model.md');
    final backupFormat = read('docs/backup-format.md');
    final taxonomy = read('lib/core/database/enums/animal_category.dart');

    expect(changelog, contains('## [1.7.0] - 2026-09-15'));
    expect(readme, contains('docs/release-v1.7.0.md'));
    expect(roadmap, contains('## v1.7.0 – Animal Taxonomy & Category Views'));
    expect(platformSupport, contains('release-v1.7.0.md'));
    expect(release, contains('Issues #127 and #128'));
    expect(release, contains('Database Schema Version: **10**'));
    expect(release, contains('Portable Backup Format Version: **2**'));
    expect(dataModel, contains('### Schema Version 10'));
    expect(dataModel, contains('Box.temperatureZones'));
    expect(backupFormat, contains('### Animal Taxonomy Fields'));
    expect(
      backupFormat,
      contains(
        'Current input and display belong to `BackupBox.temperatureZones`',
      ),
    );
    expect(
      release,
      contains('transfer a legacy assigned-Animal temperature-zone value'),
    );

    for (final value in const [
      'amphibian',
      'reptile',
      'arachnid',
      'insect',
      'myriapod',
      'crustacean',
      'mollusc',
      'otherInvertebrate',
      'otherSpider',
      'other',
    ]) {
      expect(taxonomy, contains(value), reason: value);
      expect(release, contains(value), reason: value);
    }

    expect(taxonomy, isNot(contains('jumpingSpider')));
    expect(release, isNot(contains('Jumping spider')));
  });
}
