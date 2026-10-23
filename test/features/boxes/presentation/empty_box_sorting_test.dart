import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_boxes_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_detail_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/box_overview_sorting.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/boxes/presentation/box_overview.dart';

void main() {
  late AppDatabase database;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
  });
  tearDown(() async => database.close());
  Future<int> box(String name, {double? width}) => BoxRepository(database)
      .createBoxWithGeneratedQrId(
        name: name,
        widthCm: width,
        heightCm: 2,
        depthCm: 3,
      );
  Future<int> animal(int boxId) => AnimalRepository(database).createAnimal(
    boxId: boxId,
    commonName: 'Animal',
    latinName: 'Species',
    tempMin: 20,
    tempMax: 28,
    humidityMin: 40,
    humidityMax: 70,
  );

  for (final order in BoxSortOrder.values) {
    test(
      'empty-last preserves both groups with $order and filtered subsets',
      () async {
        final names = ['Box 10', 'Box 2', 'Box 1', 'Other'];
        for (var i = 0; i < names.length; i++) {
          await box(names[i], width: [10.0, 2.0, 1.0, null][i]);
        }
        final boxes = await BoxRepository(database).getActiveBoxes();
        final occupied = {boxes[1].id, boxes[3].id};
        final original = sortBoxesForOverview(boxes, order);
        final expected = [
          ...original.where((b) => occupied.contains(b.id)),
          ...original.where((b) => !occupied.contains(b.id)),
        ];
        expect(
          sortBoxesForOverview(
            boxes,
            order,
            showEmptyBoxesLast: true,
            occupiedBoxIds: occupied,
          ).map((b) => b.id),
          expected.map((b) => b.id),
        );
        final maps = [
          for (final b in boxes)
            {
              'id': b.id,
              'name': b.name,
              'widthCm': b.widthCm,
              'heightCm': b.heightCm,
              'depthCm': b.depthCm,
            },
        ];
        final sharedOriginal = sortSharedBoxesForOverview(maps, order);
        expect(
          sortBoxesForOverview(
            boxes,
            order,
            showEmptyBoxesLast: true,
            occupiedBoxIds: boxes.map((b) => b.id).toSet(),
          ).map((b) => b.id),
          original.map((b) => b.id),
        );
        expect(
          sortSharedBoxesForOverview(
            maps,
            order,
            showEmptyBoxesLast: true,
            occupiedBoxIds: occupied,
          ).map((b) => b['id']),
          [
            ...sharedOriginal.where((b) => occupied.contains(b['id'])),
            ...sharedOriginal.where((b) => !occupied.contains(b['id'])),
          ].map((b) => b['id']),
        );
        for (final enabled in [false, true]) {
          expect(
            sortBoxesForOverview(
              boxes,
              order,
              showEmptyBoxesLast: enabled,
            ).map((b) => b.id),
            original.map((b) => b.id),
          );
        }
        final filtered = boxes.where((b) => b.name!.contains('Box'));
        final result = sortBoxesForOverview(
          filtered,
          order,
          showEmptyBoxesLast: true,
          occupiedBoxIds: occupied,
        );
        expect(
          result.map((b) => b.id).toSet(),
          filtered.map((b) => b.id).toSet(),
        );
        expect(boxes.map((b) => b.id), orderedEquals([1, 2, 3, 4]));
      },
    );
  }

  testWidgets(
    'Shared Care updates occupation from snapshots and preserves detail navigation order',
    (tester) async {
      const boxes = <Map<String, dynamic>>[
        {'id': 1, 'name': 'First', 'status': 'active'},
        {'id': 2, 'name': 'Second', 'status': 'active'},
      ];
      var animals = <Map<String, dynamic>>[
        {'id': 1, 'boxId': 2, 'status': 'active', 'commonName': 'Animal'},
      ];
      final api = SharedApiClient(
        Uri.parse('https://test.local'),
        MockClient((request) async {
          final path = request.url.path;
          final Object result;
          if (path.endsWith('/boxes')) {
            result = {'boxes': boxes};
          } else if (path.endsWith('/animals')) {
            result = {'animals': animals};
          } else if (path.endsWith('/boxes/1') || path.endsWith('/boxes/2')) {
            result = {'box': boxes[path.endsWith('/1') ? 0 : 1]};
          } else {
            return http.Response('{}', 404);
          }
          return http.Response(jsonEncode(result), 200);
        }),
      );
      addTearDown(api.close);
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      await settings.setShowEmptyBoxesLast(true);
      Widget view() => AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: SharedBoxesPage(
            api: api,
            boxes: boxes,
            animals: animals,
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      double top(int id) =>
          tester.getTopLeft(find.byKey(Key('box-list-item-$id'))).dy;
      expect(top(2), lessThan(top(1)));
      final heading = find.byKey(const Key('empty-boxes-heading'));
      expect(find.text('Empty Boxes'), findsOneWidget);
      expect(tester.getTopLeft(heading).dy, greaterThan(top(2)));
      expect(tester.getBottomLeft(heading).dy, lessThanOrEqualTo(top(1)));
      animals = [
        {'id': 1, 'boxId': 1, 'status': 'active', 'commonName': 'Animal'},
      ];
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(top(1), lessThan(top(2)));
      expect(tester.getTopLeft(heading).dy, greaterThan(top(1)));
      expect(tester.getBottomLeft(heading).dy, lessThanOrEqualTo(top(2)));
      await tester.tap(find.byKey(const Key('box-list-item-1')));
      await tester.pumpAndSettle();
      final detail = tester.widget<SharedBoxDetailPage>(
        find.byType(SharedBoxDetailPage),
      );
      expect(detail.navigationContext!.recordIds, [1, 2]);
      expect(detail.navigationContext!.showEmptyBoxesLast, true);
      await tester.tap(find.byKey(const Key('shared-detail-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      animals = [];
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(top(1), lessThan(top(2)));
      expect(tester.getBottomLeft(heading).dy, lessThanOrEqualTo(top(1)));
      await settings.setShowEmptyBoxesLast(false);
      await tester.pumpAndSettle();
      expect(heading, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'empty-last defaults off and persists without changing other settings',
    () async {
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      await settings.load();
      expect(settings.showEmptyBoxesLast, false);
      await settings.setShowEmptyBoxesLast(true);
      final restored = AppSettingsController();
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.showEmptyBoxesLast, true);
      expect(restored.bigPictureModeEnabled, false);
      restored.applyStoredSettings({});
      expect(restored.showEmptyBoxesLast, false);
      await settings.setShowEmptyBoxesLast(false);
      await restored.load();
      expect(restored.showEmptyBoxesLast, false);
    },
  );

  testWidgets(
    'Standalone updates occupied groups after moves, archive and assignment',
    (tester) async {
      final first = await box('First');
      final second = await box('Second');
      final id = await animal(second);
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(home: BoxesPage(database: database)),
        ),
      );
      await tester.pumpAndSettle();
      double top(int id) =>
          tester.getTopLeft(find.byKey(Key('box-list-item-$id'))).dy;
      expect(top(first), lessThan(top(second)));
      final heading = find.byKey(const Key('empty-boxes-heading'));
      expect(heading, findsNothing);
      await settings.setShowEmptyBoxesLast(true);
      await tester.pumpAndSettle();
      expect(top(second), lessThan(top(first)));
      expect(find.text('Empty Boxes'), findsOneWidget);
      expect(tester.getTopLeft(heading).dy, greaterThan(top(second)));
      expect(tester.getBottomLeft(heading).dy, lessThanOrEqualTo(top(first)));
      await AnimalRepository(database)
          .moveAnimalToBox(animalId: id, boxId: first);
      await tester.pumpAndSettle();
      expect(top(first), lessThan(top(second)));
      expect(tester.getTopLeft(heading).dy, greaterThan(top(first)));
      await AnimalRepository(database).archiveAnimal(
        animalId: id,
        reason: AnimalArchiveReason.other,
        archivedAt: DateTime.now(),
      );
      await tester.pumpAndSettle();
      expect(top(first), lessThan(top(second)));
      expect(tester.getBottomLeft(heading).dy, lessThanOrEqualTo(top(first)));
      await animal(second);
      await tester.pumpAndSettle();
      expect(top(second), lessThan(top(first)));
      await settings.setShowEmptyBoxesLast(false);
      await tester.pumpAndSettle();
      expect(top(first), lessThan(top(second)));
      expect(heading, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final shared in [false, true]) {
    testWidgets(
      '${shared ? 'Shared Care' : 'Standalone'} grid has a full-width empty section',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final first = await box('First');
        final second = await box('Second');
        final animalId = await animal(second);
        final settings = AppSettingsController();
        addTearDown(settings.dispose);
        await settings.setShowEmptyBoxesLast(true);
        await settings.setBigPictureModeEnabled(true);
        var animals = <Map<String, dynamic>>[
          {
            'id': animalId,
            'boxId': second,
            'commonName': 'Animal',
            'status': 'active',
          },
        ];
        final api = SharedApiClient(
          Uri.parse('https://test.local'),
          MockClient((_) async => http.Response('{}', 404)),
        );
        addTearDown(api.close);
        var archived = false;
        Widget view() => AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: shared
                ? SharedBoxesPage(
                    api: api,
                    boxes: [
                      {
                        'id': first,
                        'name': 'First',
                        'status': archived ? 'archived' : 'active',
                      },
                      {
                        'id': second,
                        'name': 'Second',
                        'status': archived ? 'archived' : 'active',
                      },
                    ],
                    animals: animals,
                    archived: archived,
                    connected: true,
                    change: (_) async => true,
                    onReload: () async {},
                  )
                : BoxesPage(database: database),
          ),
        );
        await tester.pumpWidget(view());
        await tester.pumpAndSettle();
        final heading = find.byKey(const Key('empty-boxes-heading'));
        final firstTile = find.byKey(Key('box-list-item-$first'));
        final secondTile = find.byKey(Key('box-list-item-$second'));
        expect(find.text('Leere Boxen'), findsOneWidget);
        expect(tester.widget<Semantics>(heading).properties.header, true);
        final section = tester.getRect(heading);
        expect(section.width, 900);
        expect(
          section.top,
          greaterThanOrEqualTo(tester.getBottomLeft(secondTile).dy),
        );
        expect(section.bottom, lessThan(tester.getTopLeft(firstTile).dy));
        // All occupied: no empty section.
        final secondAnimalId = await animal(first);
        animals = [
          ...animals,
          {'id': secondAnimalId, 'boxId': first, 'status': 'active'},
        ];
        await tester.pumpWidget(view());
        await tester.pumpAndSettle();
        expect(heading, findsNothing);
        // All empty: one heading before the first row, with both cards on that row.
        for (final id in [animalId, secondAnimalId]) {
          await AnimalRepository(database).archiveAnimal(
            animalId: id,
            reason: AnimalArchiveReason.other,
            archivedAt: DateTime.now(),
          );
        }
        animals = [];
        await tester.pumpWidget(view());
        await tester.pumpAndSettle();
        expect(heading, findsOneWidget);
        expect(
          tester.getBottomLeft(heading).dy,
          lessThan(tester.getTopLeft(firstTile).dy),
        );
        expect(
          tester.getTopLeft(firstTile).dy,
          tester.getTopLeft(secondTile).dy,
        );
        await settings.setShowEmptyBoxesLast(false);
        await tester.pumpAndSettle();
        expect(heading, findsNothing);
        if (shared) {
          await settings.setShowEmptyBoxesLast(true);
          archived = true;
          await tester.pumpWidget(view());
          await tester.pumpAndSettle();
          expect(heading, findsNothing);
          expect(
            find.byKey(const PageStorageKey<String>('shared-boxes-archive')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
