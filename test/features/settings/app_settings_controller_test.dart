import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system theme, green accent, system language, common '
      'name first, and oldest Boxes first', () async {
    final controller = AppSettingsController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.system);

    expect(controller.accent, AppAccent.green);

    expect(controller.language, AppLanguage.system);

    expect(controller.animalNameOrder, AnimalNameOrder.commonNameFirst);

    expect(controller.boxSortOrder, BoxSortOrder.createdOldestFirst);
  });

  test('loads persisted settings', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'accent': 'purple',
      'language': 'german',
      'animal_name_order': 'latinNameFirst',
      'box_sort_order': 'labelDescending',
    });

    final controller = AppSettingsController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.dark);

    expect(controller.accent, AppAccent.purple);

    expect(controller.language, AppLanguage.german);

    expect(controller.animalNameOrder, AnimalNameOrder.latinNameFirst);

    expect(controller.boxSortOrder, BoxSortOrder.labelDescending);
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

  test('persists Animal name order', () async {
    final controller = AppSettingsController();

    await controller.load();

    await controller.setAnimalNameOrder(AnimalNameOrder.latinNameFirst);

    final preferences = await SharedPreferences.getInstance();

    expect(controller.animalNameOrder, AnimalNameOrder.latinNameFirst);

    expect(preferences.getString('animal_name_order'), 'latinNameFirst');
  });

  test('persists Box sort order', () async {
    final controller = AppSettingsController();

    await controller.load();

    await controller.setBoxSortOrder(BoxSortOrder.createdNewestFirst);

    final preferences = await SharedPreferences.getInstance();

    expect(controller.boxSortOrder, BoxSortOrder.createdNewestFirst);

    expect(preferences.getString('box_sort_order'), 'createdNewestFirst');
  });

  test('invalid persisted settings fall back safely', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'invalid-theme',
      'accent': 'invalid-accent',
      'language': 'invalid-language',
      'animal_name_order': 'invalid-name-order',
      'box_sort_order': 'invalid-box-sort-order',
    });

    final controller = AppSettingsController();

    await controller.load();

    expect(controller.themeMode, ThemeMode.system);

    expect(controller.accent, AppAccent.green);

    expect(controller.language, AppLanguage.system);

    expect(controller.animalNameOrder, AnimalNameOrder.commonNameFirst);

    expect(controller.boxSortOrder, BoxSortOrder.createdOldestFirst);
  });

  test('replaceSettings persists all settings together', () async {
    final controller = AppSettingsController();

    await controller.load();

    await controller.replaceSettings(
      themeMode: ThemeMode.dark,
      accent: AppAccent.purple,
      language: AppLanguage.german,
      animalNameOrder: AnimalNameOrder.latinNameFirst,
      boxSortOrder: BoxSortOrder.labelDescending,
    );

    expect(controller.themeMode, ThemeMode.dark);

    expect(controller.accent, AppAccent.purple);

    expect(controller.language, AppLanguage.german);

    expect(controller.animalNameOrder, AnimalNameOrder.latinNameFirst);

    expect(controller.boxSortOrder, BoxSortOrder.labelDescending);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('theme_mode'), 'dark');

    expect(preferences.getString('accent'), 'purple');

    expect(preferences.getString('language'), 'german');

    expect(preferences.getString('animal_name_order'), 'latinNameFirst');

    expect(preferences.getString('box_sort_order'), 'labelDescending');
  });
}
