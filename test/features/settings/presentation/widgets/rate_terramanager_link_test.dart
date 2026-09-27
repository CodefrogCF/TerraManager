import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';
import 'package:terramanager/features/settings/presentation/widgets/rate_terramanager_link.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.codefrog.terramanager/browser');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void androidTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpLink(WidgetTester tester, Locale locale) =>
      tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: RateTerraManagerLink()),
        ),
      );

  for (final locale in ['en', 'de']) {
    androidTest(
      '$locale opens only on an explicit tap and sends no user data',
      (tester) async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => calls.add(call),
        );
        await pumpLink(tester, Locale(locale));
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        expect(
          find.text(
            locale == 'de' ? 'TerraManager bewerten' : 'Rate TerraManager',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('rate-terramanager-link')));
        await tester.pumpAndSettle();
        expect(calls.single.method, 'openStoreListing');
        expect(calls.single.arguments, isNull);
      },
    );
  }

  androidTest('disables repeated taps while opening and then recovers', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      await pending.future;
      return null;
    });
    await pumpLink(tester, const Locale('en'));
    await tester.tap(find.byKey(const Key('rate-terramanager-link')));
    await tester.pump();
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('rate-terramanager-link')))
          .onTap,
      isNull,
    );
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('rate-terramanager-link')))
          .onTap,
      isNotNull,
    );
  });

  for (final missingPlugin in [false, true]) {
    androidTest(
      'shows a localized failure for ${missingPlugin ? 'missing plugin' : 'no external handler'}',
      (tester) async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (missingPlugin) throw MissingPluginException();
          throw PlatformException(code: 'no_store_or_browser');
        });
        await pumpLink(tester, const Locale('de'));
        await tester.tap(find.byKey(const Key('rate-terramanager-link')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Die Play-Store-Seite konnte nicht geöffnet werden. Bitte versuche es später erneut.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ListTile>(find.byKey(const Key('rate-terramanager-link')))
              .onTap,
          isNotNull,
        );
      },
    );
  }

  androidTest('does not offer an Android store link on other platforms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpLink(tester, const Locale('en'));
    expect(find.byKey(const Key('rate-terramanager-link')), findsNothing);
  });

  androidTest(
    'standalone Settings includes the action without opening it on entry',
    (tester) async {
      final database = AppDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      final controller = AppSettingsController();
      await controller.load();
      addTearDown(controller.dispose);
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async => calls++);
      await tester.pumpWidget(
        AppSettingsScope(
          controller: controller,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(database: database),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('rate-terramanager-link')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(calls, 0);
      await tester.tap(find.byKey(const Key('rate-terramanager-link')));
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
}
