import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';

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
      sex: Sex.female,
      birthDate: DateTime(2024, 5, 10),
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
    expect(find.text('Sex'), findsOneWidget);
    expect(find.text('Sex.female'), findsOneWidget);
    expect(find.text('10.05.2024'), findsOneWidget);
    expect(find.text('24.0 °C – 28.0 °C'), findsOneWidget);
    expect(find.text('40.0% – 60.0%'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Test notes'), 300);

    await tester.pumpAndSettle();

    expect(find.text('Test notes'), findsOneWidget);
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
}
