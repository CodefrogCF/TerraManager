import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';
import 'package:terramanager/shared_client/shared_detail_navigation.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';

http.Response _ok(String key, Object value) =>
    http.Response(jsonEncode({key: value}), 200);

Widget _app(AppSettingsController settings, Widget home) => AppSettingsScope(
  controller: settings,
  child: MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'detail context keeps boundaries and rejects removed current record',
    () {
      final context = SharedDetailNavigationContext.boxes(
        recordIds: const [2, 1],
        currentRecordId: 2,
        archived: false,
        sortOrder: BoxSortOrder.nameAscending,
      );
      expect(context.previousRecordId, isNull);
      expect(context.nextRecordId, 1);
      expect(context.withRecords(const [1]), isNull);
      expect(context.withRecords(const [2, 3])?.nextRecordId, 3);
      expect(
        () => SharedDetailNavigationContext.boxes(
          recordIds: const [2, 2],
          currentRecordId: 2,
          archived: false,
          sortOrder: BoxSortOrder.nameAscending,
        ),
        throwsArgumentError,
      );
    },
  );

  testWidgets('navigation controls support keyboard and semantics', (
    tester,
  ) async {
    var nextPressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SharedDetailNavigationBar(
                contextData: SharedDetailNavigationContext.boxes(
                  recordIds: const [1, 2],
                  currentRecordId: 1,
                  archived: false,
                  sortOrder: BoxSortOrder.labelAscending,
                ),
                onPrevious: () {},
                onNext: () => nextPressed++,
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('shared-detail-next')))
          .tooltip,
      isNotEmpty,
    );
    Focus.of(tester.element(find.byIcon(Icons.chevron_right))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(nextPressed, 1);
  });

  testWidgets(
    'Box detail follows natural overview order and archive boundary',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      await settings.setBoxSortOrder(BoxSortOrder.nameAscending);
      final boxes = <Map<String, dynamic>>[
        {'id': 1, 'name': 'Box 10', 'status': 'active'},
        {'id': 2, 'name': 'Box 2', 'status': 'active'},
        {'id': 3, 'name': 'Archived', 'status': 'archived'},
      ];
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/v1/boxes') return _ok('boxes', boxes);
          if (path == '/api/v1/animals') return _ok('animals', []);
          if (path.endsWith('/pictures')) return _ok('pictures', []);
          if (path.startsWith('/api/v1/boxes/')) {
            final id = int.parse(path.split('/').last);
            return _ok('box', boxes.singleWhere((box) => box['id'] == id));
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        _app(
          settings,
          SharedBoxesPage(
            api: api,
            boxes: boxes,
            animals: const [],
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('box-list-item-2')));
      await tester.pumpAndSettle();
      expect(find.text('Box 2'), findsWidgets);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('shared-detail-previous')))
            .onPressed,
        isNull,
      );

      boxes.add({'id': 4, 'name': 'Box 3', 'status': 'active'});
      await tester.tap(find.byKey(const Key('shared-detail-next')));
      await tester.pumpAndSettle();
      expect(find.text('Box 3'), findsWidgets);
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shared-detail-next')));
      await tester.pumpAndSettle();
      expect(find.text('Box 10'), findsWidgets);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('shared-detail-next')))
            .onPressed,
        isNull,
      );

      await tester.drag(
        find.byKey(const Key('shared-detail-swipe-area')),
        const Offset(180, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Box 3'), findsWidgets);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Archived'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Animal detail follows grouped sort and ignores gallery drag', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    await settings.setAnimalSortOrder(AnimalSortOrder.displayNameDescending);
    await settings.setAnimalCategoryViewEnabled(true);
    final boxes = <Map<String, dynamic>>[
      {'id': 10, 'name': 'Terrarium', 'status': 'active'},
    ];
    final animals = <Map<String, dynamic>>[
      {
        'id': 1,
        'commonName': 'Zebra',
        'latinName': 'Species',
        'status': 'active',
        'boxId': 10,
        'category': 'reptile',
      },
      {
        'id': 2,
        'commonName': 'Ant',
        'latinName': 'Species',
        'status': 'active',
        'boxId': 10,
        'category': 'reptile',
      },
      {
        'id': 3,
        'commonName': 'Spider',
        'latinName': 'Species',
        'status': 'active',
        'boxId': 10,
        'category': 'arachnid',
      },
      {
        'id': 4,
        'commonName': 'Archived',
        'latinName': 'Species',
        'status': 'archived',
        'boxId': 10,
        'category': 'reptile',
      },
    ];
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/animals') return _ok('animals', animals);
        if (path == '/api/v1/boxes') return _ok('boxes', boxes);
        if (path.endsWith('/pictures')) return _ok('pictures', []);
        if (path.endsWith('/feedings')) return _ok('feedings', []);
        if (path.endsWith('/weights')) return _ok('weights', []);
        if (path.endsWith('/shedding')) return _ok('shedding', []);
        if (path.startsWith('/api/v1/animals/')) {
          final id = int.parse(path.split('/').last);
          return _ok(
            'animal',
            animals.singleWhere((animal) => animal['id'] == id),
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      _app(
        settings,
        SharedAnimalsPage(
          api: api,
          boxes: boxes,
          animals: animals,
          connected: true,
          change: (_) async => true,
          onReload: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('animal-list-item-1')));
    await tester.pumpAndSettle();
    expect(find.text('Zebra'), findsWidgets);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('shared-animal-gallery-1')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zebra'), findsWidgets);
    await tester.tap(find.byKey(const Key('shared-detail-next')));
    await tester.pumpAndSettle();
    expect(find.text('Ant'), findsWidgets);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Animal detail opened from a Box stays in that Box', (
    tester,
  ) async {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    final boxes = <Map<String, dynamic>>[
      {'id': 10, 'name': 'Terrarium', 'status': 'active'},
      {'id': 11, 'name': 'Other Box', 'status': 'active'},
    ];
    final animals = <Map<String, dynamic>>[
      {'id': 1, 'commonName': 'First', 'status': 'active', 'boxId': 10},
      {'id': 2, 'commonName': 'Second', 'status': 'active', 'boxId': 10},
      {'id': 3, 'commonName': 'Other', 'status': 'active', 'boxId': 11},
    ];
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/animals') return _ok('animals', animals);
        if (path == '/api/v1/boxes') return _ok('boxes', boxes);
        if (path.endsWith('/pictures')) return _ok('pictures', []);
        if (path.endsWith('/feedings')) return _ok('feedings', []);
        if (path.endsWith('/weights')) return _ok('weights', []);
        if (path.endsWith('/shedding')) return _ok('shedding', []);
        if (path.startsWith('/api/v1/animals/')) {
          final id = int.parse(path.split('/').last);
          return _ok(
            'animal',
            animals.singleWhere((animal) => animal['id'] == id),
          );
        }
        if (path == '/api/v1/boxes/10') return _ok('box', boxes.first);
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      _app(
        settings,
        SharedBoxDetailPage(
          api: api,
          id: 10,
          boxes: boxes,
          animals: animals,
          connected: true,
          change: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('assigned-animal-1')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('assigned-animal-1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('First'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('First'), findsWidgets);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shared-detail-next')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Second'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Second'), findsWidgets);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale adjacent Animal is removed from navigation', (
    tester,
  ) async {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    final animals = <Map<String, dynamic>>[
      {'id': 1, 'commonName': 'First', 'status': 'active', 'boxId': 10},
      {'id': 2, 'commonName': 'Second', 'status': 'active', 'boxId': 10},
    ];
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/animals') return _ok('animals', animals);
        if (path == '/api/v1/boxes') {
          return _ok('boxes', [
            {'id': 10, 'status': 'active'},
          ]);
        }
        if (path.endsWith('/pictures')) return _ok('pictures', []);
        if (path.endsWith('/feedings')) return _ok('feedings', []);
        if (path.endsWith('/weights')) return _ok('weights', []);
        if (path.endsWith('/shedding')) return _ok('shedding', []);
        if (path == '/api/v1/animals/2') return http.Response('{}', 404);
        if (path == '/api/v1/animals/1') return _ok('animal', animals.first);
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      _app(
        settings,
        SharedAnimalDetailPage(
          api: api,
          id: 1,
          boxes: const [
            {'id': 10, 'status': 'active'},
          ],
          connected: true,
          change: (_) async => true,
          navigationContext: SharedDetailNavigationContext.animals(
            recordIds: const [1, 2],
            currentRecordId: 1,
            archived: false,
            sortOrder: AnimalSortOrder.displayNameAscending,
            nameOrder: AnimalNameOrder.commonNameFirst,
            groupCategories: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared-detail-next')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('First'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('First'), findsWidgets);
    expect(find.text('1 / 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-detail-navigation-error')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('shared-detail-navigation-error')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote archive removes current Animal from active detail', (
    tester,
  ) async {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    var archived = false;
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        final path = request.url.path;
        final animal = {
          'id': 1,
          'commonName': 'First',
          'status': archived ? 'archived' : 'active',
          'boxId': 10,
        };
        if (path == '/api/v1/animals') return _ok('animals', [animal]);
        if (path == '/api/v1/animals/1') return _ok('animal', animal);
        if (path == '/api/v1/boxes') {
          return _ok('boxes', [
            {'id': 10, 'status': 'active'},
          ]);
        }
        if (path.endsWith('/pictures')) return _ok('pictures', []);
        if (path.endsWith('/feedings')) return _ok('feedings', []);
        if (path.endsWith('/weights')) return _ok('weights', []);
        if (path.endsWith('/shedding')) return _ok('shedding', []);
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      _app(
        settings,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SharedAnimalDetailPage(
                    api: api,
                    id: 1,
                    boxes: const [
                      {'id': 10, 'status': 'active'},
                    ],
                    connected: true,
                    change: (_) async => true,
                    navigationContext: SharedDetailNavigationContext.animals(
                      recordIds: const [1],
                      currentRecordId: 1,
                      archived: false,
                      sortOrder: AnimalSortOrder.displayNameAscending,
                      nameOrder: AnimalNameOrder.commonNameFirst,
                      groupCategories: false,
                    ),
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('First'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('First'), findsWidgets);
    archived = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Open detail'), findsOneWidget);
    expect(find.byType(SharedAnimalDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
