import 'package:flutter/material.dart';

import '../../settings/app_accent.dart';
import '../domain/backup_settings.dart';

class BackupSettingsCodec {
  BackupSettingsCodec._();

  static BackupSettings encode({
    required ThemeMode themeMode,
    required AppAccent accent,
  }) {
    return BackupSettings(
      themeMode: encodeThemeMode(themeMode),
      accent: encodeAccent(accent),
    );
  }

  static String encodeThemeMode(ThemeMode value) {
    return switch (value) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
  }

  static ThemeMode decodeThemeMode(String value) {
    return switch (value) {
      'system' => ThemeMode.system,
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => throw FormatException('Unsupported ThemeMode backup value: $value'),
    };
  }

  static String encodeAccent(AppAccent value) {
    return switch (value) {
      AppAccent.green => 'green',
      AppAccent.blue => 'blue',
      AppAccent.teal => 'teal',
      AppAccent.orange => 'orange',
      AppAccent.purple => 'purple',
      AppAccent.red => 'red',
    };
  }

  static AppAccent decodeAccent(String value) {
    return switch (value) {
      'green' => AppAccent.green,
      'blue' => AppAccent.blue,
      'teal' => AppAccent.teal,
      'orange' => AppAccent.orange,
      'purple' => AppAccent.purple,
      'red' => AppAccent.red,
      _ => throw FormatException('Unsupported AppAccent backup value: $value'),
    };
  }
}
