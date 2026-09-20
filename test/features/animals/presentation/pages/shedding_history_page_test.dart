import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/shedding_history_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<int> createAnimal() async {
    final boxId = await BoxRepository(database)
        .createBox('shedding-history-box');

    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Shedding Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  Future<void> pumpPage(WidgetTester tester, int animalId) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SheddingHistoryPage(database: database, animalId: animalId),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('adds a shedding event from the history page', (tester) async {
    final animalId = await createAnimal();

    await pumpPage(tester, animalId);

    expect(find.byKey(const Key('shedding-history-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-shedding-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shedding-dialog')), findsOneWidget);

    expect(find.byKey(const Key('shedding-date-time-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('shedding-notes-field')),
      'Complete shed',
    );

    await tester.tap(find.byKey(const Key('save-shedding-button')));

    await tester.pumpAndSettle();

    final history = await SheddingRepository(database).getHistory(animalId);

    expect(history, hasLength(1));

    expect(history.single.notes, 'Complete shed');

    expect(find.text('Complete shed'), findsOneWidget);
  });

  testWidgets('edits an existing shedding event without adding a row', (
    tester,
  ) async {
    final animalId = await createAnimal();

    final repository = SheddingRepository(database);

    final entryId = await repository.add(
      animalId: animalId,
      shedAt: DateTime(2026, 9, 1, 10),
      notes: 'Old note',
    );

    await pumpPage(tester, animalId);

    await tester.tap(find.byKey(Key('edit-shedding-button-$entryId')));

    await tester.pumpAndSettle();

    expect(find.text('Edit shedding'), findsOneWidget);

    final field = tester.widget<TextField>(
      find.byKey(const Key('shedding-notes-field')),
    );

    expect(field.controller!.text, 'Old note');

    await tester.enterText(
      find.byKey(const Key('shedding-notes-field')),
      'Complete shed',
    );

    await tester.tap(find.byKey(const Key('save-shedding-button')));

    await tester.pumpAndSettle();

    final history = await repository.getHistory(animalId);

    expect(history, hasLength(1));

    expect(history.single.id, entryId);

    expect(history.single.notes, 'Complete shed');

    expect(find.text('Complete shed'), findsOneWidget);
  });

  testWidgets('deletes a shedding event only after confirmation', (
    tester,
  ) async {
    final animalId = await createAnimal();

    final repository = SheddingRepository(database);

    final entryId = await repository.add(
      animalId: animalId,
      shedAt: DateTime(2026, 9, 1, 10),
      notes: 'Complete shed',
    );

    await pumpPage(tester, animalId);

    await tester.tap(find.byKey(Key('delete-shedding-button-$entryId')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-shedding-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-delete-shedding-button')));

    await tester.pumpAndSettle();

    expect(await repository.getHistory(animalId), hasLength(1));

    await tester.tap(find.byKey(Key('delete-shedding-button-$entryId')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-delete-shedding-button')));

    await tester.pumpAndSettle();

    expect(await repository.getHistory(animalId), isEmpty);

    expect(find.byKey(const Key('shedding-history-empty')), findsOneWidget);
  });
}
