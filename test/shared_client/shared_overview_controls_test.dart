import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_care_app.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(390, 844), const Size(1920, 1080)]) {
    testWidgets(
      'overview actions share one toolbar at $size with enlarged text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = AppSettingsController();
        final api = SharedApiClient(
          Uri.parse('https://192.168.1.117'),
          MockClient((_) async => http.Response('{}', 404)),
        );
        addTearDown(settings.dispose);
        addTearDown(api.close);
        var reloads = 0;
        Future<void> reload() async => reloads++;
        Widget app(Widget page) => AppSettingsScope(
          controller: settings,
          child: MaterialApp(
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
        void checkOrder(List<String> keys) {
          final positions = [
            for (final key in keys) tester.getCenter(find.byKey(Key(key))),
          ];
          for (var i = 1; i < positions.length; i++) {
            expect(positions[i].dx, greaterThan(positions[i - 1].dx));
            expect(positions[i].dy, positions[0].dy);
          }
          expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
          expect(
            find.byKey(const Key('shared-big-picture-toggle')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }

        await tester.pumpWidget(
          app(
            SharedBoxesPage(
              api: api,
              boxes: const [],
              animals: const [],
              connected: true,
              change: (_) async => true,
              onReload: reload,
            ),
          ),
        );
        await tester.pumpAndSettle();
        checkOrder([
          'box-sort-button',
          'box-archive-button',
          'shared-box-scan-button',
          'shared-feeding-mode-button',
          'shared-refresh',
        ]);
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('shared-feeding-mode-button')),
              )
              .icon,
          isA<Icon>().having(
            (icon) => icon.icon,
            'feeding icon',
            Icons.restaurant_menu,
          ),
        );
        await tester.tap(find.byKey(const Key('shared-refresh')));
        await tester.pumpAndSettle();
        expect(reloads, 1);
        await tester.tap(find.byKey(const Key('box-archive-button')));
        await tester.pumpAndSettle();
        checkOrder(['box-sort-button', 'shared-refresh']);
        expect(find.byKey(const Key('shared-box-scan-button')), findsNothing);
        expect(
          find.byKey(const Key('shared-feeding-mode-button')),
          findsNothing,
        );
        await tester.pumpWidget(
          app(
            SharedAnimalsPage(
              api: api,
              boxes: const [],
              animals: const [],
              connected: true,
              change: (_) async => true,
              onReload: reload,
            ),
          ),
        );
        await tester.pumpAndSettle();
        checkOrder([
          'animal-category-view-toggle',
          'animal-sort-button',
          'animal-history-button',
          'shared-refresh',
        ]);
        await tester.tap(find.byKey(const Key('animal-category-view-toggle')));
        await tester.pumpAndSettle();
        expect(settings.animalCategoryViewEnabled, isTrue);
        await tester.tap(find.byKey(const Key('animal-history-button')));
        await tester.pumpAndSettle();
        checkOrder(['animal-sort-button', 'shared-refresh']);
        expect(
          find.byKey(const Key('animal-category-view-toggle')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('shared-refresh')));
        await tester.pumpAndSettle();
        expect(reloads, 2);
      },
    );
  }

  testWidgets(
    'Settings Big Picture switch updates both overviews and archives and persists',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedApiClient client() => SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient(
          (request) async => http.Response(
            jsonEncode(switch (request.url.path) {
              '/api/v1/auth/session' => {
                'user': {'username': 'carer', 'role': 'caregiver'},
                'csrfToken': 'test-token',
                'expiresAt': '2099-01-01T00:00:00Z',
              },
              '/api/v1/boxes' => {
                'boxes': [
                  {'id': 1, 'name': 'Active Box', 'status': 'active'},
                  {'id': 2, 'name': 'Archived Box', 'status': 'archived'},
                ],
              },
              '/api/v1/animals' => {
                'animals': [
                  {
                    'id': 1,
                    'commonName': 'Active Animal',
                    'boxId': 1,
                    'status': 'active',
                  },
                  {
                    'id': 2,
                    'commonName': 'Archived Animal',
                    'boxId': 1,
                    'status': 'archived',
                  },
                ],
              },
              '/api/v1/reminders' => {'reminders': []},
              _ => {},
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(SharedCareApp(api: client()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('big-picture-mode-switch'));
      await tester.scrollUntilVisible(toggle, 200);
      final tile = tester.widget<SwitchListTile>(toggle);
      expect((tile.title as Text).data, 'Big Picture Mode');
      expect(tile.subtitle, isA<Text>());
      expect(tile.value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'big_picture_mode_enabled',
        ),
        isTrue,
      );
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box-big-picture-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('box-archive-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box-big-picture-2')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pets_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('animal-big-picture-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('animal-history-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('animal-big-picture-2')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(toggle, 200);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pets_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('animal-big-picture-1')), findsNothing);
      expect(find.byKey(const Key('animal-list-item-1')), findsOneWidget);
      // Loading a new client restores the same existing browser preference.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(SharedCareApp(api: client()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box-big-picture-1')), findsNothing);
      expect(find.byKey(const Key('box-list-item-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
