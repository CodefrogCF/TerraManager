import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/application/backup_settings_codec.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';

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

  test('languages use stable backup values and round trip', () {
    expect(BackupSettingsCodec.encodeLanguage(AppLanguage.system), 'system');
    expect(BackupSettingsCodec.encodeLanguage(AppLanguage.english), 'english');
    expect(BackupSettingsCodec.encodeLanguage(AppLanguage.german), 'german');

    for (final value in AppLanguage.values) {
      final encoded = BackupSettingsCodec.encodeLanguage(value);

      final decoded = BackupSettingsCodec.decodeLanguage(encoded);

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

    expect(
      () => BackupSettingsCodec.decodeLanguage('future-language'),
      throwsFormatException,
    );

    expect(
      () => BackupSettingsCodec.decodeAnimalNameOrder('future-name-order'),
      throwsFormatException,
    );

    expect(
      () => BackupSettingsCodec.decodeBoxSortOrder('future-box-sort-order'),
      throwsFormatException,
    );

    expect(
      () =>
          BackupSettingsCodec.decodeAnimalSortOrder('future-animal-sort-order'),
      throwsFormatException,
    );
  });

  test('Animal name orders use stable backup values and round trip', () {
    expect(
      BackupSettingsCodec.encodeAnimalNameOrder(
        AnimalNameOrder.commonNameFirst,
      ),
      'commonNameFirst',
    );
    expect(
      BackupSettingsCodec.encodeAnimalNameOrder(AnimalNameOrder.latinNameFirst),
      'latinNameFirst',
    );

    for (final value in AnimalNameOrder.values) {
      final encoded = BackupSettingsCodec.encodeAnimalNameOrder(value);
      final decoded = BackupSettingsCodec.decodeAnimalNameOrder(encoded);

      expect(decoded, value);
    }
  });

  test('Box sort orders use stable backup values and round trip', () {
    expect(
      BackupSettingsCodec.encodeBoxSortOrder(BoxSortOrder.createdOldestFirst),
      'createdOldestFirst',
    );
    expect(
      BackupSettingsCodec.encodeBoxSortOrder(BoxSortOrder.createdNewestFirst),
      'createdNewestFirst',
    );
    expect(
      BackupSettingsCodec.encodeBoxSortOrder(BoxSortOrder.labelAscending),
      'labelAscending',
    );
    expect(
      BackupSettingsCodec.encodeBoxSortOrder(BoxSortOrder.labelDescending),
      'labelDescending',
    );

    for (final value in BoxSortOrder.values) {
      final encoded = BackupSettingsCodec.encodeBoxSortOrder(value);
      final decoded = BackupSettingsCodec.decodeBoxSortOrder(encoded);

      expect(decoded, value);
    }
  });

  test('Animal sort orders use stable backup values and round trip', () {
    const stableValues = {
      AnimalSortOrder.createdOldestFirst: 'createdOldestFirst',
      AnimalSortOrder.createdNewestFirst: 'createdNewestFirst',
      AnimalSortOrder.displayNameAscending: 'displayNameAscending',
      AnimalSortOrder.displayNameDescending: 'displayNameDescending',
      AnimalSortOrder.ageOldestFirst: 'ageOldestFirst',
      AnimalSortOrder.ageYoungestFirst: 'ageYoungestFirst',
      AnimalSortOrder.latestFeedingNewestFirst: 'latestFeedingNewestFirst',
      AnimalSortOrder.latestFeedingOldestFirst: 'latestFeedingOldestFirst',
    };

    for (final entry in stableValues.entries) {
      final encoded = BackupSettingsCodec.encodeAnimalSortOrder(entry.key);
      final decoded = BackupSettingsCodec.decodeAnimalSortOrder(encoded);

      expect(encoded, entry.value);
      expect(decoded, entry.key);
    }
  });
}
