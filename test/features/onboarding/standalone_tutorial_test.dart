import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/onboarding/presentation/standalone_tutorial_gate.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase database;
  late AppSettingsController settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
    settings = AppSettingsController();
  });

  tearDown(() async {
    settings.dispose();
    await database.close();
  });

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StandaloneTutorialGate(database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first empty collection gets a skippable interactive tour', (
    tester,
  ) async {
    await pumpGate(tester);
    expect(find.byKey(const Key('standalone-tutorial-dialog')), findsOneWidget);
    expect(find.text('Create a Box'), findsOneWidget);
    await tester.tap(find.byKey(const Key('standalone-tutorial-next')));
    await tester.pumpAndSettle();
    expect(find.text('Add an Animal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('standalone-tutorial-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('standalone-tutorial-dialog')), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('standalone_tutorial_seen'), isTrue);
  });

  testWidgets('existing collection opens without onboarding interruption', (
    tester,
  ) async {
    await BoxRepository(database)
        .createBox('TM:BOX:76767676-7676-4767-8767-767676767676');
    await pumpGate(tester);
    expect(find.byKey(const Key('standalone-tutorial-dialog')), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('standalone_tutorial_seen'), isTrue);
  });

  testWidgets(
    'replayed introduction keeps Settings selected and never opens an overview',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'standalone_tutorial_seen': true,
      });
      await pumpGate(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      final replay = find.byKey(const Key('replay-tutorial-button'));
      await tester.scrollUntilVisible(
        replay,
        350,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(replay);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('standalone-tutorial-dialog')),
        findsOneWidget,
      );
      for (var step = 1; step <= 4; step++) {
        expect(find.text('Step $step of 4'), findsOneWidget);
        expect(
          find.byKey(const Key('standalone-tutorial-open-section')),
          findsNothing,
        );
        if (step == 2) {
          await tester.tap(find.byKey(const Key('standalone-tutorial-back')));
          await tester.pumpAndSettle();
          expect(find.text('Step 1 of 4'), findsOneWidget);
          await tester.tap(find.byKey(const Key('standalone-tutorial-next')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('standalone-tutorial-next')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('standalone-tutorial-dialog')), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(await BoxRepository(database).getAllBoxes(), isEmpty);
    },
  );
}
