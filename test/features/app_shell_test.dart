import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/navigation/presentation/pages/app_shell.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';

void main() {
  late AppDatabase database;
  late AppSettingsController settingsController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
    settingsController = AppSettingsController();
    await settingsController.load();
  });

  tearDown(() async {
    settingsController.dispose();
    await database.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settingsController,
        child: MaterialApp(home: AppShell(database: database)),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedPage(WidgetTester tester) {
    return tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .selectedIndex;
  }

  Future<void> swipeLeft(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('primary-page-swipe-area')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('primary-page-swipe-area')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<int> createAnimalWithReminder({
    required DateTime baseline,
    int intervalDays = 1,
  }) async {
    final boxId = await BoxRepository(database)
        .createBoxWithGeneratedQrId(name: 'Reminder Box');

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Reminder Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 60,
    );

    final updated = await AnimalRepository(database).updateFeedingReminder(
      animalId: animalId,
      intervalDays: intervalDays,
      baseline: baseline,
    );

    expect(updated, isTrue);

    return animalId;
  }

  testWidgets('shows Boxes as the initial primary page', (tester) async {
    await pumpApp(tester);

    expect(find.text('Boxes'), findsWidgets);
    expect(find.text('No boxes available'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2), findsOneWidget);
    expect(find.byIcon(Icons.home), findsNothing);
    expect(selectedPage(tester), 0);
  });

  testWidgets('navigation bar taps select every primary page', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(selectedPage(tester), 2);

    await tester.tap(find.text('Animals').last);
    await tester.pumpAndSettle();
    expect(find.text('No animals available'), findsOneWidget);
    expect(selectedPage(tester), 1);

    await tester.tap(find.text('Boxes').last);
    await tester.pumpAndSettle();
    expect(find.text('No boxes available'), findsOneWidget);
    expect(selectedPage(tester), 0);
  });

  testWidgets('horizontal swipes follow the adjacent primary-page order', (
    tester,
  ) async {
    await pumpApp(tester);

    await swipeLeft(tester);
    expect(find.text('No animals available'), findsOneWidget);
    expect(selectedPage(tester), 1);

    await swipeLeft(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(selectedPage(tester), 2);

    await swipeRight(tester);
    expect(find.text('No animals available'), findsOneWidget);
    expect(selectedPage(tester), 1);

    await swipeRight(tester);
    expect(find.text('No boxes available'), findsOneWidget);
    expect(selectedPage(tester), 0);
  });

  testWidgets('swipes stop at the first and last primary pages', (
    tester,
  ) async {
    await pumpApp(tester);

    await swipeRight(tester);
    expect(selectedPage(tester), 0);

    await swipeLeft(tester);
    await swipeLeft(tester);
    await swipeLeft(tester);
    expect(selectedPage(tester), 2);
  });

  testWidgets('short and vertical drags do not change the primary page', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(
      find.byKey(const Key('primary-page-swipe-area')),
      const Offset(-30, 0),
    );
    await tester.pumpAndSettle();
    expect(selectedPage(tester), 0);

    await swipeLeft(tester);
    await swipeLeft(tester);

    final settingsScrollable = find.descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    );
    final position = tester
        .state<ScrollableState>(settingsScrollable.first)
        .position;
    final before = position.pixels;

    await tester.drag(settingsScrollable.first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(before));
    expect(selectedPage(tester), 2);
  });

  testWidgets('open Settings dropdown does not trigger page navigation', (
    tester,
  ) async {
    await pumpApp(tester);
    await swipeLeft(tester);
    await swipeLeft(tester);

    await tester.tap(find.byKey(const Key('accent-color-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Purple').last, findsOneWidget);

    await tester.drag(find.text('Purple').last, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(selectedPage(tester), 2);

    await tester.tap(find.text('Purple').last);
    await tester.pumpAndSettle();
    expect(selectedPage(tester), 2);
  });

  testWidgets('keyboard shortcuts switch adjacent primary pages', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(selectedPage(tester), 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(selectedPage(tester), 0);
  });

  testWidgets('primary navigation exposes localized semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpApp(tester);

    final pageSemantics = tester.getSemantics(
      find.byKey(const Key('primary-page-semantics')),
    );
    final navigationSemantics = tester.getSemantics(
      find.byKey(const Key('primary-navigation-semantics')),
    );

    expect(pageSemantics.label, 'Primary page');
    expect(pageSemantics.value, 'Boxes');
    expect(pageSemantics.hint, contains('Swipe horizontally'));
    expect(navigationSemantics.label, 'Primary navigation');

    await swipeLeft(tester);
    expect(
      tester
          .getSemantics(find.byKey(const Key('primary-page-semantics')))
          .value,
      'Animals',
    );
    semantics.dispose();
  });

  testWidgets('swiping away and back preserves Box sorting and scroll', (
    tester,
  ) async {
    final repository = BoxRepository(database);
    final boxIds = <int>[];

    for (var i = 1; i <= 30; i++) {
      boxIds.add(
        await repository.createBox(
          'primary-navigation-box-$i',
          name: 'Named Box ${i.toString().padLeft(2, '0')}',
        ),
      );
    }

    await settingsController.setBoxSortOrder(BoxSortOrder.nameAscending);
    await pumpApp(tester);

    final target = find.byKey(Key('box-list-item-${boxIds[19]}'));
    final boxesScrollable = find.descendant(
      of: find.byType(BoxesPage),
      matching: find.byType(Scrollable),
    );

    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: boxesScrollable.first,
    );
    await tester.pumpAndSettle();
    final positionBefore = tester.getTopLeft(target).dy;

    await swipeLeft(tester);
    await swipeRight(tester);

    expect(settingsController.boxSortOrder, BoxSortOrder.nameAscending);
    expect(target, findsOneWidget);
    expect(tester.getTopLeft(target).dy, closeTo(positionBefore, 0.1));
  });

  testWidgets(
    'root swipes do not push routes and detail swipes stay independent',
    (tester) async {
      final repository = BoxRepository(database);
      final firstId = await repository.createBox('detail-one');
      final secondId = await repository.createBox('detail-two');

      await pumpApp(tester);

      final rootContext = tester.element(
        find.byKey(const Key('primary-page-swipe-area')),
      );
      expect(Navigator.of(rootContext).canPop(), isFalse);

      await swipeLeft(tester);
      expect(Navigator.of(rootContext).canPop(), isFalse);
      await swipeRight(tester);

      await tester.tap(find.byKey(Key('box-list-item-$firstId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box-detail-title')), findsOneWidget);
      expect(find.text('Box $firstId'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('box-detail-swipe-area')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Box $secondId'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box-detail-title')), findsNothing);
      expect(selectedPage(tester), 0);
    },
  );

  testWidgets('Animal Overview refreshes after creation from Box details', (
    tester,
  ) async {
    final boxId = await BoxRepository(database).createBox('animal-refresh');
    await pumpApp(tester);

    await swipeLeft(tester);
    expect(find.text('No animals available'), findsOneWidget);
    await swipeRight(tester);

    await tester.tap(find.byKey(Key('box-list-item-$boxId')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('add-animal-to-box-button')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('box-detail-swipe-area')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('add-animal-to-box-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'Fresh Snake',
    );
    await tester.enterText(
      find.byKey(const Key('latin-name-field')),
      'Pantherophis guttatus',
    );
    await tester.enterText(find.byKey(const Key('temp-min-field')), '24');
    await tester.enterText(find.byKey(const Key('temp-max-field')), '28');
    await tester.enterText(find.byKey(const Key('humidity-min-field')), '40');
    await tester.enterText(find.byKey(const Key('humidity-max-field')), '60');
    await tester.tap(find.byKey(const Key('save-animal-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('box-detail-title')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await swipeLeft(tester);
    expect(find.text('Fresh Snake'), findsOneWidget);
    expect(find.text('No animals available'), findsNothing);
  });

  testWidgets('hides Animals navigation due badge when nothing is due', (
    tester,
  ) async {
    await pumpApp(tester);

    final badge = tester.widget<Badge>(
      find.byKey(const Key('animals-feeding-due-badge')),
    );

    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('shows Animals navigation due badge when a feeding is due', (
    tester,
  ) async {
    await createAnimalWithReminder(
      baseline: DateTime.now().subtract(const Duration(days: 2)),
      intervalDays: 1,
    );

    await pumpApp(tester);

    final badge = tester.widget<Badge>(
      find.byKey(const Key('animals-feeding-due-badge')),
    );

    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('hides Animals navigation badge when reminder is not due yet', (
    tester,
  ) async {
    await createAnimalWithReminder(baseline: DateTime.now(), intervalDays: 7);

    await pumpApp(tester);

    final badge = tester.widget<Badge>(
      find.byKey(const Key('animals-feeding-due-badge')),
    );

    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('keeps due-feeding indicator visible on other primary pages', (
    tester,
  ) async {
    await createAnimalWithReminder(
      baseline: DateTime.now().subtract(const Duration(days: 2)),
      intervalDays: 1,
    );

    await pumpApp(tester);

    expect(
      tester
          .widget<Badge>(find.byKey(const Key('animals-feeding-due-badge')))
          .isLabelVisible,
      isTrue,
    );

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(selectedPage(tester), 2);

    final badge = tester.widget<Badge>(
      find.byKey(const Key('animals-feeding-due-badge')),
    );

    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('refreshes navigation badge after reminder changes', (
    tester,
  ) async {
    final animalId = await createAnimalWithReminder(
      baseline: DateTime.now().subtract(const Duration(days: 2)),
      intervalDays: 1,
    );

    await pumpApp(tester);

    expect(
      tester
          .widget<Badge>(find.byKey(const Key('animals-feeding-due-badge')))
          .isLabelVisible,
      isTrue,
    );

    await tester.tap(find.text('Animals').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('animal-list-item-$animalId')));
    await tester.pumpAndSettle();

    // Open the existing feeding-reminder settings from Animal Details.
    await tester.tap(find.byKey(const Key('feeding-reminder-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('feeding-reminder-settings-page')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('save-feeding-reminder-form-button')),
    );
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    final badge = tester.widget<Badge>(
      find.byKey(const Key('animals-feeding-due-badge-selected')),
    );

    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('ignores animals with disabled feeding reminders', (
    tester,
  ) async {
    final animalId = await createAnimalWithReminder(
      baseline: DateTime.now().subtract(const Duration(days: 2)),
      intervalDays: 1,
    );

    final updated = await AnimalRepository(database).updateFeedingReminder(
      animalId: animalId,
      intervalDays: null,
      baseline: null,
    );

    expect(updated, isTrue);

    await pumpApp(tester);

    final badge = tester.widget<Badge>(
      find.byKey(const Key('animals-feeding-due-badge')),
    );

    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets(
    'Animal detail navigation follows latest-feeding overview order',
    (tester) async {
      final boxId = await BoxRepository(database)
          .createBoxWithGeneratedQrId(name: 'Feeding Sort Box');

      final animalRepository = AnimalRepository(database);
      final feedingRepository = FeedingRepository(database);

      final recentId = await animalRepository.createAnimal(
        boxId: boxId,
        commonName: 'Recent',
        latinName: 'Species recent',
        tempMin: 20,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 70,
      );

      final oldId = await animalRepository.createAnimal(
        boxId: boxId,
        commonName: 'Old',
        latinName: 'Species old',
        tempMin: 20,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 70,
      );

      final neverId = await animalRepository.createAnimal(
        boxId: boxId,
        commonName: 'Never',
        latinName: 'Species never',
        tempMin: 20,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 70,
      );

      await feedingRepository.addFeeding(recentId, DateTime(2026, 9, 18));

      await feedingRepository.addFeeding(oldId, DateTime(2026, 9, 1));

      await settingsController.setAnimalSortOrder(
        AnimalSortOrder.latestFeedingOldestFirst,
      );

      await pumpApp(tester);

      await tester.tap(find.text('Animals').last);
      await tester.pumpAndSettle();

      // Oldest-first order is:
      // Never fed -> Old feeding -> Recent feeding.
      final neverTile = find.byKey(Key('animal-list-item-$neverId'));
      final oldTile = find.byKey(Key('animal-list-item-$oldId'));
      final recentTile = find.byKey(Key('animal-list-item-$recentId'));

      expect(
        tester.getTopLeft(neverTile).dy,
        lessThan(tester.getTopLeft(oldTile).dy),
      );
      expect(
        tester.getTopLeft(oldTile).dy,
        lessThan(tester.getTopLeft(recentTile).dy),
      );

      // Open the middle item.
      await tester.tap(oldTile);
      await tester.pumpAndSettle();

      expect(find.text('Old'), findsWidgets);

      // Swipe right: previous item in the visible ordering is Never.
      await tester.drag(
        find.byKey(const Key('animal-detail-swipe-area')),
        const Offset(400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Never'), findsWidgets);

      // Return to Old.
      await tester.drag(
        find.byKey(const Key('animal-detail-swipe-area')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Old'), findsWidgets);

      // Swipe left: next item is Recent.
      await tester.drag(
        find.byKey(const Key('animal-detail-swipe-area')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent'), findsWidgets);
    },
  );
}
