import 'package:flutter/material.dart';

import '../../settings/app_accent.dart';
import '../../settings/app_language.dart';
import '../../settings/animal_name_order.dart';
import '../../settings/animal_sort_order.dart';
import '../../settings/box_sort_order.dart';
import '../domain/backup_settings.dart';

class BackupSettingsCodec {
  BackupSettingsCodec._();

  static BackupSettings encode({
    required ThemeMode themeMode,
    required AppAccent accent,
    AppLanguage language = AppLanguage.system,
    AnimalNameOrder animalNameOrder = AnimalNameOrder.commonNameFirst,
    AnimalSortOrder animalSortOrder = AnimalSortOrder.createdOldestFirst,
    BoxSortOrder boxSortOrder = BoxSortOrder.labelAscending,
  }) {
    return BackupSettings(
      themeMode: encodeThemeMode(themeMode),
      accent: encodeAccent(accent),
      language: encodeLanguage(language),
      animalNameOrder: encodeAnimalNameOrder(animalNameOrder),
      animalSortOrder: encodeAnimalSortOrder(animalSortOrder),
      boxSortOrder: encodeBoxSortOrder(boxSortOrder),
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

  static String encodeAnimalNameOrder(AnimalNameOrder value) {
    return switch (value) {
      AnimalNameOrder.commonNameFirst => 'commonNameFirst',
      AnimalNameOrder.latinNameFirst => 'latinNameFirst',
    };
  }

  static AnimalNameOrder decodeAnimalNameOrder(String value) {
    return switch (value) {
      'commonNameFirst' => AnimalNameOrder.commonNameFirst,
      'latinNameFirst' => AnimalNameOrder.latinNameFirst,
      _ => throw FormatException(
        'Unsupported AnimalNameOrder backup value: $value',
      ),
    };
  }

  static String encodeBoxSortOrder(BoxSortOrder value) {
    return switch (value) {
      BoxSortOrder.labelAscending => 'labelAscending',
      BoxSortOrder.labelDescending => 'labelDescending',
    };
  }

  static BoxSortOrder decodeBoxSortOrder(String value) {
    return switch (value) {
      'labelAscending' || 'createdOldestFirst' => BoxSortOrder.labelAscending,
      'labelDescending' || 'createdNewestFirst' => BoxSortOrder.labelDescending,
      _ => throw FormatException(
        'Unsupported BoxSortOrder backup value: $value',
      ),
    };
  }

  static String encodeAnimalSortOrder(AnimalSortOrder value) {
    return switch (value) {
      AnimalSortOrder.createdOldestFirst => 'createdOldestFirst',
      AnimalSortOrder.createdNewestFirst => 'createdNewestFirst',
      AnimalSortOrder.displayNameAscending => 'displayNameAscending',
      AnimalSortOrder.displayNameDescending => 'displayNameDescending',
      AnimalSortOrder.ageOldestFirst => 'ageOldestFirst',
      AnimalSortOrder.ageYoungestFirst => 'ageYoungestFirst',
      AnimalSortOrder.latestFeedingNewestFirst => 'latestFeedingNewestFirst',
      AnimalSortOrder.latestFeedingOldestFirst => 'latestFeedingOldestFirst',
    };
  }

  static AnimalSortOrder decodeAnimalSortOrder(String value) {
    return switch (value) {
      'createdOldestFirst' => AnimalSortOrder.createdOldestFirst,
      'createdNewestFirst' => AnimalSortOrder.createdNewestFirst,
      'displayNameAscending' => AnimalSortOrder.displayNameAscending,
      'displayNameDescending' => AnimalSortOrder.displayNameDescending,
      'ageOldestFirst' => AnimalSortOrder.ageOldestFirst,
      'ageYoungestFirst' => AnimalSortOrder.ageYoungestFirst,
      'latestFeedingNewestFirst' => AnimalSortOrder.latestFeedingNewestFirst,
      'latestFeedingOldestFirst' => AnimalSortOrder.latestFeedingOldestFirst,
      _ => throw FormatException(
        'Unsupported AnimalSortOrder backup value: $value',
      ),
    };
  }
}
