import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/navigation/presentation/pages/app_shell.dart';

void main() {
  late AppDatabase database;
  late AppSettingsController settingsController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    database = AppDatabase.test(NativeDatabase.memory());

    settingsController = AppSettingsController();
    await settingsController.load();
  });

  tearDown(() async {
    settingsController.dispose();
    await database.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settingsController,
        child: MaterialApp(home: AppShell(database: database)),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows boxes page by default', (tester) async {
    await pumpApp(tester);

    expect(find.text('Boxes'), findsWidgets);
    expect(find.text('No boxes available'), findsOneWidget);
  });

  testWidgets('can navigate to settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('can navigate to animals', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Animals').first);
    await tester.pumpAndSettle();

    expect(find.text('No animals available'), findsOneWidget);
  });

  testWidgets('can navigate back to boxes', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boxes').first);
    await tester.pumpAndSettle();

    expect(find.text('No boxes available'), findsOneWidget);
  });
}
