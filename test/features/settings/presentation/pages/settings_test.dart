import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:drift/native.dart';
import 'package:terramanager/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<AppSettingsController> pumpSettings(WidgetTester tester) async {
    final controller = AppSettingsController();

    await controller.load();

    await tester.pumpWidget(
      AppSettingsScope(
        controller: controller,
        child: MaterialApp(home: SettingsPage(database: database)),
      ),
    );

    await tester.pumpAndSettle();

    return controller;
  }

  Future<void> scrollToSetting(WidgetTester tester, Key key) async {
    final settingsScrollable = find.descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    );

    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: settingsScrollable.first,
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows appearance, Animal name, and language settings', (
    tester,
  ) async {
    await pumpSettings(tester);

    final themeSelector = find.byKey(const Key('theme-mode-selector'));

    expect(themeSelector, findsOneWidget);

    expect(
      find.descendant(of: themeSelector, matching: find.text('System')),
      findsOneWidget,
    );

    expect(find.text('Light'), findsOneWidget);

    expect(find.text('Dark'), findsOneWidget);

    for (final accent in AppAccent.values) {
      expect(find.byKey(Key('accent-${accent.name}')), findsOneWidget);
    }

    await scrollToSetting(tester, const Key('animal-name-order-selector'));

    expect(find.byKey(const Key('animal-name-order-selector')), findsOneWidget);

    expect(find.text('Common name first'), findsOneWidget);

    expect(find.text('Latin name first'), findsOneWidget);

    await scrollToSetting(tester, const Key('language-selector'));

    final languageSelector = find.byKey(const Key('language-selector'));

    expect(languageSelector, findsOneWidget);

    expect(
      find.descendant(of: languageSelector, matching: find.text('System')),
      findsOneWidget,
    );

    expect(find.text('English'), findsOneWidget);

    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('can change theme mode', (tester) async {
    final controller = await pumpSettings(tester);

    await tester.tap(find.text('Dark'));

    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.dark);
  });

  testWidgets('can change accent color', (tester) async {
    final controller = await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('accent-purple')));

    await tester.pumpAndSettle();

    expect(controller.accent, AppAccent.purple);
  });

  testWidgets('can change language', (tester) async {
    final controller = await pumpSettings(tester);

    await scrollToSetting(tester, const Key('language-selector'));

    await tester.tap(find.text('Deutsch'));

    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.german);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('language'), 'german');
  });

  testWidgets('can change preferred Animal name order', (tester) async {
    final controller = await pumpSettings(tester);

    await scrollToSetting(tester, const Key('animal-name-order-selector'));

    await tester.tap(find.text('Latin name first'));

    await tester.pumpAndSettle();

    expect(controller.animalNameOrder, AnimalNameOrder.latinNameFirst);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('animal_name_order'), 'latinNameFirst');
  });

  testWidgets('opens Privacy Policy from Settings', (tester) async {
    await pumpSettings(tester);

    await scrollToSetting(tester, const Key('privacy-policy-tile'));

    final privacyTile = find.byKey(const Key('privacy-policy-tile'));

    expect(privacyTile, findsOneWidget);

    await tester.tap(privacyTile);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-policy-page')), findsOneWidget);
    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.byKey(const Key('privacy-policy-content')), findsOneWidget);
  });
}
