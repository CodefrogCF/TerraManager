import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';

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
}
