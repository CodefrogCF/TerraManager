import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_history_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createTestMedia() {
    return MediaRepository(database).createMedia(
      fileName: 'box.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    AppSettingsController? settingsController,
  }) async {
    final app = MaterialApp(home: BoxesPage(database: database));

    await tester.pumpWidget(
      settingsController == null
          ? app
          : AppSettingsScope(controller: settingsController, child: app),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no boxes exist', (tester) async {
    await pumpPage(tester);

    expect(find.text('No boxes available'), findsOneWidget);
  });

  testWidgets('shows human readable box label', (tester) async {
    await BoxRepository(database).createBox('test-box-001');

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text('Dimensions not specified'), findsOneWidget);

    expect(find.text('test-box-001'), findsNothing);
  });

  testWidgets('shows an optional Box name without hiding its number', (
    tester,
  ) async {
    await BoxRepository(database)
        .createBox('test-box-named', name: 'Arboreal 1');

    await pumpPage(tester);

    expect(find.text('Arboreal 1'), findsOneWidget);
    expect(find.text('Box 1'), findsOneWidget);
    expect(find.byKey(const Key('box-name-1')), findsOneWidget);
    expect(find.byKey(const Key('box-label-1')), findsOneWidget);
  });

  testWidgets('shows fallback thumbnail when box has no picture', (
    tester,
  ) async {
    final boxId = await BoxRepository(database).createBox('test-box-001');

    await pumpPage(tester);

    final thumbnail = find.byKey(Key('box-thumbnail-$boxId'));

    expect(thumbnail, findsOneWidget);

    expect(
      find.descendant(
        of: thumbnail,
        matching: find.byIcon(Icons.inventory_2_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows picture thumbnail when box has media', (tester) async {
    final mediaId = await createTestMedia();

    final boxId = await BoxRepository(database)
        .createBox('test-box-001', pictureMediaId: mediaId);

    await pumpPage(tester);

    final thumbnail = find.byKey(Key('box-thumbnail-$boxId'));

    expect(thumbnail, findsOneWidget);

    expect(
      find.descendant(of: thumbnail, matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('shows box dimensions in overview', (tester) async {
    await BoxRepository(database)
        .createBox('test-box-001', widthCm: 60, heightCm: 45, depthCm: 40);

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text('60 × 45 × 40 cm'), findsOneWidget);
  });

  testWidgets('shows multiple boxes by local box id', (tester) async {
    await BoxRepository(database).createBox('test-box-001');

    await BoxRepository(database).createBox('test-box-002');

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text('Box 2'), findsOneWidget);

    expect(find.text('test-box-001'), findsNothing);

    expect(find.text('test-box-002'), findsNothing);
  });

  testWidgets('opens box detail page', (tester) async {
    await BoxRepository(database).createBox('test-box-detail');

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('box-list-item-1')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('box-detail-title')), findsOneWidget);

    expect(find.text('Box 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const Key('box-qr-id')), 300);

    await tester.pumpAndSettle();

    expect(find.text('test-box-detail'), findsOneWidget);
  });

  testWidgets('passes box overview order to box details', (tester) async {
    final repository = BoxRepository(database);

    final firstId = await repository.createBox('test-box-1');
    final secondId = await repository.createBox('test-box-2');
    final thirdId = await repository.createBox('test-box-3');

    await pumpPage(tester);

    await tester.tap(find.byKey(Key('box-list-item-$secondId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<BoxDetailPage>(find.byType(BoxDetailPage));
    final navigationContext = detailPage.navigationContext!;

    expect(navigationContext.source, DetailNavigationSource.boxes);
    expect(navigationContext.recordIds, [firstId, secondId, thirdId]);
    expect(navigationContext.currentRecordId, secondId);
    expect(navigationContext.currentIndex, 1);
  });

  testWidgets('changes, persists, and passes the selected Box order', (
    tester,
  ) async {
    final firstId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'box-oldest',
            createdAt: drift.Value(DateTime(2026, 9, 1)),
          ),
        );
    final secondId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'box-newest',
            createdAt: drift.Value(DateTime(2026, 9, 3)),
          ),
        );
    final thirdId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'box-middle',
            createdAt: drift.Value(DateTime(2026, 9, 2)),
          ),
        );
    final settingsController = AppSettingsController();

    await settingsController.load();
    await pumpPage(tester, settingsController: settingsController);

    await tester.tap(find.byKey(const Key('box-sort-button')));
    await tester.pumpAndSettle();

    expect(find.text('Oldest created first'), findsNothing);
    expect(find.text('Newest created first'), findsNothing);
    expect(find.text('Box number: ascending'), findsOneWidget);
    expect(find.text('Box name'), findsOneWidget);
    expect(
      find.byType(CheckedPopupMenuItem<BoxSortCriterion>),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const Key('box-sort-option-labelDescending')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('box-sort-option-nameDescending')),
      findsNothing,
    );

    final descendingOption = find.byKey(const Key('box-sort-option-label'));

    await tester.ensureVisible(descendingOption);
    await tester.pumpAndSettle();
    await tester.tap(descendingOption);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(Key('box-list-item-$thirdId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('box-list-item-$secondId'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(Key('box-list-item-$secondId'))).dy,
      lessThan(tester.getTopLeft(find.byKey(Key('box-list-item-$firstId'))).dy),
    );

    expect(settingsController.boxSortOrder, BoxSortOrder.labelDescending);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('box_sort_order'), 'labelDescending');

    await tester.tap(find.byKey(Key('box-list-item-$thirdId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<BoxDetailPage>(find.byType(BoxDetailPage));

    expect(detailPage.navigationContext!.recordIds, [
      thirdId,
      secondId,
      firstId,
    ]);
  });

  testWidgets('sorts named and fallback Box labels alphabetically', (
    tester,
  ) async {
    final repository = BoxRepository(database);
    final zuluId = await repository.createBox('box-zulu', name: 'Zulu');
    final unnamedId = await repository.createBox('box-unnamed');
    final alphaId = await repository.createBox('box-alpha', name: 'Alpha');
    final settingsController = AppSettingsController();

    await settingsController.load();
    await pumpPage(tester, settingsController: settingsController);

    await tester.tap(find.byKey(const Key('box-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('box-sort-option-name')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(Key('box-list-item-$alphaId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('box-list-item-$unnamedId'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(Key('box-list-item-$zuluId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('box-list-item-$unnamedId'))).dy,
      ),
    );

    expect(settingsController.boxSortOrder, BoxSortOrder.nameAscending);

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('box_sort_order'), 'nameAscending');

    await tester.tap(find.byKey(Key('box-list-item-$zuluId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<BoxDetailPage>(find.byType(BoxDetailPage));

    expect(detailPage.navigationContext!.recordIds, [
      alphaId,
      zuluId,
      unnamedId,
    ]);
  });

  testWidgets('sorts by volume, persists it and passes visible order', (
    tester,
  ) async {
    final repository = BoxRepository(database);
    final largeId = await repository.createBox(
      'box-large',
      widthCm: 20,
      heightCm: 20,
      depthCm: 20,
    );
    final incompleteId = await repository.createBox(
      'box-incomplete',
      widthCm: 10,
      heightCm: 10,
    );
    final smallId = await repository.createBox(
      'box-small',
      widthCm: 10,
      heightCm: 10,
      depthCm: 10,
    );
    final settingsController = AppSettingsController();
    await settingsController.load();
    await pumpPage(tester, settingsController: settingsController);

    await tester.tap(find.byKey(const Key('box-sort-button')));
    await tester.pumpAndSettle();
    expect(find.text('Volume'), findsOneWidget);
    await tester.tap(find.byKey(const Key('box-sort-option-volume')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(Key('box-list-item-$smallId'))).dy,
      lessThan(tester.getTopLeft(find.byKey(Key('box-list-item-$largeId'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(Key('box-list-item-$largeId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('box-list-item-$incompleteId'))).dy,
      ),
    );
    expect(settingsController.boxSortOrder, BoxSortOrder.volumeAscending);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('box_sort_order'), 'volumeAscending');

    await tester.tap(find.byKey(Key('box-list-item-$largeId')));
    await tester.pumpAndSettle();
    final detailPage = tester.widget<BoxDetailPage>(find.byType(BoxDetailPage));
    expect(detailPage.navigationContext!.recordIds, [
      smallId,
      largeId,
      incompleteId,
    ]);
  });

  testWidgets('add button opens new box page', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('add-box-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-box-button')));

    await tester.pumpAndSettle();

    expect(find.text('New Box'), findsOneWidget);

    expect(find.byKey(const Key('create-box-button')), findsOneWidget);

    expect(find.byKey(const Key('qr-id-field')), findsNothing);
  });

  testWidgets('newly created box appears with readable label', (tester) async {
    await pumpPage(tester);

    expect(find.text('No boxes available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-box-button')));

    await tester.pumpAndSettle();

    final createButton = find.byKey(const Key('create-box-button'));

    await tester.ensureVisible(createButton);

    await tester.pumpAndSettle();

    await tester.tap(createButton);

    await tester.pumpAndSettle();

    final boxes = await BoxRepository(database).getAllBoxes();

    expect(boxes.length, 1);

    final box = boxes.single;

    expect(box.qrId, startsWith('TM:BOX:'));

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text(box.qrId), findsNothing);
  });

  testWidgets('box ids are not renumbered after deletion', (tester) async {
    final repository = BoxRepository(database);

    await repository.createBox('box-1');

    final secondId = await repository.createBox('box-2');

    await repository.createBox('box-3');

    await repository.deleteBox(secondId);

    final fourthId = await repository.createBox('box-4');

    expect(fourthId, 4);

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text('Box 2'), findsNothing);

    expect(find.text('Box 3'), findsOneWidget);

    expect(find.text('Box 4'), findsOneWidget);
  });

  testWidgets('preserves scroll position after returning from box detail', (
    tester,
  ) async {
    final repository = BoxRepository(database);

    final boxIds = <int>[];

    for (var i = 1; i <= 30; i++) {
      boxIds.add(await repository.createBox('test-box-$i'));
    }

    await pumpPage(tester);

    final targetId = boxIds[19];

    final target = find.byKey(Key('box-list-item-$targetId'));

    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(target, findsOneWidget);

    final positionBefore = tester.getTopLeft(target).dy;

    await tester.tap(target);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('box-detail-title')), findsOneWidget);

    await tester.pageBack();

    await tester.pumpAndSettle();

    expect(target, findsOneWidget);

    final positionAfter = tester.getTopLeft(target).dy;

    expect(positionAfter, closeTo(positionBefore, 1.0));
  });

  testWidgets('switches Box Overview between compact and Big Picture Mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final boxId = await BoxRepository(database)
        .createBox('big-picture-box', name: 'Display Box');

    final settingsController = AppSettingsController();

    await settingsController.load();

    await tester.pumpWidget(
      AppSettingsScope(
        controller: settingsController,
        child: MaterialApp(home: BoxesPage(database: database)),
      ),
    );

    await tester.pumpAndSettle();

    expect(settingsController.bigPictureModeEnabled, isFalse);

    expect(
      find.byKey(const PageStorageKey<String>('boxes-overview-list')),
      findsOneWidget,
    );

    expect(
      find.byKey(const PageStorageKey<String>('boxes-overview-grid')),
      findsNothing,
    );

    expect(find.byKey(Key('box-list-item-$boxId')), findsOneWidget);

    await settingsController.setBigPictureModeEnabled(true);

    await tester.pumpAndSettle();

    expect(settingsController.bigPictureModeEnabled, isTrue);

    expect(
      find.byKey(const PageStorageKey<String>('boxes-overview-list')),
      findsNothing,
    );

    expect(
      find.byKey(const PageStorageKey<String>('boxes-overview-grid')),
      findsOneWidget,
    );

    expect(find.byKey(Key('box-list-item-$boxId')), findsOneWidget);

    expect(find.byKey(Key('box-big-picture-$boxId')), findsOneWidget);

    await settingsController.setBigPictureModeEnabled(false);

    await tester.pumpAndSettle();

    expect(
      find.byKey(const PageStorageKey<String>('boxes-overview-list')),
      findsOneWidget,
    );

    expect(
      find.byKey(const PageStorageKey<String>('boxes-overview-grid')),
      findsNothing,
    );

    settingsController.dispose();
    await database.close();
  });

  testWidgets('archive button opens dedicated Box History', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('box-archive-button')));

    await tester.pumpAndSettle();

    expect(find.byType(BoxHistoryPage), findsOneWidget);

    expect(find.text('Archived Boxes'), findsOneWidget);

    expect(find.byKey(const Key('box-history-empty-state')), findsOneWidget);
  });
}
