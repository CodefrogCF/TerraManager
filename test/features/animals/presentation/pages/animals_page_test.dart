import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
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
    AnimalCategory category = AnimalCategory.other,
    AnimalSubcategory? subcategory,
    int? pictureMediaId,
    int? feedingReminderIntervalDays,
    DateTime? feedingReminderBaseline,
  }) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: latinName,
      category: category,
      subcategory: subcategory,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaId: pictureMediaId,
      feedingReminderIntervalDays: feedingReminderIntervalDays,
      feedingReminderBaseline: feedingReminderBaseline,
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
    Locale? locale,
  }) async {
    final app = MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AnimalsPage(database: database),
    );

    await tester.pumpWidget(
      settingsController == null
          ? app
          : AppSettingsScope(controller: settingsController, child: app),
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'due reminder expansion survives scrolling and overview presentation changes',
    (tester) async {
      final boxId = await createTestBox();
      final dueId = await createTestAnimal(
        boxId: boxId,
        feedingReminderIntervalDays: 1,
        feedingReminderBaseline: DateTime.now().subtract(
          const Duration(days: 3),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await createTestAnimal(boxId: boxId, commonName: 'Animal $i');
      }
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      await pumpPage(tester, settingsController: settings);
      final item = find.byKey(Key('feeding-reminder-summary-item-$dueId'));
      expect(item.hitTestable(), findsOneWidget);
      await tester.tap(find.text('Feeding reminders'));
      await tester.pumpAndSettle();
      expect(item.hitTestable(), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await settings.setBigPictureModeEnabled(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await settings.setAnimalNameOrder(AnimalNameOrder.latinNameFirst);
      await settings.setAnimalCategoryViewEnabled(true);
      await tester.pumpAndSettle();
      await settings.setBigPictureModeEnabled(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(item.hitTestable(), findsNothing);
      expect(find.text('1 Animal is due for feeding'), findsOneWidget);
      await tester.tap(find.text('Feeding reminders'));
      await tester.pumpAndSettle();
      expect(item.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

    final categoryToggle = find.byKey(const Key('animal-category-view-toggle'));
    final sortButton = find.byKey(const Key('animal-sort-button'));
    expect(categoryToggle, findsOneWidget);
    expect(
      tester.getCenter(categoryToggle).dx,
      lessThan(tester.getCenter(sortButton).dx),
    );
    expect(find.byTooltip('Show category groups'), findsOneWidget);

    await tester.tap(sortButton);
    await tester.pumpAndSettle();

    expect(find.text('Creation time: oldest first'), findsOneWidget);
    expect(find.text('Displayed name'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Latest feeding'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
    expect(
      find.byType(CheckedPopupMenuItem<AnimalSortCriterion>),
      findsNWidgets(4),
    );
    expect(
      find.byKey(const Key('animal-sort-option-latestFeedingOldestFirst')),
      findsNothing,
    );

    final latestFeedingOption = find.byKey(
      const Key('animal-sort-option-latestFeeding'),
    );

    await tester.ensureVisible(latestFeedingOption);
    await tester.pumpAndSettle();
    await tester.tap(latestFeedingOption);
    await tester.pumpAndSettle();

    expect(
      settingsController.animalSortOrder,
      AnimalSortOrder.latestFeedingOldestFirst,
    );
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

    await tester.tap(find.byKey(const Key('animal-sort-button')));
    await tester.pumpAndSettle();
    expect(find.text('Latest feeding: oldest first'), findsOneWidget);
    await tester.tap(find.byKey(const Key('animal-sort-option-latestFeeding')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(Key('animal-list-item-$recentId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('animal-list-item-$oldId'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(Key('animal-list-item-$oldId'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('animal-list-item-$neverId'))).dy,
      ),
    );

    expect(
      settingsController.animalSortOrder,
      AnimalSortOrder.latestFeedingNewestFirst,
    );

    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getString('animal_sort_order'),
      'latestFeedingNewestFirst',
    );

    await tester.tap(find.byKey(Key('animal-list-item-$oldId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );

    expect(detailPage.navigationContext!.recordIds, [recentId, oldId, neverId]);
  });

  testWidgets('groups category views and passes their flattened order', (
    tester,
  ) async {
    final boxId = await createTestBox();
    final frogId = await createTestAnimal(
      boxId: boxId,
      commonName: 'Frog',
      category: AnimalCategory.amphibian,
    );
    final snake10Id = await createTestAnimal(
      boxId: boxId,
      commonName: 'Snake 10',
      category: AnimalCategory.reptile,
      subcategory: AnimalSubcategory.snake,
    );
    final snake2Id = await createTestAnimal(
      boxId: boxId,
      commonName: 'Snake 2',
      category: AnimalCategory.reptile,
      subcategory: AnimalSubcategory.snake,
    );
    final settingsController = AppSettingsController();
    await settingsController.load();
    await settingsController.setAnimalSortOrder(
      AnimalSortOrder.displayNameAscending,
    );
    await settingsController.setAnimalCategoryViewEnabled(true);

    await pumpPage(tester, settingsController: settingsController);

    expect(
      find.byKey(const Key('animal-category-heading-amphibian')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('animal-category-heading-reptile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('animal-subcategory-heading-snake')),
      findsOneWidget,
    );
    expect(find.text('Amphibians'), findsOneWidget);
    expect(find.text('Reptiles'), findsOneWidget);
    expect(find.text('Snakes'), findsOneWidget);
    expect(find.text('Jumping spider'), findsNothing);

    await tester.tap(find.byKey(Key('animal-list-item-$snake10Id')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );
    expect(detailPage.navigationContext!.recordIds, [
      frogId,
      snake2Id,
      snake10Id,
    ]);

    settingsController.dispose();
  });

  testWidgets('uses German plural taxonomy labels in grouped view', (
    tester,
  ) async {
    final boxId = await createTestBox();
    await createTestAnimal(
      boxId: boxId,
      category: AnimalCategory.reptile,
      subcategory: AnimalSubcategory.snake,
    );
    await createTestAnimal(
      boxId: boxId,
      commonName: 'Gecko',
      category: AnimalCategory.reptile,
      subcategory: AnimalSubcategory.lizard,
    );
    final settingsController = AppSettingsController();
    await settingsController.load();
    await settingsController.setAnimalCategoryViewEnabled(true);

    await pumpPage(
      tester,
      settingsController: settingsController,
      locale: const Locale('de'),
    );

    expect(find.text('Reptilien'), findsOneWidget);
    expect(find.text('Schlangen'), findsOneWidget);
    expect(find.text('Reptil'), findsNothing);
    expect(find.text('Schlange'), findsNothing);

    settingsController.dispose();
  });

  testWidgets('toggles and persists category grouping independently', (
    tester,
  ) async {
    final boxId = await createTestBox();
    await createTestAnimal(boxId: boxId, category: AnimalCategory.reptile);
    final settingsController = AppSettingsController();
    await settingsController.load();
    await pumpPage(tester, settingsController: settingsController);

    expect(
      find.byKey(const Key('animal-category-heading-reptile')),
      findsNothing,
    );
    expect(settingsController.animalCategoryViewEnabled, isFalse);

    await tester.tap(find.byKey(const Key('animal-category-view-toggle')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('animal-category-heading-reptile')),
      findsOneWidget,
    );
    expect(settingsController.animalCategoryViewEnabled, isTrue);
    expect(find.byTooltip('Hide category groups'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('animal_category_view_enabled'), isTrue);
    expect(preferences.getString('animal_sort_order'), isNull);

    await tester.tap(find.byKey(const Key('animal-category-view-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('animal-category-heading-reptile')),
      findsNothing,
    );
    expect(preferences.getBool('animal_category_view_enabled'), isFalse);

    settingsController.dispose();
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

  testWidgets('switches Animal Overview between compact and Big Picture Mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final boxId = await BoxRepository(database)
        .createBox('animal-big-picture-box');

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final settingsController = AppSettingsController();

    await settingsController.load();

    await tester.pumpWidget(
      AppSettingsScope(
        controller: settingsController,
        child: MaterialApp(home: AnimalsPage(database: database)),
      ),
    );

    await tester.pumpAndSettle();

    expect(settingsController.bigPictureModeEnabled, isFalse);

    expect(
      find.byKey(const PageStorageKey<String>('animals-overview-list')),
      findsOneWidget,
    );

    expect(
      find.byKey(const PageStorageKey<String>('animals-overview-grid')),
      findsNothing,
    );

    expect(find.byKey(Key('animal-list-item-$animalId')), findsOneWidget);

    await settingsController.setBigPictureModeEnabled(true);

    await tester.pumpAndSettle();

    expect(settingsController.bigPictureModeEnabled, isTrue);

    expect(
      find.byKey(const PageStorageKey<String>('animals-overview-list')),
      findsNothing,
    );

    expect(
      find.byKey(const PageStorageKey<String>('animals-overview-grid')),
      findsOneWidget,
    );

    expect(find.byKey(Key('animal-list-item-$animalId')), findsOneWidget);

    expect(find.byKey(Key('animal-big-picture-$animalId')), findsOneWidget);

    await settingsController.setBigPictureModeEnabled(false);

    await tester.pumpAndSettle();

    expect(
      find.byKey(const PageStorageKey<String>('animals-overview-list')),
      findsOneWidget,
    );

    expect(
      find.byKey(const PageStorageKey<String>('animals-overview-grid')),
      findsNothing,
    );

    settingsController.dispose();
    await database.close();
  });

  testWidgets(
    'does not show next feeding summary when preference is disabled',
    (tester) async {
      final boxId = await createTestBox();

      await createTestAnimal(
        boxId: boxId,
        commonName: 'Future Snake',
        feedingReminderIntervalDays: 7,
        feedingReminderBaseline: DateTime.now().add(const Duration(days: 1)),
      );

      final settingsController = AppSettingsController();
      await settingsController.load();

      expect(settingsController.nextFeedingSummaryEnabled, isFalse);

      await pumpPage(tester, settingsController: settingsController);

      expect(find.byKey(const Key('next-feeding-summary')), findsNothing);

      settingsController.dispose();
    },
  );

  testWidgets(
    'does not show next feeding summary when no Animal has a reminder',
    (tester) async {
      final boxId = await createTestBox();

      await createTestAnimal(boxId: boxId, commonName: 'No Reminder Snake');

      final settingsController = AppSettingsController();
      await settingsController.load();
      await settingsController.setNextFeedingSummaryEnabled(true);

      await pumpPage(tester, settingsController: settingsController);

      expect(find.byKey(const Key('next-feeding-summary')), findsNothing);

      settingsController.dispose();
    },
  );

  testWidgets('shows next upcoming feeding when preference is enabled', (
    tester,
  ) async {
    final boxId = await createTestBox();

    final futureAnimalId = await createTestAnimal(
      boxId: boxId,
      commonName: 'Future Snake',
      feedingReminderIntervalDays: 5,
      feedingReminderBaseline: DateTime.now(),
    );

    final settingsController = AppSettingsController();
    await settingsController.load();
    await settingsController.setNextFeedingSummaryEnabled(true);

    await pumpPage(tester, settingsController: settingsController);

    expect(find.byKey(const Key('next-feeding-summary')), findsOneWidget);

    expect(find.byKey(const Key('next-feeding-summary-text')), findsOneWidget);

    final summaryText = tester.widget<Text>(
      find.byKey(const Key('next-feeding-summary-text')),
    );

    expect(summaryText.data, contains('Future Snake'));

    expect(find.byKey(Key('animal-list-item-$futureAnimalId')), findsOneWidget);

    settingsController.dispose();
  });

  testWidgets(
    'keeps due Animals in due UI and shows only a future Animal as next feeding',
    (tester) async {
      final boxId = await createTestBox();

      final dueAnimalId = await createTestAnimal(
        boxId: boxId,
        commonName: 'Due Snake',
        feedingReminderIntervalDays: 1,
        feedingReminderBaseline: DateTime.now().subtract(
          const Duration(days: 3),
        ),
      );

      final futureAnimalId = await createTestAnimal(
        boxId: boxId,
        commonName: 'Future Snake',
        feedingReminderIntervalDays: 7,
        feedingReminderBaseline: DateTime.now(),
      );

      final settingsController = AppSettingsController();
      await settingsController.load();
      await settingsController.setNextFeedingSummaryEnabled(true);

      await pumpPage(tester, settingsController: settingsController);

      expect(find.byKey(const Key('feeding-reminder-summary')), findsOneWidget);

      expect(
        find.byKey(Key('feeding-reminder-summary-item-$dueAnimalId')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('next-feeding-summary')), findsOneWidget);

      final nextSummary = find.byKey(const Key('next-feeding-summary'));

      expect(
        find.descendant(
          of: nextSummary,
          matching: find.textContaining('Future Snake'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: nextSummary,
          matching: find.textContaining('Due Snake'),
        ),
        findsNothing,
      );

      expect(
        find.byKey(Key('animal-list-item-$futureAnimalId')),
        findsOneWidget,
      );

      settingsController.dispose();
    },
  );

  testWidgets(
    'does not show next feeding summary when all reminder Animals are already due',
    (tester) async {
      final boxId = await createTestBox();

      final dueAnimalId = await createTestAnimal(
        boxId: boxId,
        commonName: 'Due Snake',
        feedingReminderIntervalDays: 1,
        feedingReminderBaseline: DateTime.now().subtract(
          const Duration(days: 5),
        ),
      );

      final settingsController = AppSettingsController();
      await settingsController.load();
      await settingsController.setNextFeedingSummaryEnabled(true);

      await pumpPage(tester, settingsController: settingsController);

      expect(find.byKey(const Key('feeding-reminder-summary')), findsOneWidget);

      expect(
        find.byKey(Key('feeding-reminder-summary-item-$dueAnimalId')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('next-feeding-summary')), findsNothing);

      settingsController.dispose();
    },
  );

  testWidgets('shows the Animal with the earliest future feeding', (
    tester,
  ) async {
    final boxId = await createTestBox();
    final now = DateTime.now();

    await createTestAnimal(
      boxId: boxId,
      commonName: 'Later Snake',
      feedingReminderIntervalDays: 10,
      feedingReminderBaseline: now,
    );

    await createTestAnimal(
      boxId: boxId,
      commonName: 'Sooner Snake',
      feedingReminderIntervalDays: 3,
      feedingReminderBaseline: now,
    );

    final settingsController = AppSettingsController();
    await settingsController.load();
    await settingsController.setNextFeedingSummaryEnabled(true);

    await pumpPage(tester, settingsController: settingsController);

    final summary = find.byKey(const Key('next-feeding-summary'));

    expect(summary, findsOneWidget);

    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('Sooner Snake'),
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('Later Snake'),
      ),
      findsNothing,
    );

    settingsController.dispose();
  });

  testWidgets(
    'uses Animal id as deterministic tie-break for equal future feeding times',
    (tester) async {
      final boxId = await createTestBox();

      final baseline = DateTime.now().add(const Duration(hours: 1));

      final firstAnimalId = await createTestAnimal(
        boxId: boxId,
        commonName: 'First Snake',
        feedingReminderIntervalDays: 5,
        feedingReminderBaseline: baseline,
      );

      final secondAnimalId = await createTestAnimal(
        boxId: boxId,
        commonName: 'Second Snake',
        feedingReminderIntervalDays: 5,
        feedingReminderBaseline: baseline,
      );

      expect(firstAnimalId, lessThan(secondAnimalId));

      final settingsController = AppSettingsController();
      await settingsController.load();
      await settingsController.setNextFeedingSummaryEnabled(true);

      await pumpPage(tester, settingsController: settingsController);

      final summary = find.byKey(const Key('next-feeding-summary'));

      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining('First Snake'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining('Second Snake'),
        ),
        findsNothing,
      );

      settingsController.dispose();
    },
  );

  testWidgets('tapping next feeding summary opens the relevant Animal detail', (
    tester,
  ) async {
    final boxId = await createTestBox();

    await createTestAnimal(
      boxId: boxId,
      commonName: 'Later Snake',
      feedingReminderIntervalDays: 10,
      feedingReminderBaseline: DateTime.now(),
    );

    final nextAnimalId = await createTestAnimal(
      boxId: boxId,
      commonName: 'Next Snake',
      feedingReminderIntervalDays: 2,
      feedingReminderBaseline: DateTime.now(),
    );

    final settingsController = AppSettingsController();
    await settingsController.load();
    await settingsController.setNextFeedingSummaryEnabled(true);

    await pumpPage(tester, settingsController: settingsController);

    await tester.tap(find.byKey(const Key('next-feeding-summary-tap-target')));

    await tester.pumpAndSettle();

    expect(find.byType(AnimalDetailPage), findsOneWidget);

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );

    expect(detailPage.animalId, nextAnimalId);

    expect(detailPage.navigationContext, isNotNull);

    expect(detailPage.navigationContext!.currentRecordId, nextAnimalId);

    settingsController.dispose();
  });

  testWidgets('places next feeding below due reminders and above Animal list', (
    tester,
  ) async {
    final boxId = await createTestBox();

    await createTestAnimal(
      boxId: boxId,
      commonName: 'Due Snake',
      feedingReminderIntervalDays: 1,
      feedingReminderBaseline: DateTime.now().subtract(const Duration(days: 3)),
    );

    final futureAnimalId = await createTestAnimal(
      boxId: boxId,
      commonName: 'Future Snake',
      feedingReminderIntervalDays: 5,
      feedingReminderBaseline: DateTime.now(),
    );

    final settingsController = AppSettingsController();
    await settingsController.load();
    await settingsController.setNextFeedingSummaryEnabled(true);

    await pumpPage(tester, settingsController: settingsController);

    final dueTop = tester.getTopLeft(
      find.byKey(const Key('feeding-reminder-summary')),
    );

    final nextTop = tester.getTopLeft(
      find.byKey(const Key('next-feeding-summary')),
    );

    final animalTop = tester.getTopLeft(
      find.byKey(Key('animal-list-item-$futureAnimalId')),
    );

    expect(dueTop.dy, lessThan(nextTop.dy));
    expect(nextTop.dy, lessThan(animalTop.dy));

    settingsController.dispose();
  });
}
