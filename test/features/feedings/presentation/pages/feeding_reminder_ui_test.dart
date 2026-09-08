import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );

    expect(detailPage.animalId, mostOverdueId);
    expect(find.text('Most Overdue'), findsOneWidget);
  });

  testWidgets('shows the calculated state and opens feeding history', (
    tester,
  ) async {
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

    await tester.scrollUntilVisible(status, 300);
    await tester.pumpAndSettle();

    expect(status, findsOneWidget);
    expect(find.text('Next feeding scheduled'), findsOneWidget);
    expect(find.text('Due on 27.09.2026 12:00'), findsOneWidget);

    await tester.tap(status);
    await tester.pumpAndSettle();

    expect(find.text('Feeding History'), findsOneWidget);
    expect(find.byKey(const Key('add-feeding-button')), findsOneWidget);
  });

  testWidgets('recording a feeding refreshes detail and overview reminders', (
    tester,
  ) async {
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

    final status = find.byKey(const Key('feeding-reminder-status'));

    await tester.scrollUntilVisible(status, 300);
    await tester.pumpAndSettle();
    expect(find.text('Feeding due'), findsOneWidget);

    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-feeding-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-feeding-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeding-dialog')), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(status, 300);
    await tester.pumpAndSettle();

    expect(find.text('Next feeding scheduled'), findsOneWidget);
    expect(find.text('Feeding due'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeding-reminder-summary')), findsNothing);
    expect(find.byKey(Key('animal-due-marker-$animalId')), findsNothing);
  });

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

    await tester.scrollUntilVisible(status, 300);
    await tester.pumpAndSettle();
    expect(find.text('Next feeding scheduled'), findsOneWidget);

    await tester.tap(status);
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
