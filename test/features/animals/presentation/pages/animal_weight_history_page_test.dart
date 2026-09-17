import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_weight_history_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<int> createAnimal() async {
    final boxId = await BoxRepository(database).createBox('weight-history-box');
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Weighted Animal',
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
        home: AnimalWeightHistoryPage(database: database, animalId: animalId),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('adds a measurement from the history page', (tester) async {
    final animalId = await createAnimal();
    await pumpPage(tester, animalId);

    expect(find.byKey(const Key('weight-history-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-weight-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weight-dialog')), findsOneWidget);
    expect(find.byKey(const Key('weight-date-time-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('weight-value-field')), '42,5');
    await tester.tap(find.byKey(const Key('save-weight-button')));
    await tester.pumpAndSettle();

    final history = await AnimalWeightRepository(database).getHistory(animalId);
    expect(history, hasLength(1));
    expect(history.single.weightGrams, 42.5);
    expect(find.text('42.5 g'), findsOneWidget);
  });

  testWidgets('edits an existing measurement without adding a row', (
    tester,
  ) async {
    final animalId = await createAnimal();
    final repository = AnimalWeightRepository(database);
    final entryId = await repository.add(
      animalId: animalId,
      weightGrams: 50,
      measuredAt: DateTime(2026, 9, 1, 10),
    );
    await pumpPage(tester, animalId);

    await tester.tap(find.byKey(Key('edit-weight-button-$entryId')));
    await tester.pumpAndSettle();
    expect(find.text('Edit weight'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('weight-value-field')),
    );
    expect(field.controller!.text, '50');

    await tester.enterText(
      find.byKey(const Key('weight-value-field')),
      '51.25',
    );
    await tester.tap(find.byKey(const Key('save-weight-button')));
    await tester.pumpAndSettle();

    final history = await repository.getHistory(animalId);
    expect(history, hasLength(1));
    expect(history.single.id, entryId);
    expect(history.single.weightGrams, 51.25);
    expect(find.text('51.25 g'), findsOneWidget);
  });

  testWidgets('deletes a measurement only after confirmation', (tester) async {
    final animalId = await createAnimal();
    final repository = AnimalWeightRepository(database);
    final entryId = await repository.add(
      animalId: animalId,
      weightGrams: 50,
      measuredAt: DateTime(2026, 9, 1, 10),
    );
    await pumpPage(tester, animalId);

    await tester.tap(find.byKey(Key('delete-weight-button-$entryId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-weight-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-delete-weight-button')));
    await tester.pumpAndSettle();
    expect(await repository.getHistory(animalId), hasLength(1));

    await tester.tap(find.byKey(Key('delete-weight-button-$entryId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-weight-button')));
    await tester.pumpAndSettle();

    expect(await repository.getHistory(animalId), isEmpty);
    expect(find.byKey(const Key('weight-history-empty')), findsOneWidget);
  });
}
