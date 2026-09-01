import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppSettingsController> pumpSettings(
    WidgetTester tester,
  ) async {
    final controller =
        AppSettingsController();

    await controller.load();

    await tester.pumpWidget(
      AppSettingsScope(
        controller: controller,
        child: MaterialApp(
          home: const SettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    return controller;
  }

  testWidgets(
    'shows theme and accent settings',
    (tester) async {
      await pumpSettings(
        tester,
      );

      expect(
        find.byKey(
          const Key(
            'theme-mode-selector',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text('System'),
        findsOneWidget,
      );

      expect(
        find.text('Light'),
        findsOneWidget,
      );

      expect(
        find.text('Dark'),
        findsOneWidget,
      );

      for (final accent in AppAccent.values) {
        expect(
          find.byKey(
            Key(
              'accent-${accent.name}',
            ),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'can change theme mode',
    (tester) async {
      final controller =
          await pumpSettings(
        tester,
      );

      await tester.tap(
        find.text('Dark'),
      );

      await tester.pumpAndSettle();

      expect(
        controller.themeMode,
        ThemeMode.dark,
      );
    },
  );

  testWidgets(
    'can change accent color',
    (tester) async {
      final controller =
          await pumpSettings(
        tester,
      );

      await tester.tap(
        find.byKey(
          const Key(
            'accent-purple',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        controller.accent,
        AppAccent.purple,
      );
    },
  );
}