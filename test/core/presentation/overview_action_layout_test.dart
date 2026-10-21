import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_boxes_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_scanner_page.dart';
import 'package:terramanager/shared_client/feedings/presentation/pages/shared_feeding_box_page.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final shared in [false, true]) {
    for (final size in [
      const Size(320, 640),
      const Size(800, 320),
      const Size(1280, 900),
    ]) {
      testWidgets(
        'floating entry points and matching archive icons: shared=$shared, size=$size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = AppDatabase.test(NativeDatabase.memory());
          addTearDown(db.close);
          final settings = AppSettingsController();
          addTearDown(settings.dispose);
          final api = SharedApiClient(
            Uri.parse('https://test.local'),
            MockClient((_) async => http.Response('{}', 404)),
          );
          addTearDown(api.close);
          Widget app(Widget page) => AppSettingsScope(
            controller: settings,
            child: MaterialApp(
              theme: ThemeData(
                platform: size.width < 1000
                    ? TargetPlatform.android
                    : TargetPlatform.windows,
              ),
              locale: const Locale('de'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: page,
            ),
          );
          for (final animals in [false, true]) {
            final page = shared
                ? animals
                      ? SharedAnimalsPage(
                          api: api,
                          boxes: const [],
                          animals: const [],
                          connected: true,
                          change: (_) async => true,
                          onReload: () async {},
                        )
                      : SharedBoxesPage(
                          api: api,
                          boxes: const [],
                          animals: const [],
                          connected: true,
                          change: (_) async => true,
                          onReload: () async {},
                        )
                : animals
                ? AnimalsPage(database: db)
                : BoxesPage(database: db);
            await tester.pumpWidget(app(page));
            await tester.pumpAndSettle();
            final primary = find.byKey(
              Key(animals ? 'add-animal-button' : 'add-box-button'),
            );
            final key = shared
                ? animals
                      ? 'shared-feeding-mode-button'
                      : 'shared-box-scan-button'
                : animals
                ? 'feeding-mode-button'
                : 'scan-box-button';
            final secondary = find.byKey(Key(key));
            final a = tester.getRect(primary);
            final b = tester.getRect(secondary);
            expect(a.width, closeTo(56, 0.01));
            expect(a.height, closeTo(56, 0.01));
            expect(b.width, closeTo(a.width, 0.01));
            expect(b.height, closeTo(a.height, 0.01));
            expect(a.left, closeTo(b.left, 0.01));
            expect(a.top - b.bottom, closeTo(12, 0.01));
            expect(b.top, greaterThanOrEqualTo(0));
            expect(
              find.descendant(of: find.byType(AppBar), matching: secondary),
              findsNothing,
            );
            expect(
              tester.widget<FloatingActionButton>(secondary).child,
              isA<Icon>().having(
                (icon) => icon.icon,
                'scanner icon',
                animals ? Icons.restaurant_menu : Icons.qr_code_scanner,
              ),
            );
            expect(
              find.byKey(
                Key(
                  shared
                      ? animals
                            ? 'shared-box-scan-button'
                            : 'shared-feeding-mode-button'
                      : animals
                      ? 'scan-box-button'
                      : 'feeding-mode-button',
                ),
              ),
              findsNothing,
            );
            final archive = find.byKey(
              Key(animals ? 'animal-history-button' : 'box-archive-button'),
            );
            expect(
              (tester.widget<IconButton>(archive).icon as Icon).icon,
              Icons.history,
            );
            await tester.tap(archive);
            await tester.pumpAndSettle();
            expect(find.byType(FloatingActionButton), findsNothing);
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
            expect(primary, findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('last Box row scrolls above both floating buttons', (
    tester,
  ) async {
    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);
    for (var i = 0; i < 20; i++) {
      await BoxRepository(db).createBoxWithGeneratedQrId(name: 'Box $i');
    }
    await tester.pumpWidget(MaterialApp(home: BoxesPage(database: db)));
    await tester.pumpAndSettle();
    final last = find.byKey(const Key('box-list-item-20'));
    await tester.scrollUntilVisible(last, 400);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(last).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('scan-box-button'))).dy,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Shared Care feeding button opens existing scanner and Box feeding workflow',
    (tester) async {
      const box = {'id': 1, 'status': 'active', 'name': 'Feeding Box'};
      final api = SharedApiClient(
        Uri.parse('https://test.local'),
        MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'user': {'username': 'carer', 'role': 'caregiver'},
                'csrfToken': 'token',
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      addTearDown(api.close);
      await api.login('carer', 'password');
      var reloads = 0;
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SharedAnimalsPage(
              api: api,
              boxes: const [box],
              animals: const [],
              connected: true,
              change: (_) async => true,
              onReload: () async {
                reloads++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shared-feeding-mode-button')));
      await tester.pumpAndSettle();
      final scanner = tester.widget<SharedBoxScannerPage>(
        find.byType(SharedBoxScannerPage),
      );
      expect(scanner.title, 'Feeding Mode');
      expect(scanner.allowBoxSelection, true);
      expect(scanner.onBoxResolved, isNotNull);
      final route = scanner.onBoxResolved!(
        tester.element(find.byType(SharedBoxScannerPage)),
        box,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SharedFeedingBoxPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop(false);
      await tester.pumpAndSettle();
      await route;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(reloads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
