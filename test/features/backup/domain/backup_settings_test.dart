import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/domain/backup_settings.dart';

void main() {
  test('settings survive json round trip', () {
    const original = BackupSettings(
      themeMode: 'dark',
      accent: 'green',
      language: 'german',
      animalNameOrder: 'latinNameFirst',
    );

    final restored = BackupSettings.fromJson(original.toJson());

    expect(restored.themeMode, 'dark');

    expect(restored.accent, 'green');

    expect(restored.language, 'german');

    expect(restored.animalNameOrder, 'latinNameFirst');
  });

  test('legacy settings without language default to system', () {
    final restored = BackupSettings.fromJson({
      'themeMode': 'light',
      'accent': 'blue',
    });

    expect(restored.language, 'system');

    expect(restored.animalNameOrder, 'commonNameFirst');
  });
}
