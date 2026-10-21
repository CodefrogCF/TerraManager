import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/feedings/domain/feeding_alert_suppression.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase database;
  late int boxId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
    boxId = await BoxRepository(database)
        .createBox('TM:BOX:76767676-7676-4767-8767-767676767676');
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createAnimal({
    required String commonName,
    int? intervalDays,
    DateTime? baseline,
  }) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Species ${commonName.toLowerCase()}',
      tempMin: 20,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 70,
      feedingReminderIntervalDays: intervalDays,
      feedingReminderBaseline: baseline,
    );
  }

  Future<void> pumpOverview(
    WidgetTester tester, {
    required DateTime now,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimalsPage(database: database, reminderNow: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required int animalId,
    required DateTime now,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimalDetailPage(
          database: database,
          animalId: animalId,
          reminderNow: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final bigPicture in [false, true]) {
    testWidgets(
      'suppression changes only overview indicators, large pictures=$bigPicture',
      (tester) async {
        var now = DateTime.now();
        final first = await createAnimal(
          commonName: 'First',
          intervalDays: 1,
          baseline: now.subtract(const Duration(days: 3)),
        );
        final second = await createAnimal(
          commonName: 'Second',
          intervalDays: 1,
          baseline: now.subtract(const Duration(days: 2)),
        );
        await createAnimal(
          commonName: 'Upcoming',
          intervalDays: 7,
          baseline: now,
        );
        final before = await AnimalRepository(database).getAnimalById(first);
        final settings = AppSettingsController(now: () => now);
        addTearDown(settings.dispose);
        await settings.setBigPictureModeEnabled(bigPicture);
        await settings.setNextFeedingSummaryEnabled(true);
        await tester.pumpWidget(
          AppSettingsScope(
            controller: settings,
            child: MaterialApp(
              locale: Locale(bigPicture ? 'de' : 'en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AnimalsPage(database: database, reminderNow: () => now),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final entry = find.byKey(Key('feeding-reminder-summary-item-$first'));
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(
          find.text(bigPicture ? 'Fütterung hinzufügen' : 'Add Feeding'),
          findsOneWidget,
        );
        expect(
          find.text(
            bigPicture
                ? 'Alarm für 24 Stunden deaktivieren'
                : 'Disable Alert for 24 Hours',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('feeding-alert-suppress')));
        await tester.pumpAndSettle();
        expect(entry, findsNothing);
        expect(find.byKey(Key('animal-due-marker-$first')), findsNothing);
        expect(
          find.byKey(Key('feeding-reminder-summary-item-$second')),
          findsOneWidget,
        );
        expect(find.byKey(Key('animal-due-marker-$second')), findsOneWidget);
        expect(await AnimalRepository(database).getAnimalById(first), before);
        expect(
          await FeedingRepository(database).getFeedingsForAnimal(first),
          isEmpty,
        );

        await tester.ensureVisible(
          find.byKey(const Key('next-feeding-summary')),
        );
        await tester.tap(find.byKey(const Key('next-feeding-summary')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('feeding-schedule-animal-$first')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(Key('feeding-schedule-animal-$first')));
        await tester.pumpAndSettle();
        final banner = find.byKey(const Key('feeding-reminder-status'));
        await tester.scrollUntilVisible(banner, 300);
        await tester.pumpAndSettle();
        expect(banner, findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        expect(entry, findsNothing);

        now = now.add(const Duration(hours: 24));
        await tester.pump(const Duration(hours: 24));
        await tester.pumpAndSettle();
        expect(entry, findsOneWidget);
        expect(
          settings.isFeedingAlertSuppressed(
            feedingAlertAnimalKey(first, before!.createdAt),
          ),
          false,
        );
      },
    );
  }

  testWidgets(
    'hiding the last due alert keeps the feeding schedule accessible',
    (tester) async {
      final now = DateTime.now();
      final id = await createAnimal(
        commonName: 'Scheduled',
        intervalDays: 1,
        baseline: now.subtract(const Duration(days: 3)),
      );
      final animal = (await AnimalRepository(database).getAnimalById(id))!;
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      await settings.setNextFeedingSummaryEnabled(true);
      await settings.suppressFeedingAlertFor24Hours(
        feedingAlertAnimalKey(id, animal.createdAt),
      );
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AnimalsPage(database: database, reminderNow: () => now),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feeding-reminder-summary')), findsNothing);
      expect(find.byKey(Key('animal-due-marker-$id')), findsNothing);
      await tester.tap(find.byKey(const Key('next-feeding-summary')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('feeding-schedule-animal-$id')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.applyStoredSettings({});
    },
  );

  testWidgets('hides the reminder summary when no Animal is due', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 20, 12);

    await createAnimal(commonName: 'Disabled Reminder');
    await createAnimal(
      commonName: 'Scheduled Reminder',
      intervalDays: 7,
      baseline: DateTime(2026, 9, 19, 12),
    );

    await pumpOverview(tester, now: now);

    expect(find.byKey(const Key('feeding-reminder-summary')), findsNothing);
    expect(find.text('Disabled Reminder'), findsOneWidget);
    expect(find.text('Scheduled Reminder'), findsOneWidget);
    expect(find.text('Due'), findsNothing);
  });

  testWidgets('shows, orders and opens due reminder entries', (tester) async {
    final now = DateTime(2026, 9, 20, 12);
    final mostOverdueId = await createAnimal(
      commonName: 'Most Overdue',
      intervalDays: 7,
      baseline: DateTime(2026, 9, 1, 12),
    );
    final recentlyDueId = await createAnimal(
      commonName: 'Recently Due',
      intervalDays: 5,
      baseline: DateTime(2026, 9, 10, 12),
    );
    final scheduledId = await createAnimal(
      commonName: 'Not Due',
      intervalDays: 7,
      baseline: DateTime(2026, 9, 19, 12),
    );

    await pumpOverview(tester, now: now);

    final mostOverdueEntry = find.byKey(
      Key('feeding-reminder-summary-item-$mostOverdueId'),
    );
    final recentlyDueEntry = find.byKey(
      Key('feeding-reminder-summary-item-$recentlyDueId'),
    );

    expect(find.byKey(const Key('feeding-reminder-summary')), findsOneWidget);
    expect(find.text('2 Animals are due for feeding'), findsOneWidget);
    expect(mostOverdueEntry, findsOneWidget);
    expect(recentlyDueEntry, findsOneWidget);
    expect(
      find.byKey(Key('feeding-reminder-summary-item-$scheduledId')),
      findsNothing,
    );
    expect(
      tester.getTopLeft(mostOverdueEntry).dy,
      lessThan(tester.getTopLeft(recentlyDueEntry).dy),
    );
    expect(find.byKey(Key('animal-due-marker-$mostOverdueId')), findsOneWidget);
    expect(find.byKey(Key('animal-due-marker-$recentlyDueId')), findsOneWidget);
    expect(find.byKey(Key('animal-due-marker-$scheduledId')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(mostOverdueEntry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feeding-alert-actions')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('animal-list-item-$mostOverdueId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );

    expect(detailPage.animalId, mostOverdueId);
    expect(find.text('Most Overdue'), findsOneWidget);
  });

  testWidgets('due feeding group collapses and expands without losing count', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 20, 12);
    final animalId = await createAnimal(
      commonName: 'Due Animal',
      intervalDays: 2,
      baseline: DateTime(2026, 9, 15, 12),
    );
    await pumpOverview(tester, now: now);

    final group = find.byKey(
      const PageStorageKey<String>('feeding-reminder-summary-toggle'),
    );
    final entry = find.byKey(Key('feeding-reminder-summary-item-$animalId'));
    expect(group, findsOneWidget);
    expect(entry, findsOneWidget);

    await tester.tap(find.text('Feeding reminders'));
    await tester.pumpAndSettle();
    expect(find.text('1 Animal is due for feeding'), findsOneWidget);
    expect(entry.hitTestable(), findsNothing);

    await tester.tap(find.text('Feeding reminders'));
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);
  });

  testWidgets('omits a reminder card while feeding is not due', (tester) async {
    final animalId = await createAnimal(
      commonName: 'Scheduled Animal',
      intervalDays: 7,
      baseline: DateTime(2026, 9, 20, 12),
    );

    await pumpDetail(
      tester,
      animalId: animalId,
      now: DateTime(2026, 9, 22, 12),
    );

    final status = find.byKey(const Key('feeding-reminder-status'));

    expect(status, findsNothing);
    expect(find.text('Next feeding scheduled'), findsNothing);
  });

  testWidgets(
    'reminder Add Feeding reuses entry and refreshes overview reminders',
    (tester) async {
      final now = DateTime.now();
      final animalId = await createAnimal(
        commonName: 'Hungry Animal',
        intervalDays: 7,
        baseline: now.subtract(const Duration(days: 14)),
      );

      await pumpOverview(tester, now: now);

      expect(find.byKey(const Key('feeding-reminder-summary')), findsOneWidget);

      await tester.tap(
        find.byKey(Key('feeding-reminder-summary-item-$animalId')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feeding-alert-add-feeding')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-feeding-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feeding-dialog')), findsNothing);

      expect(
        await FeedingRepository(database).getFeedingsForAnimal(animalId),
        hasLength(1),
      );
      expect(find.byKey(const Key('feeding-reminder-summary')), findsNothing);
      expect(find.byKey(Key('animal-due-marker-$animalId')), findsNothing);
    },
  );

  testWidgets('deleting the latest feeding refreshes the due state', (
    tester,
  ) async {
    final now = DateTime.now();
    final animalId = await createAnimal(
      commonName: 'Deletion Animal',
      intervalDays: 7,
      baseline: now.subtract(const Duration(days: 14)),
    );
    final feedingId = await FeedingRepository(database)
        .addFeeding(animalId, now.subtract(const Duration(days: 1)));

    await pumpDetail(tester, animalId: animalId, now: now);

    final status = find.byKey(const Key('feeding-reminder-status'));

    expect(status, findsNothing);

    await tester.tap(find.byKey(const Key('feeding-history-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('delete-feeding-button-$feedingId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-feeding-button')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(status, 300);
    await tester.pumpAndSettle();

    expect(find.text('Feeding due'), findsOneWidget);
  });

  testWidgets('localizes due reminders in German', (tester) async {
    final now = DateTime(2026, 9, 20, 12);

    await createAnimal(
      commonName: 'Deutsches Tier',
      intervalDays: 7,
      baseline: DateTime(2026, 9, 1, 12),
    );

    await pumpOverview(tester, now: now, locale: const Locale('de'));

    expect(find.text('Fütterungserinnerungen'), findsOneWidget);
    expect(find.text('1 Tier ist zur Fütterung fällig'), findsOneWidget);
    expect(find.text('Fällig'), findsOneWidget);
  });
}
