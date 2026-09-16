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
    expect(l10n.boxName, 'Box Name');
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
    expect(l10n.createSafetyBackup, 'Back up current data before restoring');
    expect(l10n.sexMale, 'Male');
    expect(l10n.sexFemale, 'Female');
    expect(l10n.sexOther, 'Hermaphrodite / other');
    expect(l10n.sexUnknown, 'Unknown');
    expect(l10n.additionalCharacteristics, 'Additional characteristics');
    expect(l10n.originHabitat, 'Origin / habitat');
    expect(l10n.restOrDormancyPeriods, 'Rest or dormancy periods');
    expect(l10n.minimumTemperatureCelsius, 'Minimum daytime temperature (°C)');
    expect(l10n.maximumTemperatureCelsius, 'Maximum daytime temperature (°C)');
    expect(l10n.nighttimeTemperatureCelsius, 'Nighttime temperature (°C)');
    expect(l10n.categoryReptiles, 'Reptiles');
    expect(l10n.subcategorySnakes, 'Snakes');
    expect(l10n.licenseTitle, 'License');
    expect(l10n.birthDateAccuracyExact, 'Exact');
    expect(l10n.birthDateAccuracyMonthKnown, 'Month known');
    expect(l10n.birthDateAccuracyYearKnown, 'Year known');
    expect(l10n.sortBoxes, 'Sort boxes');
    expect(l10n.boxSortLabelAscending, 'Box number ascending');
    expect(l10n.boxSortLabelDescending, 'Box number descending');
    expect(l10n.boxSortNameAscending, 'Name A–Z');
    expect(l10n.boxSortNameDescending, 'Name Z–A');
    expect(l10n.boxSortVolumeAscending, 'Volume ascending');
    expect(l10n.boxSortVolumeDescending, 'Volume descending');
    expect(l10n.sortAnimals, 'Sort animals');
    expect(l10n.animalSortCreatedOldestFirst, 'Oldest added first');
    expect(l10n.animalSortCreatedNewestFirst, 'Newest added first');
    expect(l10n.animalSortNameAscending, 'Name A–Z');
    expect(l10n.animalSortNameDescending, 'Name Z–A');
    expect(l10n.animalSortAgeOldestFirst, 'Oldest animals first');
    expect(l10n.animalSortAgeYoungestFirst, 'Youngest animals first');
    expect(l10n.animalSortLatestFeedingNewestFirst, 'Newest feeding first');
    expect(l10n.animalSortLatestFeedingOldestFirst, 'Oldest feeding first');
    expect(l10n.animalActions('Mango'), 'Actions for Mango');
    expect(l10n.boxActions('Main Box'), 'Actions for Main Box');
    expect(l10n.createFeeding, 'Create Feeding');
    expect(l10n.renameAnimal, 'Rename Animal');
    expect(l10n.renameBox, 'Rename Box');
    expect(l10n.duplicateAnimal, 'Duplicate Animal');
    expect(l10n.duplicateBox, 'Duplicate Box');
    expect(l10n.copyName('Mango'), 'Mango (copy)');
    expect(l10n.boxQrCodes, 'Box QR Codes');
    expect(l10n.saveBoxQrCodes, 'Save Box QR Codes');
    expect(
      l10n.saveBoxQrCodesDescription,
      'Choose the Boxes whose QR codes you want to save.',
    );
    expect(l10n.activeBoxes, 'Active Boxes');
    expect(l10n.clearSelection, 'Clear selection');
    expect(l10n.selectAtLeastOneBox, 'Select at least one Box.');
    expect(l10n.boxQrExportSucceeded(1), '1 Box QR code saved');
    expect(l10n.boxQrExportSucceeded(3), '3 Box QR codes saved');
    expect(l10n.boxQrExportPartial(2, 1), '2 saved; 1 failed.');
    expect(l10n.saveBoxQrCodesAsZip, 'Save Box QR Codes as ZIP');
    expect(l10n.saveBoxQrCodesAsPdf, 'Save Box QR Codes as PDF');
    expect(l10n.boxQrCodeSizeValue(6), 'QR code size: 6 × 6 mm');
    expect(l10n.boxQrZipExportSucceeded(2), 'ZIP with 2 Box QR codes saved');
    expect(l10n.boxQrPdfExportSucceeded(2), 'PDF with 2 Box QR codes saved');
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
    expect(l10n.boxName, 'Boxname');
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
    expect(
      l10n.createSafetyBackup,
      'Aktuelle Daten vor Wiederherstellung sichern',
    );
    expect(l10n.sexMale, 'Männlich');
    expect(l10n.sexFemale, 'Weiblich');
    expect(l10n.sexOther, 'Zwitter / andere');
    expect(l10n.sexUnknown, 'Unbekannt');
    expect(l10n.additionalCharacteristics, 'Zusätzliche Merkmale');
    expect(l10n.originHabitat, 'Herkunft / Lebensraum');
    expect(l10n.restOrDormancyPeriods, 'Ruhe- oder Dormanzzeiten');
    expect(l10n.minimumTemperatureCelsius, 'Minimale Tagestemperatur (°C)');
    expect(l10n.maximumTemperatureCelsius, 'Maximale Tagestemperatur (°C)');
    expect(l10n.nighttimeTemperatureCelsius, 'Nachttemperatur (°C)');
    expect(l10n.categoryReptiles, 'Reptilien');
    expect(l10n.subcategorySnakes, 'Schlangen');
    expect(l10n.licenseTitle, 'Lizenz');
    expect(l10n.birthDateAccuracyExact, 'Genau');
    expect(l10n.birthDateAccuracyMonthKnown, 'Monat bekannt');
    expect(l10n.birthDateAccuracyYearKnown, 'Jahr bekannt');
    expect(l10n.sortBoxes, 'Boxen sortieren');
    expect(l10n.boxSortLabelAscending, 'Boxnummer aufsteigend');
    expect(l10n.boxSortLabelDescending, 'Boxnummer absteigend');
    expect(l10n.boxSortNameAscending, 'Name A–Z');
    expect(l10n.boxSortNameDescending, 'Name Z–A');
    expect(l10n.boxSortVolumeAscending, 'Volumen aufsteigend');
    expect(l10n.boxSortVolumeDescending, 'Volumen absteigend');
    expect(l10n.sortAnimals, 'Tiere sortieren');
    expect(l10n.animalSortCreatedOldestFirst, 'Zuerst hinzugefügt');
    expect(l10n.animalSortCreatedNewestFirst, 'Zuletzt hinzugefügt');
    expect(l10n.animalSortNameAscending, 'Name A–Z');
    expect(l10n.animalSortNameDescending, 'Name Z–A');
    expect(l10n.animalSortAgeOldestFirst, 'Älteste Tiere zuerst');
    expect(l10n.animalSortAgeYoungestFirst, 'Jüngste Tiere zuerst');
    expect(l10n.animalSortLatestFeedingNewestFirst, 'Neueste Fütterung zuerst');
    expect(l10n.animalSortLatestFeedingOldestFirst, 'Älteste Fütterung zuerst');
    expect(l10n.animalActions('Mango'), 'Aktionen für Mango');
    expect(l10n.boxActions('Hauptbox'), 'Aktionen für Hauptbox');
    expect(l10n.createFeeding, 'Fütterung erstellen');
    expect(l10n.renameAnimal, 'Tier umbenennen');
    expect(l10n.renameBox, 'Box umbenennen');
    expect(l10n.duplicateAnimal, 'Tier duplizieren');
    expect(l10n.duplicateBox, 'Box duplizieren');
    expect(l10n.copyName('Mango'), 'Mango (Kopie)');
    expect(l10n.boxQrCodes, 'Box-QR-Codes');
    expect(l10n.saveBoxQrCodes, 'Box-QR-Codes speichern');
    expect(
      l10n.saveBoxQrCodesDescription,
      'Wähle die Boxen aus, deren QR-Codes gespeichert werden sollen.',
    );
    expect(l10n.activeBoxes, 'Aktive Boxen');
    expect(l10n.clearSelection, 'Auswahl leeren');
    expect(l10n.selectAtLeastOneBox, 'Wähle mindestens eine Box aus.');
    expect(l10n.boxQrExportSucceeded(1), '1 Box-QR-Code gespeichert');
    expect(l10n.boxQrExportSucceeded(3), '3 Box-QR-Codes gespeichert');
    expect(l10n.saveBoxQrCodesAsZip, 'Box-QR-Codes als ZIP speichern');
    expect(l10n.saveBoxQrCodesAsPdf, 'Box-QR-Codes als PDF speichern');
    expect(l10n.boxQrCodeSizeValue(6), 'QR-Code-Größe: 6 × 6 mm');
    expect(
      l10n.boxQrZipExportSucceeded(2),
      'ZIP mit 2 Box-QR-Codes gespeichert',
    );
    expect(
      l10n.boxQrPdfExportSucceeded(2),
      'PDF mit 2 Box-QR-Codes gespeichert',
    );
    expect(l10n.boxQrExportPartial(2, 1), '2 gespeichert; 1 fehlgeschlagen.');
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
