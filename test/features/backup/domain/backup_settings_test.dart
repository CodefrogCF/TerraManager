import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/domain/backup_settings.dart';

void main() {
  test('settings survive json round trip', () {
    const original = BackupSettings(
      themeMode: 'dark',
      accent: 'green',
      language: 'german',
      animalNameOrder: 'latinNameFirst',
      animalSortOrder: 'latestFeedingOldestFirst',
      animalCategoryViewEnabled: true,
      bigPictureModeEnabled: true,
      boxSortOrder: 'labelDescending',
    );

    final restored = BackupSettings.fromJson(original.toJson());

    expect(restored.themeMode, 'dark');

    expect(restored.accent, 'green');

    expect(restored.language, 'german');

    expect(restored.animalNameOrder, 'latinNameFirst');

    expect(restored.animalSortOrder, 'latestFeedingOldestFirst');

    expect(restored.animalCategoryViewEnabled, isTrue);

    expect(restored.bigPictureModeEnabled, isTrue);

    expect(restored.boxSortOrder, 'labelDescending');
  });

  test('legacy settings without language default to system', () {
    final restored = BackupSettings.fromJson({
      'themeMode': 'light',
      'accent': 'blue',
    });

    expect(restored.language, 'system');

    expect(restored.animalNameOrder, 'commonNameFirst');

    expect(restored.animalSortOrder, 'createdOldestFirst');

    expect(restored.animalCategoryViewEnabled, isFalse);

    expect(restored.boxSortOrder, 'labelAscending');
  });

  test('legacy category sort enables category view', () {
    final restored = BackupSettings.fromJson({
      'themeMode': 'light',
      'accent': 'blue',
      'animalSortOrder': 'categoryDescending',
    });

    expect(restored.animalCategoryViewEnabled, isTrue);
  });

  test('defaults Big Picture Mode to false when missing from JSON', () {
    final settings = BackupSettings.fromJson({
      'themeMode': 'system',
      'accent': 'green',
    });

    expect(settings.bigPictureModeEnabled, isFalse);
  });
}
