import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_care_app.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Big Picture keeps Box sorting, archive separation and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
    final boxes = [
      {'id': 1, 'name': 'Box 10', 'status': 'active'},
      {
        'id': 2,
        'name': 'Box 2',
        'status': 'active',
        'widthCm': 10,
        'heightCm': 10,
        'depthCm': 10,
      },
      {'id': 3, 'name': 'Archived', 'status': 'archived'},
    ];
    await settings.setBoxSortOrder(BoxSortOrder.nameAscending);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedBoxesPage(
            api: api,
            boxes: boxes,
            animals: const [],
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared-big-picture-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('box-big-picture-1')), findsOneWidget);
    expect(find.byKey(const Key('box-big-picture-2')), findsOneWidget);
    expect(find.byKey(const Key('box-big-picture-3')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('box-list-item-2'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('box-list-item-1'))).dy),
    );
    expect(find.byKey(const Key('box-context-menu-button-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('box-archive-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('box-big-picture-3')), findsOneWidget);
    expect(find.byKey(const Key('box-big-picture-1')), findsNothing);
    await tester.tap(find.byKey(const Key('shared-big-picture-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('box-big-picture-3')), findsNothing);
    expect(find.byKey(const Key('box-list-item-3')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settings.setBoxSortOrder(BoxSortOrder.volumeDescending);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('box-list-item-2'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('box-list-item-1'))).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Big Picture groups Animals and latest Feeding sort refreshes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
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
    await settings.setBigPictureModeEnabled(true);
    await settings.setAnimalSortOrder(AnimalSortOrder.latestFeedingNewestFirst);
    await settings.setAnimalCategoryViewEnabled(true);
    final animals = [
      {
        'id': 1,
        'commonName': 'First',
        'latinName': 'Species',
        'status': 'active',
        'boxId': 10,
        'category': 'reptile',
        'latestFeedingAt': '2026-09-20T10:00:00Z',
      },
      {
        'id': 2,
        'commonName': 'Second',
        'latinName': 'Species',
        'status': 'active',
        'boxId': 10,
        'category': 'reptile',
        'latestFeedingAt': '2026-09-24T10:00:00Z',
      },
    ];
    Widget page() => AppSettingsScope(
      controller: settings,
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SharedAnimalsPage(
          api: api,
          boxes: const [
            {'id': 10, 'name': 'Terrarium', 'status': 'active'},
          ],
          animals: animals,
          connected: true,
          change: (_) async => true,
          onReload: () async {},
        ),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('animal-big-picture-1')), findsOneWidget);
    expect(find.byKey(const Key('animal-big-picture-2')), findsOneWidget);
    expect(find.text('Reptiles'), findsOneWidget);
    expect(
      find.byKey(const Key('animal-context-menu-button-2')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('animal-list-item-2'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('animal-list-item-1'))).dx,
      ),
    );
    animals[0]['latestFeedingAt'] = '2026-09-25T10:00:00Z';
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('animal-list-item-1'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('animal-list-item-2'))).dx,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('latest Feeding ordering places never-fed Animals consistently', () {
    final animals = [
      {'id': 1, 'commonName': 'Never', 'latinName': 'Species'},
      {
        'id': 2,
        'commonName': 'Older',
        'latinName': 'Species',
        'latestFeedingAt': '2026-09-20T10:00:00Z',
      },
      {
        'id': 3,
        'commonName': 'Newer',
        'latinName': 'Species',
        'latestFeedingAt': '2026-09-24T10:00:00Z',
      },
    ];
    expect(
      sortSharedAnimalsForOverview(
        animals,
        order: AnimalSortOrder.latestFeedingOldestFirst,
        nameOrder: AnimalNameOrder.commonNameFirst,
      ).map((animal) => animal['id']),
      [1, 2, 3],
    );
    expect(
      sortSharedAnimalsForOverview(
        animals,
        order: AnimalSortOrder.latestFeedingNewestFirst,
        nameOrder: AnimalNameOrder.commonNameFirst,
      ).map((animal) => animal['id']),
      [3, 2, 1],
    );
  });

  testWidgets('Box detail shows assigned Animal thumbnail and name order', (
    tester,
  ) async {
    final settings = AppSettingsController();
    await settings.setAnimalNameOrder(AnimalNameOrder.latinNameFirst);
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        if (request.url.path == '/api/v1/boxes/1') {
          return http.Response(
            jsonEncode({
              'box': {'id': 1, 'name': 'Terrarium', 'status': 'active'},
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/boxes/1/pictures') {
          return http.Response(jsonEncode({'pictures': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedBoxDetailPage(
            api: api,
            id: 1,
            boxes: const [],
            animals: const [
              {
                'id': 5,
                'boxId': 1,
                'latinName': 'Aphonopelma seemanni',
                'commonName': 'Zebra',
              },
            ],
            connected: true,
            change: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('assigned-animal-thumbnail-5')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('assigned-animal-thumbnail-5')),
      findsOneWidget,
    );
    expect(find.text('Aphonopelma seemanni'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Animal detail localizes one-decimal day and night ranges', (
    tester,
  ) async {
    final settings = AppSettingsController();
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        if (request.url.path == '/api/v1/animals/5') {
          return http.Response(
            jsonEncode({
              'animal': {
                'id': 5,
                'commonName': 'Zebra',
                'latinName': 'Aphonopelma seemanni',
                'status': 'active',
                'boxId': 1,
                'tempMin': 24,
                'tempMax': 27.5,
                'nighttimeTemperatureMin': 19,
                'nighttimeTemperatureMax': 21.5,
                'birthDate': '2020-01-01T00:00:00Z',
                'birthDateAccuracy': 'exact',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/animals/5/feedings') {
          return http.Response(jsonEncode({'feedings': []}), 200);
        }
        if (request.url.path == '/api/v1/animals/5/pictures') {
          return http.Response(jsonEncode({'pictures': []}), 200);
        }
        if (request.url.path == '/api/v1/animals/5/weights') {
          return http.Response(
            jsonEncode({
              'weights': [
                {'weightGrams': 42.25, 'measuredAt': '2026-09-24T10:00:00Z'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/animals/5/shedding') {
          return http.Response(
            jsonEncode({
              'shedding': [
                {'shedAt': '2026-09-23T10:00:00Z'},
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedAnimalDetailPage(
            api: api,
            id: 5,
            boxes: const [
              {'id': 1, 'name': 'Terrarium', 'status': 'active'},
            ],
            connected: true,
            change: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('daytime-temperature-detail')),
      250,
    );
    expect(find.textContaining('24,0'), findsOneWidget);
    expect(find.textContaining('27,5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('nighttime-temperature-detail')),
      200,
    );
    expect(find.textContaining('19,0'), findsOneWidget);
    expect(find.textContaining('21,5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-weight-detail')),
      200,
    );
    expect(find.textContaining('42,25'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-shedding-detail')),
      200,
    );
    expect(find.byKey(const Key('shared-shedding-detail')), findsOneWidget);
    expect(
      find.textContaining('Terrarium · Box 1', skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared Box overview sorts naturally and renames through API', (
    tester,
  ) async {
    final boxes = <Map<String, dynamic>>[
      {
        'id': 1,
        'name': 'Terrarium 10',
        'status': 'active',
        'revision': 'rev-1',
      },
      {'id': 2, 'name': 'Terrarium 2', 'status': 'active', 'revision': 'rev-1'},
    ];
    var writes = 0;
    var archives = 0;
    final backend = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/auth/session':
          return http.Response(jsonEncode(_session), 200);
        case '/api/v1/boxes':
          return http.Response(jsonEncode({'boxes': boxes}), 200);
        case '/api/v1/animals':
          return http.Response(jsonEncode({'animals': []}), 200);
        case '/api/v1/reminders':
          return http.Response(jsonEncode({'reminders': []}), 200);
        case '/api/v1/boxes/1':
          if (request.method == 'PATCH') {
            writes++;
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            expect(payload, {'name': 'Renamed', 'expectedRevision': 'rev-1'});
            boxes[0] = {
              ...boxes[0],
              'name': payload['name'],
              'revision': 'rev-2',
            };
            return http.Response(jsonEncode({'box': boxes[0]}), 200);
          }
        case '/api/v1/boxes/1/archive':
          archives++;
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['reason'], 'sold');
          boxes[0] = {...boxes[0], 'status': 'archived'};
          return http.Response(jsonEncode({'box': boxes[0]}), 200);
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      SharedCareApp(
        api: SharedApiClient(Uri.parse('https://192.168.1.117'), backend),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('box-sort-button')), findsOneWidget);
    expect(find.byKey(const Key('add-box-button')), findsOneWidget);
    expect(find.byKey(const Key('shared-box-scan-button')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('shared-box-scan-button')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('box-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('box-sort-option-name')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Terrarium 2')).dy,
      lessThan(tester.getTopLeft(find.text('Terrarium 10')).dy),
    );

    await tester.longPress(find.byKey(const Key('box-list-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename Box'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Renamed'), findsOneWidget);

    await tester.longPress(find.byKey(const Key('box-list-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive Box'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(archives, 1);
    expect(find.text('Renamed'), findsNothing);
    await tester.tap(find.byKey(const Key('box-archive-button')));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    expect(find.byKey(const Key('shared-box-scan-button')), findsNothing);
  });
}

const _session = {
  'user': {'username': 'hagen', 'role': 'administrator'},
  'csrfToken': 'csrf-secret',
  'expiresAt': '2026-09-24T08:00:00Z',
};
