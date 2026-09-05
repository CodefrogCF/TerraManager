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

    await tester.ensureVisible(find.text('Deutsch'));
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
