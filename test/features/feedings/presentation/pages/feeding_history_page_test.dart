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
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createTestAnimal() async {
    final boxId = await BoxRepository(database).createBox(
      'test-box-001',
    );

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

  Future<void> pumpPage(
    WidgetTester tester, {
    required int animalId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeedingHistoryPage(
          database: database,
          animalId: animalId,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows empty state when no feeding events exist',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      expect(
        find.text('No feeding events available'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows existing feeding events',
    (tester) async {
      final animalId = await createTestAnimal();

      await FeedingRepository(database).addFeeding(
        animalId,
        DateTime(2026, 8, 20, 18, 30),
        notes: 'Mouse',
      );

      await pumpPage(
        tester,
        animalId: animalId,
      );

      expect(
        find.text('20.08.2026 18:30'),
        findsOneWidget,
      );

      expect(
        find.text('Mouse'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows feedings newest first',
    (tester) async {
      final animalId = await createTestAnimal();

      await FeedingRepository(database).addFeeding(
        animalId,
        DateTime(2026, 8, 10, 12),
        notes: 'Older',
      );

      await FeedingRepository(database).addFeeding(
        animalId,
        DateTime(2026, 8, 20, 12),
        notes: 'Newer',
      );

      await pumpPage(
        tester,
        animalId: animalId,
      );

      final newer = tester.getTopLeft(
        find.text('Newer'),
      );

      final older = tester.getTopLeft(
        find.text('Older'),
      );

      expect(
        newer.dy,
        lessThan(older.dy),
      );
    },
  );

  testWidgets(
    'add button opens feeding dialog',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(const Key('add-feeding-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Add Feeding'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('feeding-notes-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('save-feeding-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'creates feeding event',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(const Key('add-feeding-button')),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('feeding-notes-field')),
        'Test feeding',
      );

      await tester.tap(
        find.byKey(const Key('save-feeding-button')),
      );

      await tester.pumpAndSettle();

      final feedings =
          await FeedingRepository(database)
              .getFeedingsForAnimal(animalId);

      expect(
        feedings.length,
        1,
      );

      expect(
        feedings.single.notes,
        'Test feeding',
      );

      expect(
        find.text('Test feeding'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'can create feeding without notes',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(const Key('add-feeding-button')),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('save-feeding-button')),
      );

      await tester.pumpAndSettle();

      final feedings =
          await FeedingRepository(database)
              .getFeedingsForAnimal(animalId);

      expect(
        feedings.length,
        1,
      );

      expect(
        feedings.single.notes,
        isNull,
      );
    },
  );

  testWidgets(
    'cancel does not create feeding',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(const Key('add-feeding-button')),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('feeding-notes-field')),
        'Should not save',
      );

      await tester.tap(
        find.text('Cancel'),
      );

      await tester.pumpAndSettle();

      final feedings =
          await FeedingRepository(database)
              .getFeedingsForAnimal(animalId);

      expect(
        feedings,
        isEmpty,
      );

      expect(
        find.text('Add Feeding'),
        findsNothing,
      );
    },
  );
}