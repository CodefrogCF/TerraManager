import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/domain/backup_settings.dart';

void main() {
  test('settings survive json round trip', () {
    const original = BackupSettings(themeMode: 'dark', accent: 'green');

    final restored = BackupSettings.fromJson(original.toJson());

    expect(restored.themeMode, 'dark');

    expect(restored.accent, 'green');
  });
}
