import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createTestAnimal() {
    final repository = AnimalRepository(database);

    return repository.createAnimal(
      boxId: 1,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      sex: Sex.other,
      birthDate: DateTime(2024, 5, 10),
      birthDateAccuracy: BirthDateAccuracy.yearKnown,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      notes: 'Test notes',
    );
  }

  testWidgets('shows animal details', (tester) async {
    // Box required because Animal.boxId references Boxes.id.
    await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-001'));

    final animalId = await createTestAnimal();

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );

    expect(detailPage.navigationContext, isNull);
    expect(find.text('Test Snake'), findsOneWidget);
    expect(find.text('Pantherophis guttatus'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sex'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Sex'), findsOneWidget);
    expect(find.text('Hermaphrodite / other'), findsOneWidget);
    expect(find.text('10.05.2024'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Year known'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Year known'), findsOneWidget);

    expect(find.text('Daytime temperature'), findsOneWidget);
    expect(find.text('Temperature'), findsNothing);
    expect(find.text('Daytime temperature (°C)'), findsNothing);
    await tester.scrollUntilVisible(find.text('24.0 °C – 28.0 °C'), 200);
    await tester.pumpAndSettle();

    expect(find.text('24.0 °C – 28.0 °C'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('40.0% – 60.0%'), 200);
    await tester.pumpAndSettle();

    expect(find.text('40.0% – 60.0%'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Test notes'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Test notes'), findsOneWidget);
  });

  testWidgets('localizes temperature labels and decimal values in details', (
    tester,
  ) async {
    await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-001'));
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: 1,
      commonName: 'Testtier',
      latinName: 'Testudo test',
      tempMin: 24,
      tempMax: 28.5,
      humidityMin: 40,
      humidityMax: 60,
      nighttimeTemperatureMin: 17,
      nighttimeTemperatureMax: 19.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );
    await tester.pumpAndSettle();

    final daytime = find.byKey(const Key('daytime-temperature-detail'));
    await tester.scrollUntilVisible(daytime, 200);
    await tester.pumpAndSettle();
    expect(find.text('Tagestemperatur'), findsOneWidget);
    expect(find.text('24,0 °C – 28,5 °C'), findsOneWidget);
    expect(find.text('Tagestemperatur (°C)'), findsNothing);

    final nighttime = find.byKey(const Key('nighttime-temperature-detail'));
    await tester.scrollUntilVisible(nighttime, 200);
    await tester.pumpAndSettle();
    expect(find.text('Nachttemperatur'), findsOneWidget);
    expect(find.text('17,0 °C – 19,5 °C'), findsOneWidget);
    expect(find.text('Nachttemperatur (°C)'), findsNothing);
  });

  testWidgets('shows legacy missing sex as Unknown', (tester) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-001'));
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Unknown Snake',
      latinName: 'Serpentes',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sex'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Sex'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('shows not found state for unknown animal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AnimalDetailPage(database: database, animalId: 999)),
    );

    await tester.pumpAndSettle();

    expect(find.text('Animal not found'), findsOneWidget);
  });

  testWidgets('shows loading indicator while loading animal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AnimalDetailPage(database: database, animalId: 999)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('edit button navigates to animal edit page', (tester) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-001'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-animal-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-animal-button')));

    await tester.pumpAndSettle();

    expect(find.text('Edit Animal'), findsOneWidget);
    expect(find.byKey(const Key('common-name-field')), findsOneWidget);
  });

  testWidgets('feeding history button navigates to feeding history page', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'feeding-history-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeding-history-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feeding-history-button')));

    await tester.pumpAndSettle();

    expect(find.text('Feeding History'), findsOneWidget);

    expect(find.byKey(const Key('add-feeding-button')), findsOneWidget);
  });

  testWidgets('shows latest shedding on animal detail', (tester) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'shedding-detail-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Shedding Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final repository = SheddingRepository(database);

    await repository.add(
      animalId: animalId,
      shedAt: DateTime(2026, 8, 10, 12),
      notes: 'Older shed',
    );

    await repository.add(
      animalId: animalId,
      shedAt: DateTime(2026, 9, 20, 18, 30),
      notes: 'Latest shed',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    final latestShedding = find.byKey(const Key('shedding-detail'));

    await tester.scrollUntilVisible(latestShedding, 300);

    await tester.pumpAndSettle();

    expect(latestShedding, findsOneWidget);

    expect(find.text('Latest shedding'), findsOneWidget);

    expect(find.text('20.09.2026 18:30'), findsOneWidget);

    expect(find.text('10.08.2026 12:00'), findsNothing);
  });

  testWidgets('adds shedding directly from animal detail', (tester) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'shedding-add-detail-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Shedding Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('shedding-add-button'));

    await tester.scrollUntilVisible(addButton, 300);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shedding-empty-detail')), findsOneWidget);

    await tester.tap(addButton);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shedding-dialog')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('shedding-notes-field')),
      'Complete shed from detail',
    );

    await tester.tap(find.byKey(const Key('save-shedding-button')));

    await tester.pumpAndSettle();

    final history = await SheddingRepository(database).getHistory(animalId);

    expect(history, hasLength(1));

    expect(history.single.notes, 'Complete shed from detail');

    expect(find.byKey(const Key('shedding-detail')), findsOneWidget);

    expect(find.byKey(const Key('shedding-empty-detail')), findsNothing);
  });

  testWidgets(
    'shedding history button opens history and refreshes detail on return',
    (tester) async {
      final boxId = await database
          .into(database.boxes)
          .insert(BoxesCompanion.insert(qrId: 'shedding-history-detail-box'));

      final animalId = await AnimalRepository(database).createAnimal(
        boxId: boxId,
        commonName: 'History Snake',
        latinName: 'Pantherophis guttatus',
        tempMin: 24,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 60,
      );

      final repository = SheddingRepository(database);

      await repository.add(
        animalId: animalId,
        shedAt: DateTime(2026, 8, 1, 10),
        notes: 'Previous shed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimalDetailPage(database: database, animalId: animalId),
        ),
      );

      await tester.pumpAndSettle();

      final historyButton = find.byKey(const Key('shedding-history-button'));

      await tester.scrollUntilVisible(historyButton, 300);

      await tester.pumpAndSettle();

      await tester.tap(historyButton);

      await tester.pumpAndSettle();

      expect(find.text('Shedding history'), findsOneWidget);

      expect(find.text('Previous shed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-shedding-button')));

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('shedding-notes-field')),
        'New latest shed',
      );

      await tester.tap(find.byKey(const Key('save-shedding-button')));

      await tester.pumpAndSettle();

      expect(find.text('New latest shed'), findsOneWidget);

      await tester.pageBack();

      await tester.pumpAndSettle();

      final latestDetail = find.byKey(const Key('shedding-detail'));

      await tester.scrollUntilVisible(latestDetail, 300);

      await tester.pumpAndSettle();

      expect(latestDetail, findsOneWidget);

      final history = await repository.getHistory(animalId);

      expect(history, hasLength(2));

      expect(history.first.notes, 'New latest shed');
    },
  );

  testWidgets('does not show legacy shedding notes on animal detail', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'legacy-shedding-detail-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Legacy Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await (database.update(
      database.animals,
    )..where((animal) => animal.id.equals(animalId))).write(
      const AnimalsCompanion(sheddingNotes: Value('Legacy shedding text')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Legacy shedding text'), findsNothing);

    expect(find.byKey(const Key('shedding-notes-detail')), findsNothing);
  });

  testWidgets('latest feeding opens the Animal feeding history', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'latest-feeding-history-box'));
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'History Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
    await FeedingRepository(database).addFeeding(
      animalId,
      DateTime(2026, 9, 10, 18, 30),
      notes: 'Detail shortcut feeding',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );
    await tester.pumpAndSettle();

    final latestFeedingAction = find.byKey(
      const Key('latest-feeding-history-action'),
    );
    await tester.scrollUntilVisible(latestFeedingAction, 300);
    await tester.pumpAndSettle();

    await tester.tap(latestFeedingAction);
    await tester.pumpAndSettle();

    expect(find.text('Feeding History'), findsOneWidget);
    expect(find.text('Detail shortcut feeding'), findsOneWidget);
  });

  testWidgets('reminder button configures and refreshes the reminder state', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'detail-reminder-box'));
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Reminder Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
    var now = DateTime(2026, 9, 12, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(
          database: database,
          animalId: animalId,
          reminderNow: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeding-reminder-button')), findsOneWidget);
    expect(find.byKey(const Key('feeding-reminder-status')), findsNothing);

    await tester.tap(find.byKey(const Key('feeding-reminder-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('feeding-reminder-settings-page')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('feeding-reminder-interval-days-field')),
      '7',
    );
    now = DateTime(2026, 9, 20, 12);
    await tester.tap(find.byKey(const Key('save-feeding-reminder-button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('feeding-reminder-status')),
      300,
    );
    await tester.pumpAndSettle();

    expect(find.text('Feeding due'), findsOneWidget);
    expect(find.text('Due since 19.09.2026 12:00'), findsOneWidget);
  });

  testWidgets('archived Animal never shows an actionable due reminder', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'archived-reminder-box'));
    final repository = AnimalRepository(database);
    final animalId = await repository.createAnimal(
      boxId: boxId,
      commonName: 'Archived Reminder Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      feedingReminderIntervalDays: 1,
      feedingReminderBaseline: DateTime(2026, 9, 1),
    );
    await repository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.rehomed,
      archivedAt: DateTime(2026, 9, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(
          database: database,
          animalId: animalId,
          reminderNow: () => DateTime(2026, 9, 20),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeding-reminder-status')), findsNothing);
  });

  testWidgets('named Box reference opens the assigned Box details', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'named-detail-box',
            name: const Value('Rainforest'),
          ),
        );
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Linked Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rainforest · Box $boxId'), findsOneWidget);
    await tester.tap(find.byKey(const Key('animal-box-detail')));
    await tester.pumpAndSettle();

    final boxPage = tester.widget<BoxDetailPage>(find.byType(BoxDetailPage));
    expect(boxPage.box.id, boxId);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Linked Snake'), findsOneWidget);
  });

  testWidgets('unnamed Box reference uses the generated Box number', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'unnamed-detail-box'));
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Linked Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Box $boxId'), findsOneWidget);
  });

  testWidgets('shows picture placeholder when animal has no picture', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'picture-test-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('animal-picture')), findsOneWidget);

    expect(find.text('No picture'), findsOneWidget);
  });

  testWidgets(
    'deleting latest feeding refreshes previous feeding on animal detail',
    (tester) async {
      final boxId = await database
          .into(database.boxes)
          .insert(BoxesCompanion.insert(qrId: 'latest-feeding-delete-box'));

      final animalId = await AnimalRepository(database).createAnimal(
        boxId: boxId,
        commonName: 'Test Snake',
        latinName: 'Pantherophis guttatus',
        tempMin: 24,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 60,
      );

      final feedingRepository = FeedingRepository(database);

      await feedingRepository.addFeeding(
        animalId,
        DateTime(2026, 8, 10, 12),
        notes: 'Previous feeding',
      );

      final latestFeedingId = await feedingRepository.addFeeding(
        animalId,
        DateTime(2026, 8, 20, 18, 30),
        notes: 'Latest feeding',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimalDetailPage(database: database, animalId: animalId),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('latest-feeding-section')),
        300,
      );

      await tester.pumpAndSettle();

      expect(find.text('20.08.2026 18:30'), findsOneWidget);

      expect(find.text('Latest feeding'), findsOneWidget);

      await tester.tap(find.byKey(const Key('feeding-history-button')));

      await tester.pumpAndSettle();

      expect(find.text('Feeding History'), findsOneWidget);

      await tester.tap(
        find.byKey(Key('delete-feeding-button-$latestFeedingId')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Delete Feeding?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-delete-feeding-button')));

      await tester.pumpAndSettle();

      expect(find.text('Latest feeding'), findsNothing);

      expect(find.text('Previous feeding'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('latest-feeding-section')),
        300,
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('latest-feeding-date')), findsOneWidget);

      expect(find.text('10.08.2026 12:00'), findsOneWidget);

      expect(find.text('Previous feeding'), findsOneWidget);

      expect(find.text('20.08.2026 18:30'), findsNothing);

      final latest = await feedingRepository.getLatestFeeding(animalId);

      expect(latest, isNotNull);
      expect(latest!.fedAt, DateTime(2026, 8, 10, 12));
      expect(latest.notes, 'Previous feeding');
    },
  );

  testWidgets('deleting last feeding refreshes empty state on animal detail', (
    tester,
  ) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'last-feeding-delete-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final feedingRepository = FeedingRepository(database);

    final feedingId = await feedingRepository.addFeeding(
      animalId,
      DateTime(2026, 8, 20, 18, 30),
      notes: 'Only feeding',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feeding-history-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('delete-feeding-button-$feedingId')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-delete-feeding-button')));

    await tester.pumpAndSettle();

    expect(find.text('No feeding events available'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('latest-feeding-empty-state')),
      300,
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('latest-feeding-empty-state')), findsOneWidget);

    expect(find.text('No feeding events available'), findsOneWidget);

    expect(await feedingRepository.getLatestFeeding(animalId), isNull);
  });

  testWidgets('restore dialog shows human readable box labels', (tester) async {
    final firstBoxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'restore-box-001'));

    final secondBoxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'restore-box-002'));

    final animalRepository = AnimalRepository(database);

    final animalId = await animalRepository.createAnimal(
      boxId: firstBoxId,
      commonName: 'Archived Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final archived = await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 3),
    );

    expect(archived, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeding-reminder-button')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('restore-animal-button')),
      300,
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restore-animal-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('restore-animal-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('restore-box-field')));

    await tester.pumpAndSettle();

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text('Box 2'), findsOneWidget);

    expect(find.text('restore-box-001'), findsNothing);

    expect(find.text('restore-box-002'), findsNothing);

    await tester.tap(find.text('Box 2').last);

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-restore-animal-button')));

    await tester.pumpAndSettle();

    final restoredAnimal = await animalRepository.getAnimalById(animalId);

    expect(restoredAnimal, isNotNull);
    expect(restoredAnimal!.boxId, secondBoxId);
  });

  testWidgets('does not show birth date after it was cleared', (tester) async {
    await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'clear-birth-date-box'));

    final repository = AnimalRepository(database);

    final animalId = await repository.createAnimal(
      boxId: 1,
      commonName: 'No Birthday Snake',
      latinName: 'Pantherophis guttatus',
      birthDate: DateTime(2024, 5, 10),
      birthDateAccuracy: BirthDateAccuracy.yearKnown,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await repository.updateAnimal(
      animalId: animalId,
      boxId: 1,
      commonName: 'No Birthday Snake',
      latinName: 'Pantherophis guttatus',
      category: AnimalCategory.other,
      subcategory: null,
      sex: Sex.unknown,
      birthDate: null,
      birthDateAccuracy: null,
      tempMin: 24,
      tempMax: 28,
      nighttimeTemperatureMin: null,
      nighttimeTemperatureMax: null,
      humidityMin: 40,
      humidityMax: 60,
      originHabitat: null,
      weight: null,
      weightGrams: null,
      sheddingNotes: null,
      restOrDormancyPeriods: null,
      pictureMediaId: null,
      picturePath: null,
      notes: null,
      feedingReminderIntervalDays: null,
      feedingReminderBaseline: null,
      showWeightOnDetail: true,
      showSheddingOnDetail: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('10.05.2024'), findsNothing);
    expect(find.text('Year known'), findsNothing);
  });

  testWidgets('hides complete Weight section when disabled', (tester) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'hidden-weight-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Hidden Weight Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      weightGrams: 42,
      showWeightOnDetail: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weight-detail')), findsNothing);
    expect(find.byKey(const Key('legacy-weight-detail')), findsNothing);
    expect(find.byKey(const Key('weight-add-button')), findsNothing);
    expect(find.byKey(const Key('weight-history-button')), findsNothing);

    final history = await AnimalWeightRepository(database).getHistory(animalId);

    expect(history, hasLength(1));
    expect(history.single.weightGrams, 42);
  });

  testWidgets('hides complete Shedding section when disabled', (tester) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'hidden-shedding-box'));

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Hidden Shedding Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      showSheddingOnDetail: false,
    );

    await SheddingRepository(database).add(
      animalId: animalId,
      shedAt: DateTime(2026, 9, 1),
      notes: 'Stored shedding event',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shedding-detail')), findsNothing);
    expect(find.byKey(const Key('shedding-empty-detail')), findsNothing);
    expect(find.byKey(const Key('shedding-add-button')), findsNothing);
    expect(find.byKey(const Key('shedding-history-button')), findsNothing);

    final history = await SheddingRepository(database).getHistory(animalId);

    expect(history, hasLength(1));
    expect(history.single.notes, 'Stored shedding event');
  });
}
