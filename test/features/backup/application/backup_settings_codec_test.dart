import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/application/backup_settings_codec.dart';
import 'package:terramanager/features/settings/app_accent.dart';

void main() {
  test('theme modes use stable backup values', () {
    expect(BackupSettingsCodec.encodeThemeMode(ThemeMode.system), 'system');

    expect(BackupSettingsCodec.encodeThemeMode(ThemeMode.light), 'light');

    expect(BackupSettingsCodec.encodeThemeMode(ThemeMode.dark), 'dark');
  });

  test('theme modes round trip', () {
    for (final value in ThemeMode.values) {
      final encoded = BackupSettingsCodec.encodeThemeMode(value);

      final decoded = BackupSettingsCodec.decodeThemeMode(encoded);

      expect(decoded, value);
    }
  });

  test('accents round trip', () {
    for (final value in AppAccent.values) {
      final encoded = BackupSettingsCodec.encodeAccent(value);

      final decoded = BackupSettingsCodec.decodeAccent(encoded);

      expect(decoded, value);
    }
  });

  test('unsupported settings values throw', () {
    expect(
      () => BackupSettingsCodec.decodeThemeMode('future-theme'),
      throwsFormatException,
    );

    expect(
      () => BackupSettingsCodec.decodeAccent('future-accent'),
      throwsFormatException,
    );
  });
}
