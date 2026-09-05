import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system theme, green accent, and system language', () async {
    final controller = AppSettingsController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.system);

    expect(controller.accent, AppAccent.green);

    expect(controller.language, AppLanguage.system);
  });

  test('loads persisted settings', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'accent': 'purple',
      'language': 'german',
    });

    final controller = AppSettingsController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.dark);

    expect(controller.accent, AppAccent.purple);

    expect(controller.language, AppLanguage.german);
  });

  test('persists theme mode', () async {
    final controller = AppSettingsController();

    await controller.load();

    await controller.setThemeMode(ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('theme_mode'), 'dark');
  });

  test('persists accent', () async {
    final controller = AppSettingsController();

    await controller.load();

    await controller.setAccent(AppAccent.orange);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('accent'), 'orange');
  });

  test('persists language', () async {
    final controller = AppSettingsController();

    await controller.load();

    await controller.setLanguage(AppLanguage.english);

    final preferences = await SharedPreferences.getInstance();

    expect(controller.language, AppLanguage.english);

    expect(preferences.getString('language'), 'english');
  });

  test('invalid persisted settings fall back safely', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'invalid-theme',
      'accent': 'invalid-accent',
      'language': 'invalid-language',
    });

    final controller = AppSettingsController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.system);

    expect(controller.accent, AppAccent.green);

    expect(controller.language, AppLanguage.system);
  });

  test('replaceSettings persists all settings together', () async {
    final controller = AppSettingsController();

    await controller.load();

    await controller.replaceSettings(
      themeMode: ThemeMode.dark,
      accent: AppAccent.purple,
      language: AppLanguage.german,
    );

    expect(controller.themeMode, ThemeMode.dark);

    expect(controller.accent, AppAccent.purple);

    expect(controller.language, AppLanguage.german);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('theme_mode'), 'dark');

    expect(preferences.getString('accent'), 'purple');

    expect(preferences.getString('language'), 'german');
  });
}
