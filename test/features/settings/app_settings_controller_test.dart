import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'defaults to system theme and green accent',
    () async {
      final controller = AppSettingsController();

      await controller.load();

      expect(
        controller.themeMode,
        ThemeMode.system,
      );

      expect(
        controller.accent,
        AppAccent.green,
      );
    },
  );

  test(
    'loads persisted settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'accent': 'purple',
      });

      final controller = AppSettingsController();

      await controller.load();

      expect(
        controller.themeMode,
        ThemeMode.dark,
      );

      expect(
        controller.accent,
        AppAccent.purple,
      );
    },
  );

  test(
    'persists theme mode',
    () async {
      final controller = AppSettingsController();

      await controller.load();

      await controller.setThemeMode(
        ThemeMode.dark,
      );

      final preferences =
          await SharedPreferences.getInstance();

      expect(
        preferences.getString(
          'theme_mode',
        ),
        'dark',
      );
    },
  );

  test(
    'persists accent',
    () async {
      final controller = AppSettingsController();

      await controller.load();

      await controller.setAccent(
        AppAccent.orange,
      );

      final preferences =
          await SharedPreferences.getInstance();

      expect(
        preferences.getString(
          'accent',
        ),
        'orange',
      );
    },
  );

  test(
    'invalid persisted settings fall back safely',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'invalid-theme',
        'accent': 'invalid-accent',
      });

      final controller = AppSettingsController();

      await controller.load();

      expect(
        controller.themeMode,
        ThemeMode.system,
      );

      expect(
        controller.accent,
        AppAccent.green,
      );
    },
  );
}