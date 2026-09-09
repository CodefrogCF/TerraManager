import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createTestBox() {
    return BoxRepository(database).createBox('test-box-001');
  }

  Future<int> createTestAnimal({
    required int boxId,
    String commonName = 'Test Snake',
    String latinName = 'Pantherophis guttatus',
    int? pictureMediaId,
  }) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: latinName,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaId: pictureMediaId,
    );
  }

  Future<int> createTestMedia() {
    return MediaRepository(database).createMedia(
      fileName: 'animal.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    AppSettingsController? settingsController,
  }) async {
    final app = MaterialApp(home: AnimalsPage(database: database));

    await tester.pumpWidget(
      settingsController == null
          ? app
          : AppSettingsScope(controller: settingsController, child: app),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no animals exist', (tester) async {
    await pumpPage(tester);

    expect(find.text('No animals available'), findsOneWidget);
  });

  testWidgets('shows animal from database', (tester) async {
    final boxId = await createTestBox();

    await createTestAnimal(boxId: boxId);

    await pumpPage(tester);

    expect(find.text('Test Snake'), findsOneWidget);

    expect(find.text('Pantherophis guttatus'), findsOneWidget);
  });

  testWidgets('updates Animal name order immediately', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final boxId = await createTestBox();
    final animalId = await createTestAnimal(boxId: boxId);
    final controller = AppSettingsController();

    await controller.load();

    await tester.pumpWidget(
      AppSettingsScope(
        controller: controller,
        child: MaterialApp(home: AnimalsPage(database: database)),
      ),
    );
    await tester.pumpAndSettle();

    ListTile animalTile() =>
        tester.widget<ListTile>(find.byKey(Key('animal-list-item-$animalId')));

    expect((animalTile().title as Text).data, 'Test Snake');
    expect((animalTile().subtitle as Text).data, 'Pantherophis guttatus');

    await controller.setAnimalNameOrder(AnimalNameOrder.latinNameFirst);
    await tester.pumpAndSettle();

    expect((animalTile().title as Text).data, 'Pantherophis guttatus');
    expect((animalTile().subtitle as Text).data, 'Test Snake');

    controller.dispose();
  });

  testWidgets('shows fallback thumbnail when animal has no picture', (
    tester,
  ) async {
    final boxId = await createTestBox();

    final animalId = await createTestAnimal(boxId: boxId);

    await pumpPage(tester);

    final thumbnail = find.byKey(Key('animal-thumbnail-$animalId'));

    expect(thumbnail, findsOneWidget);

    expect(
      find.descendant(
        of: thumbnail,
        matching: find.byIcon(Icons.emoji_nature_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows picture thumbnail when animal has media', (tester) async {
    final boxId = await createTestBox();
    final mediaId = await createTestMedia();

    final animalId = await createTestAnimal(
      boxId: boxId,
      pictureMediaId: mediaId,
    );

    await pumpPage(tester);

    final thumbnail = find.byKey(Key('animal-thumbnail-$animalId'));

    expect(thumbnail, findsOneWidget);

    expect(
      find.descendant(of: thumbnail, matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('shows multiple animals', (tester) async {
    final boxId = await createTestBox();

    await createTestAnimal(boxId: boxId, commonName: 'Snake One');

    await createTestAnimal(boxId: boxId, commonName: 'Snake Two');

    await pumpPage(tester);

    expect(find.text('Snake One'), findsOneWidget);

    expect(find.text('Snake Two'), findsOneWidget);
  });

  testWidgets('opens animal detail page', (tester) async {
    final boxId = await createTestBox();

    await createTestAnimal(boxId: boxId);

    await pumpPage(tester);

    await tester.tap(find.text('Test Snake'));

    await tester.pumpAndSettle();

    expect(find.text('Animal Details'), findsOneWidget);

    expect(find.text('Test Snake'), findsOneWidget);
  });

  testWidgets('passes active overview order to animal details', (tester) async {
    final boxId = await createTestBox();

    final firstId = await createTestAnimal(
      boxId: boxId,
      commonName: 'Animal One',
    );
    final secondId = await createTestAnimal(
      boxId: boxId,
      commonName: 'Animal Two',
    );
    final thirdId = await createTestAnimal(
      boxId: boxId,
      commonName: 'Animal Three',
    );

    await pumpPage(tester);

    await tester.tap(find.byKey(Key('animal-list-item-$secondId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );
    final navigationContext = detailPage.navigationContext!;

    expect(navigationContext.source, DetailNavigationSource.activeAnimals);
    expect(navigationContext.recordIds, [firstId, secondId, thirdId]);
    expect(navigationContext.currentRecordId, secondId);
    expect(navigationContext.currentIndex, 1);
  });

  testWidgets('changes, persists, and passes the selected Animal order', (
    tester,
  ) async {
    final boxId = await createTestBox();
    final recentId = await createTestAnimal(boxId: boxId, commonName: 'Recent');
    final oldId = await createTestAnimal(boxId: boxId, commonName: 'Old');
    final neverId = await createTestAnimal(boxId: boxId, commonName: 'Never');

    await FeedingRepository(database)
        .addFeeding(recentId, DateTime(2026, 9, 8));
    await FeedingRepository(database).addFeeding(oldId, DateTime(2026, 9, 2));

    final settingsController = AppSettingsController();

    await settingsController.load();
    await pumpPage(tester, settingsController: settingsController);

    await tester.tap(find.byKey(const Key('animal-sort-button')));
    await tester.pumpAndSettle();

    expect(find.text('Oldest added first'), findsOneWidget);
    expect(find.text('Newest added first'), findsOneWidget);
    expect(find.text('Name A–Z'), findsOneWidget);
    expect(find.text('Name Z–A'), findsOneWidget);
    expect(find.text('Oldest animals first'), findsOneWidget);
    expect(find.text('Youngest animals first'), findsOneWidget);
    expect(find.text('Newest feeding first'), findsOneWidget);
    expect(find.text('Oldest feeding first'), findsOneWidget);

    final oldestFeedingOption = find.byKey(
      const Key('animal-sort-option-latestFeedingOldestFirst'),
    );

    await tester.ensureVisible(oldestFeedingOption);
    await tester.pumpAndSettle();
    await tester.tap(oldestFeedingOption);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(Key('animal-list-item-$neverId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('animal-list-item-$oldId'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(Key('animal-list-item-$oldId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('animal-list-item-$recentId'))).dy,
      ),
    );

    expect(
      settingsController.animalSortOrder,
      AnimalSortOrder.latestFeedingOldestFirst,
    );

    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getString('animal_sort_order'),
      'latestFeedingOldestFirst',
    );

    await tester.tap(find.byKey(Key('animal-list-item-$oldId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );

    expect(detailPage.navigationContext!.recordIds, [neverId, oldId, recentId]);
  });

  testWidgets('add button opens new animal page', (tester) async {
    await createTestBox();

    await pumpPage(tester);

    expect(find.byKey(const Key('add-animal-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-animal-button')));

    await tester.pumpAndSettle();

    expect(find.text('New Animal'), findsOneWidget);

    expect(find.byKey(const Key('common-name-field')), findsOneWidget);
  });

  testWidgets('newly created animal appears in overview', (tester) async {
    await createTestBox();

    await pumpPage(tester);

    expect(find.text('No animals available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-animal-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('box-field')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Box 1').last);

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'New Snake',
    );

    await tester.enterText(
      find.byKey(const Key('latin-name-field')),
      'Pantherophis guttatus',
    );

    await tester.enterText(find.byKey(const Key('temp-min-field')), '24');

    await tester.enterText(find.byKey(const Key('temp-max-field')), '28');

    await tester.enterText(find.byKey(const Key('humidity-min-field')), '40');

    await tester.enterText(find.byKey(const Key('humidity-max-field')), '60');

    await tester.tap(find.byTooltip('Save Animal'));

    await tester.pumpAndSettle();

    expect(find.text('Animals'), findsOneWidget);

    expect(find.text('New Snake'), findsOneWidget);

    expect(find.text('Pantherophis guttatus'), findsOneWidget);

    expect(find.text('No animals available'), findsNothing);

    final animals = await AnimalRepository(database).getAllAnimals();

    expect(animals.length, 1);

    expect(animals.single.commonName, 'New Snake');
  });

  testWidgets('preserves scroll position after returning from animal detail', (
    tester,
  ) async {
    final boxId = await createTestBox();

    for (var i = 1; i <= 30; i++) {
      await createTestAnimal(
        boxId: boxId,
        commonName: 'Animal $i',
        latinName: 'Species $i',
      );
    }

    await pumpPage(tester);

    final target = find.text('Animal 20');

    await tester.scrollUntilVisible(target, 300);

    await tester.pumpAndSettle();

    final positionBefore = tester.getTopLeft(target).dy;

    await tester.tap(target);

    await tester.pumpAndSettle();

    expect(find.text('Animal Details'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Animals'), findsOneWidget);

    expect(target, findsOneWidget);

    final positionAfter = tester.getTopLeft(target).dy;

    expect(positionAfter, closeTo(positionBefore, 1.0));
  });

  testWidgets('restores scroll safely when animal list becomes shorter', (
    tester,
  ) async {
    final boxId = await createTestBox();

    for (var i = 1; i <= 30; i++) {
      await createTestAnimal(
        boxId: boxId,
        commonName: 'Animal $i',
        latinName: 'Species $i',
      );
    }

    await pumpPage(tester);

    final target = find.text('Animal 30');

    await tester.scrollUntilVisible(target, 300);

    await tester.pumpAndSettle();

    expect(target, findsOneWidget);

    final animals = await AnimalRepository(database).getActiveAnimals();

    for (final animal in animals.skip(15)) {
      await AnimalRepository(database).archiveAnimal(
        animalId: animal.id,
        reason: AnimalArchiveReason.other,
        archivedAt: DateTime(2026, 9, 3),
      );
    }

    // Rebuild the page with the shorter active list.
    await tester.pumpWidget(MaterialApp(home: AnimalsPage(database: database)));

    await tester.pumpAndSettle();

    expect(find.text('Animals'), findsOneWidget);

    expect(find.byType(ListView), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
