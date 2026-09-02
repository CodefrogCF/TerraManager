import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/app.dart';
import 'package:terramanager/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('loads persisted dark theme', (tester) async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'accent': 'purple',
    });

    await tester.pumpWidget(TerraManagerApp(database: database));

    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.themeMode, ThemeMode.dark);

    expect(materialApp.darkTheme?.colorScheme.brightness, Brightness.dark);
  });
}
