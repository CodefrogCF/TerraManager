import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/onboarding/presentation/standalone_tutorial_gate.dart';
import 'package:terramanager/features/release_highlights/application/release_highlights_controller.dart';
import 'package:terramanager/features/release_highlights/presentation/release_highlights_dialog.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  const current = InstalledRelease(version: '1.16.0', buildNumber: '93');
  const dialogKey = Key('release-highlights-dialog');
  const closeKey = Key('release-highlights-close');
  late AppDatabase database;
  late AppSettingsController settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({'standalone_tutorial_seen': true});
    database = AppDatabase.test(NativeDatabase.memory());
    settings = AppSettingsController();
  });
  tearDown(() async {
    settings.dispose();
    await database.close();
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    InstalledReleaseLoader? loader,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StandaloneTutorialGate(
            database: database,
            releaseHighlightsController: ReleaseHighlightsController(
              loadRelease: loader ?? () async => current,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('release-highlights-settings')).hitTestable(),
      350,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'update shows once, persists before dismissal and reopens from Settings',
    (tester) async {
      await pumpGate(tester);
      expect(find.byKey(dialogKey), findsOneWidget);
      expect(find.text('Version 1.16.0 (93)'), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(ReleaseHighlightsController.lastShownReleaseKey),
        current.identity,
      );
      // Android Back is another supported way to dismiss the overlay.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await openSettings(tester);
      expect(find.text('Neuerungen'), findsOneWidget);
      await tester.tap(find.byKey(const Key('release-highlights-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(dialogKey), findsOneWidget);
      await tester.tap(find.byKey(closeKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpGate(tester);
      expect(find.byKey(dialogKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'fresh installation keeps its tour and sees the next build as an update',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpGate(tester);
      expect(
        find.byKey(const Key('standalone-tutorial-dialog')),
        findsOneWidget,
      );
      expect(find.byKey(dialogKey), findsNothing);
      await tester.tap(find.byKey(const Key('standalone-tutorial-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(dialogKey), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(ReleaseHighlightsController.lastShownReleaseKey),
        current.identity,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpGate(
        tester,
        loader: () async =>
            const InstalledRelease(version: '1.16.0', buildNumber: '94'),
      );
      expect(find.byKey(dialogKey), findsOneWidget);
      expect(find.text('Version 1.16.0 (94)'), findsOneWidget);
      await tester.tap(find.byKey(closeKey));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a legacy collection without a tutorial marker gets release highlights',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await BoxRepository(database)
          .createBox('TM:BOX:25225225-2252-4252-8252-252252252252');
      await pumpGate(tester);
      expect(find.byKey(const Key('standalone-tutorial-dialog')), findsNothing);
      expect(find.byKey(dialogKey), findsOneWidget);
      await tester.tap(find.byKey(closeKey));
      await tester.pumpAndSettle();
      expect(await BoxRepository(database).getAllBoxes(), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an open route has priority and the highlights wait until returning',
    (tester) async {
      final loaded = Completer<InstalledRelease>();
      final navigator = GlobalKey<NavigatorState>();
      await pumpGate(
        tester,
        loader: () => loaded.future,
        navigatorKey: navigator,
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Existing unsaved route')),
        ),
      );
      await tester.pumpAndSettle();
      loaded.complete(current);
      await tester.pumpAndSettle();
      expect(find.text('Existing unsaved route'), findsOneWidget);
      expect(find.byKey(dialogKey), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.containsKey(
          ReleaseHighlightsController.lastShownReleaseKey,
        ),
        false,
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(dialogKey), findsOneWidget);
      await tester.tap(find.byKey(closeKey));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed startup lookup keeps the app usable and Settings can retry once',
    (tester) async {
      var requests = 0;
      final retry = Completer<InstalledRelease>();
      await pumpGate(
        tester,
        loader: () {
          if (++requests == 1) return Future.error(StateError('not ready'));
          return retry.future;
        },
      );
      expect(find.byKey(dialogKey), findsNothing);
      await openSettings(tester);
      final entry = find.byKey(const Key('release-highlights-settings'));
      await tester.tap(entry);
      await tester.tap(entry);
      await tester.pump();
      expect(requests, 2);
      retry.complete(current);
      await tester.pumpAndSettle();
      expect(find.byKey(dialogKey), findsOneWidget);
      await tester.tap(find.byKey(closeKey));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unsupported platforms do not load releases or expose the Settings entry',
    (tester) async {
      var requests = 0;
      await pumpGate(
        tester,
        loader: () async {
          requests++;
          return current;
        },
      );
      expect(find.byKey(dialogKey), findsNothing);
      expect(requests, 0);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('release-highlights-settings')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final language in ['de', 'en']) {
    for (final size in [const Size(320, 480), const Size(800, 320)]) {
      testWidgets(
        '$language highlights scroll safely at $size and double text scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        showReleaseHighlights(context, release: current),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.byKey(dialogKey), findsOneWidget);
          expect(find.byKey(closeKey).hitTestable(), findsOneWidget);
          expect(
            find.text(language == 'de' ? 'Das ist neu' : "What's new"),
            findsOneWidget,
          );
          final rect = tester.getRect(find.byKey(dialogKey));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position;
          expect(position.maxScrollExtent, greaterThan(0));
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(
            tester
                .getBottomLeft(
                  find.byKey(const Key('release-highlights-settings-hint')),
                )
                .dy,
            lessThanOrEqualTo(
              tester.getBottomLeft(find.byType(SingleChildScrollView)).dy,
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(closeKey));
          await tester.pumpAndSettle();
          expect(find.byKey(dialogKey), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
