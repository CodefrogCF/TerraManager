import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('records the v1.7 release documentation consistently', () {
    final changelog = read('CHANGELOG.md');
    final readme = read('README.md');
    final roadmap = read('docs/roadmap.md');
    final platformSupport = read('docs/platform-support.md');
    final release = read('docs/release-v1.7.0.md');
    final patchRelease = read('docs/release-v1.7.1.md');
    final dataModel = read('docs/data-model.md');
    final backupFormat = read('docs/backup-format.md');
    final taxonomy = read('lib/core/database/enums/animal_category.dart');

    expect(changelog, contains('required Animal categories'));
    expect(changelog, contains('released Schema Version 10 snapshot'));
    expect(readme, contains('docs/release-v1.7.0.md'));
    expect(readme, contains('docs/release-v1.7.1.md'));
    expect(roadmap, contains('Animal Taxonomy & Category Views'));
    expect(roadmap, contains('Enclosure Notes & Migration'));
    expect(platformSupport, contains('release-v1.7.0.md'));
    expect(platformSupport, contains('release-v1.7.1.md'));
    expect(release, contains('Issues #127 and #128'));
    expect(release, isNot(contains('transfer a legacy assigned-Animal')));
    expect(patchRelease, contains('direct populated v10 to v11 migration'));
    expect(patchRelease, contains('first non-empty legacy assigned-Animal'));
    expect(patchRelease, contains('no storage, media, network'));
    expect(dataModel, contains('### Schema Version 10'));
    expect(dataModel, contains('### Schema Version 11'));
    expect(dataModel, contains('Box.temperatureZones'));
    expect(backupFormat, contains('### Animal Taxonomy Fields'));
    expect(backupFormat, contains('`BackupBox.temperatureZones`'));
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
