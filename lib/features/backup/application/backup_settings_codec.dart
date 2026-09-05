import 'package:flutter/material.dart';

import '../../settings/app_accent.dart';
import '../../settings/app_language.dart';
import '../domain/backup_settings.dart';

class BackupSettingsCodec {
  BackupSettingsCodec._();

  static BackupSettings encode({
    required ThemeMode themeMode,
    required AppAccent accent,
    AppLanguage language = AppLanguage.system,
  }) {
    return BackupSettings(
      themeMode: encodeThemeMode(themeMode),
      accent: encodeAccent(accent),
      language: encodeLanguage(language),
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

  static String encodeLanguage(AppLanguage value) {
    return switch (value) {
      AppLanguage.system => 'system',
      AppLanguage.english => 'english',
      AppLanguage.german => 'german',
    };
  }

  static AppLanguage decodeLanguage(String value) {
    return switch (value) {
      'system' => AppLanguage.system,
      'english' => AppLanguage.english,
      'german' => AppLanguage.german,
      _ => throw FormatException(
        'Unsupported AppLanguage backup value: $value',
      ),
    };
  }
}
