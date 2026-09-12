import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/app.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/navigation/presentation/pages/app_shell.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('keeps dynamic English messages unchanged', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(l10n.boxLabel(7), 'Box 7');
    expect(l10n.addAnimal, 'Add Animal');
    expect(
      l10n.activeAnimalsAssignedToBox(1, 'Box 7'),
      '1 active animal assigned to Box 7',
    );
    expect(
      l10n.activeAnimalsAssignedToBox(3, 'Box 7'),
      '3 active animals assigned to Box 7',
    );
    expect(l10n.saveFeedings(1), 'Save Feeding');
    expect(l10n.saveFeedings(3), 'Save 3 Feedings');
    expect(l10n.scanDifferentBox, 'Scan a different Box');
    expect(l10n.feedingReminder, 'Feeding reminder');
    expect(l10n.feedingReminderIntervalDays, 'Reminder interval (days)');
    expect(l10n.failedToSaveFeedingReminder, 'Failed to save feeding reminder');
    expect(l10n.aboutTerraManager, 'About TerraManager');
    expect(l10n.buildNumber, 'Build');
    expect(l10n.developer, 'Developer');
    expect(l10n.sexMale, 'Male');
    expect(l10n.sexFemale, 'Female');
    expect(l10n.sexUnknown, 'Unknown');
    expect(l10n.birthDateAccuracyExact, 'Exact');
    expect(l10n.birthDateAccuracyMonthKnown, 'Month known');
    expect(l10n.birthDateAccuracyYearKnown, 'Year known');
    expect(l10n.sortBoxes, 'Sort boxes');
    expect(l10n.boxSortLabelAscending, 'Box number ascending');
    expect(l10n.boxSortLabelDescending, 'Box number descending');
    expect(l10n.sortAnimals, 'Sort animals');
    expect(l10n.animalSortCreatedOldestFirst, 'Oldest added first');
    expect(l10n.animalSortCreatedNewestFirst, 'Newest added first');
    expect(l10n.animalSortNameAscending, 'Name A–Z');
    expect(l10n.animalSortNameDescending, 'Name Z–A');
    expect(l10n.animalSortAgeOldestFirst, 'Oldest animals first');
    expect(l10n.animalSortAgeYoungestFirst, 'Youngest animals first');
    expect(l10n.animalSortLatestFeedingNewestFirst, 'Newest feeding first');
    expect(l10n.animalSortLatestFeedingOldestFirst, 'Oldest feeding first');
    expect(l10n.animalsDueForFeeding(1), '1 Animal is due for feeding');
    expect(l10n.animalsDueForFeeding(3), '3 Animals are due for feeding');
    expect(
      l10n.feedingDueSince('08.09.2026 12:00'),
      'Due since 08.09.2026 12:00',
    );
  });

  test('German catalog covers every English message', () {
    final english = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final german = jsonDecode(
      File('lib/l10n/app_de.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    final englishKeys = english.keys
        .where((key) => !key.startsWith('@'))
        .toSet();
    final germanKeys = german.keys.where((key) => !key.startsWith('@')).toSet();

    expect(germanKeys, unorderedEquals(englishKeys));
    expect(
      germanKeys.every((key) => (german[key] as String).trim().isNotEmpty),
      isTrue,
    );
  });

  test('provides German dynamic messages', () {
    final l10n = lookupAppLocalizations(const Locale('de'));

    expect(l10n.boxLabel(7), 'Box 7');
    expect(l10n.addAnimal, 'Tier hinzufügen');
    expect(
      l10n.activeAnimalsAssignedToBox(1, 'Box 7'),
      '1 aktives Tier ist Box 7 zugewiesen',
    );
    expect(
      l10n.activeAnimalsAssignedToBox(3, 'Box 7'),
      '3 aktive Tiere sind Box 7 zugewiesen',
    );
    expect(l10n.saveFeedings(1), 'Fütterung speichern');
    expect(l10n.saveFeedings(3), '3 Fütterungen speichern');
    expect(l10n.scanDifferentBox, 'Andere Box scannen');
    expect(l10n.feedingReminder, 'Fütterungserinnerung');
    expect(l10n.feedingReminderIntervalDays, 'Erinnerungsintervall (Tage)');
    expect(
      l10n.failedToSaveFeedingReminder,
      'Fütterungserinnerung konnte nicht gespeichert werden',
    );
    expect(l10n.aboutTerraManager, 'Über TerraManager');
    expect(l10n.buildNumber, 'Build');
    expect(l10n.developer, 'Entwickler');
    expect(l10n.sexMale, 'Männlich');
    expect(l10n.sexFemale, 'Weiblich');
    expect(l10n.sexUnknown, 'Unbekannt');
    expect(l10n.birthDateAccuracyExact, 'Genau');
    expect(l10n.birthDateAccuracyMonthKnown, 'Monat bekannt');
    expect(l10n.birthDateAccuracyYearKnown, 'Jahr bekannt');
    expect(l10n.sortBoxes, 'Boxen sortieren');
    expect(l10n.boxSortLabelAscending, 'Boxnummer aufsteigend');
    expect(l10n.boxSortLabelDescending, 'Boxnummer absteigend');
    expect(l10n.sortAnimals, 'Tiere sortieren');
    expect(l10n.animalSortCreatedOldestFirst, 'Zuerst hinzugefügt');
    expect(l10n.animalSortCreatedNewestFirst, 'Zuletzt hinzugefügt');
    expect(l10n.animalSortNameAscending, 'Name A–Z');
    expect(l10n.animalSortNameDescending, 'Name Z–A');
    expect(l10n.animalSortAgeOldestFirst, 'Älteste Tiere zuerst');
    expect(l10n.animalSortAgeYoungestFirst, 'Jüngste Tiere zuerst');
    expect(l10n.animalSortLatestFeedingNewestFirst, 'Neueste Fütterung zuerst');
    expect(l10n.animalSortLatestFeedingOldestFirst, 'Älteste Fütterung zuerst');
    expect(l10n.animalsDueForFeeding(1), '1 Tier ist zur Fütterung fällig');
    expect(l10n.animalsDueForFeeding(3), '3 Tiere sind zur Fütterung fällig');
    expect(
      l10n.feedingDueSince('08.09.2026 12:00'),
      'Fällig seit 08.09.2026 12:00',
    );
  });

  testWidgets('supports selecting a fixed English locale', (tester) async {
    await tester.pumpWidget(
      TerraManagerApp(database: database, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.locale, const Locale('en'));
    expect(
      AppLocalizations.supportedLocales,
      unorderedEquals(supportedAppLocales),
    );
    expect(materialApp.supportedLocales, supportedAppLocales);
    expect(find.text('Boxes'), findsWidgets);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('changes language immediately and keeps it after restart', (
    tester,
  ) async {
    await tester.pumpWidget(TerraManagerApp(database: database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final settingsScrollable = find.descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('language-selector')),
      300,
      scrollable: settingsScrollable.first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsWidgets);

    final appShellContext = tester.element(find.byType(AppShell));
    expect(Localizations.localeOf(appShellContext), const Locale('de'));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('language'), 'german');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(TerraManagerApp(database: database));
    await tester.pumpAndSettle();

    final restartedContext = tester.element(find.byType(AppShell));
    expect(Localizations.localeOf(restartedContext), const Locale('de'));
    expect(find.text('Boxen'), findsWidgets);
  });

  testWidgets('falls back to English for an unsupported locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      TerraManagerApp(database: database, locale: const Locale('fr')),
    );
    await tester.pumpAndSettle();

    final appShellContext = tester.element(find.byType(AppShell));

    expect(Localizations.localeOf(appShellContext), const Locale('en'));
    expect(find.text('Boxes'), findsWidgets);
  });
}
