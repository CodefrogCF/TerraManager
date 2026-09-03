import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';

import 'package:terramanager/features/feedings/presentation/pages/feeding_history_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createTestAnimal() async {
    final boxId = await BoxRepository(database).createBox('test-box-001');

    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  Future<void> pumpPage(WidgetTester tester, {required int animalId}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeedingHistoryPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no feeding events exist', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    expect(find.text('No feeding events available'), findsOneWidget);
  });

  testWidgets('shows existing feeding events', (tester) async {
    final animalId = await createTestAnimal();

    await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 8, 20, 18, 30), notes: 'Mouse');

    await pumpPage(tester, animalId: animalId);

    expect(find.text('20.08.2026 18:30'), findsOneWidget);

    expect(find.text('Mouse'), findsOneWidget);
  });

  testWidgets('shows feedings newest first', (tester) async {
    final animalId = await createTestAnimal();

    await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 8, 10, 12), notes: 'Older');

    await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 8, 20, 12), notes: 'Newer');

    await pumpPage(tester, animalId: animalId);

    final newer = tester.getTopLeft(find.text('Newer'));

    final older = tester.getTopLeft(find.text('Older'));

    expect(newer.dy, lessThan(older.dy));
  });

  testWidgets('add button opens feeding dialog', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('add-feeding-button')));

    await tester.pumpAndSettle();

    expect(find.text('Add Feeding'), findsOneWidget);

    expect(find.byKey(const Key('feeding-notes-field')), findsOneWidget);

    expect(find.byKey(const Key('save-feeding-button')), findsOneWidget);
  });

  testWidgets('creates feeding event', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('add-feeding-button')));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('feeding-notes-field')),
      'Test feeding',
    );

    await tester.tap(find.byKey(const Key('save-feeding-button')));

    await tester.pumpAndSettle();

    final feedings = await FeedingRepository(database)
        .getFeedingsForAnimal(animalId);

    expect(feedings.length, 1);

    expect(feedings.single.notes, 'Test feeding');

    expect(find.text('Test feeding'), findsOneWidget);
  });

  testWidgets('can create feeding without notes', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('add-feeding-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-feeding-button')));

    await tester.pumpAndSettle();

    final feedings = await FeedingRepository(database)
        .getFeedingsForAnimal(animalId);

    expect(feedings.length, 1);

    expect(feedings.single.notes, isNull);
  });

  testWidgets('cancel does not create feeding', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('add-feeding-button')));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('feeding-notes-field')),
      'Should not save',
    );

    await tester.tap(find.text('Cancel'));

    await tester.pumpAndSettle();

    final feedings = await FeedingRepository(database)
        .getFeedingsForAnimal(animalId);

    expect(feedings, isEmpty);

    expect(find.text('Add Feeding'), findsNothing);
  });

  testWidgets('opens edit dialog with existing feeding data', (tester) async {
    final animalId = await createTestAnimal();

    final feedingId = await FeedingRepository(database).addFeeding(
      animalId,
      DateTime(2026, 8, 20, 18, 30),
      notes: 'Original note',
    );

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(Key('feeding-item-$feedingId')));

    await tester.pumpAndSettle();

    expect(find.text('Edit Feeding'), findsOneWidget);

    expect(find.byKey(const Key('feeding-dialog')), findsOneWidget);

    expect(find.text('20.08.2026 18:30'), findsWidgets);

    final notesField = tester.widget<TextField>(
      find.byKey(const Key('feeding-notes-field')),
    );

    expect(notesField.controller!.text, 'Original note');
  });

  testWidgets('edits feeding notes', (tester) async {
    final animalId = await createTestAnimal();

    final feedingId = await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 8, 20, 18, 30), notes: 'Old note');

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(Key('feeding-item-$feedingId')));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('feeding-notes-field')),
      'Updated note',
    );

    await tester.tap(find.byKey(const Key('save-feeding-button')));

    await tester.pumpAndSettle();

    final feeding = await FeedingRepository(database).getFeedingById(feedingId);

    expect(feeding, isNotNull);
    expect(feeding!.notes, 'Updated note');

    expect(find.text('Updated note'), findsOneWidget);

    expect(find.text('Old note'), findsNothing);
  });

  testWidgets('can clear feeding notes while editing', (tester) async {
    final animalId = await createTestAnimal();

    final feedingId = await FeedingRepository(
      database,
    ).addFeeding(animalId, DateTime(2026, 8, 20, 18, 30), notes: 'Remove me');

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(Key('feeding-item-$feedingId')));

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('feeding-notes-field')), '');

    await tester.tap(find.byKey(const Key('save-feeding-button')));

    await tester.pumpAndSettle();

    final feeding = await FeedingRepository(database).getFeedingById(feedingId);

    expect(feeding, isNotNull);
    expect(feeding!.notes, isNull);

    expect(find.text('Remove me'), findsNothing);
  });

  testWidgets('cancel edit leaves feeding unchanged', (tester) async {
    final animalId = await createTestAnimal();

    final feedingId = await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 8, 20, 18, 30), notes: 'Original');

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(Key('feeding-item-$feedingId')));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('feeding-notes-field')),
      'Should not save',
    );

    await tester.tap(find.byKey(const Key('cancel-feeding-button')));

    await tester.pumpAndSettle();

    final feeding = await FeedingRepository(database).getFeedingById(feedingId);

    expect(feeding, isNotNull);
    expect(feeding!.notes, 'Original');

    expect(find.text('Edit Feeding'), findsNothing);
  });

  testWidgets('delete button opens confirmation dialog', (tester) async {
    final animalId = await createTestAnimal();

    final feedingId = await FeedingRepository(database).addFeeding(
      animalId,
      DateTime(2026, 8, 20, 18, 30),
      notes: 'Mouse',
    );

    await pumpPage(tester, animalId: animalId);

    await tester.tap(
      find.byKey(
        Key('delete-feeding-button-$feedingId'),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('delete-feeding-dialog')),
      findsOneWidget,
    );

    expect(
      find.text('Delete Feeding?'),
      findsOneWidget,
    );

    expect(
      find.byKey(
        const Key('cancel-delete-feeding-button'),
      ),
      findsOneWidget,
    );

    expect(
      find.byKey(
        const Key('confirm-delete-feeding-button'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancel delete keeps feeding', (tester) async {
    final animalId = await createTestAnimal();

    final feedingId = await FeedingRepository(database).addFeeding(
      animalId,
      DateTime(2026, 8, 20, 18, 30),
      notes: 'Keep me',
    );

    await pumpPage(tester, animalId: animalId);

    await tester.tap(
      find.byKey(
        Key('delete-feeding-button-$feedingId'),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const Key('cancel-delete-feeding-button'),
      ),
    );

    await tester.pumpAndSettle();

    final feeding = await FeedingRepository(database)
        .getFeedingById(feedingId);

    expect(feeding, isNotNull);

    expect(
      find.text('Keep me'),
      findsOneWidget,
    );

    expect(
      find.text('Delete Feeding?'),
      findsNothing,
    );
  });

  testWidgets('deletes selected feeding', (tester) async {
    final animalId = await createTestAnimal();

    final firstId = await FeedingRepository(database).addFeeding(
      animalId,
      DateTime(2026, 8, 10, 12),
      notes: 'Keep',
    );

    final secondId = await FeedingRepository(database).addFeeding(
      animalId,
      DateTime(2026, 8, 20, 18, 30),
      notes: 'Delete me',
    );

    await pumpPage(tester, animalId: animalId);

    await tester.tap(
      find.byKey(
        Key('delete-feeding-button-$secondId'),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const Key('confirm-delete-feeding-button'),
      ),
    );

    await tester.pumpAndSettle();

    final repository = FeedingRepository(database);

    expect(
      await repository.getFeedingById(secondId),
      isNull,
    );

    expect(
      await repository.getFeedingById(firstId),
      isNotNull,
    );

    expect(
      find.text('Delete me'),
      findsNothing,
    );

    expect(
      find.text('Keep'),
      findsOneWidget,
    );
  });

  testWidgets(
    'deleting last feeding shows empty state',
    (tester) async {
      final animalId = await createTestAnimal();

      final feedingId =
          await FeedingRepository(database).addFeeding(
        animalId,
        DateTime(2026, 8, 20, 18, 30),
        notes: 'Only feeding',
      );

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(
          Key('delete-feeding-button-$feedingId'),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key(
            'confirm-delete-feeding-button',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No feeding events available'),
        findsOneWidget,
      );

      expect(
        find.text('Only feeding'),
        findsNothing,
      );

      final feedings =
          await FeedingRepository(database)
              .getFeedingsForAnimal(animalId);

      expect(feedings, isEmpty);
    },
  );
}
