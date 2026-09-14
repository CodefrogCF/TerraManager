import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_edit_page.dart';
import 'package:terramanager/features/animals/presentation/pages/new_animal_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> openPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-page'),
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-page')));
    await tester.pumpAndSettle();
  }

  Future<void> revealCharacteristics(WidgetTester tester) async {
    final button = find.byKey(const Key('additional-characteristics-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('New Animal expands and saves all optional characteristics', (
    tester,
  ) async {
    final boxId = await BoxRepository(database)
        .createBox('TM:BOX:11111111-1111-4111-8111-111111111111');
    await openPage(
      tester,
      NewAnimalPage(database: database, initialBoxId: boxId),
    );

    expect(find.byKey(const Key('origin-habitat-field')), findsNothing);
    await revealCharacteristics(tester);

    await tester.enterText(
      find.byKey(const Key('origin-habitat-field')),
      'South America',
    );
    await tester.enterText(find.byKey(const Key('weight-field')), '125 g');
    await tester.enterText(
      find.byKey(const Key('shedding-notes-field')),
      'Complete sheds',
    );
    await tester.enterText(
      find.byKey(const Key('rest-or-dormancy-periods-field')),
      'Reduced activity in winter',
    );
    await tester.enterText(
      find.byKey(const Key('temperature-zones-field')),
      'Warm hide 28 °C',
    );
    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'Test Snake',
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

    final animal = await database.select(database.animals).getSingle();
    expect(animal.originHabitat, 'South America');
    expect(animal.weight, '125 g');
    expect(animal.sheddingNotes, 'Complete sheds');
    expect(animal.restOrDormancyPeriods, 'Reduced activity in winter');
    expect(animal.temperatureZones, 'Warm hide 28 °C');
  });

  testWidgets('Edit Animal shows saved values and can clear them', (
    tester,
  ) async {
    final boxId = await BoxRepository(database)
        .createBox('TM:BOX:22222222-2222-4222-8222-222222222222');
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      originHabitat: 'Forest',
      weight: '80 g',
      sheddingNotes: 'Regular',
      restOrDormancyPeriods: 'December',
      temperatureZones: '20–25 °C',
    );
    await openPage(
      tester,
      AnimalEditPage(database: database, animalId: animalId),
    );

    expect(find.byKey(const Key('origin-habitat-field')), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
    for (final key in [
      'origin-habitat-field',
      'weight-field',
      'shedding-notes-field',
      'rest-or-dormancy-periods-field',
      'temperature-zones-field',
    ]) {
      await tester.enterText(find.byKey(Key(key)), '');
    }

    await tester.tap(find.byKey(const Key('save-animal-button')));
    await tester.pumpAndSettle();

    final animal = await AnimalRepository(database).getAnimalById(animalId);
    expect(animal!.originHabitat, isNull);
    expect(animal.weight, isNull);
    expect(animal.sheddingNotes, isNull);
    expect(animal.restOrDormancyPeriods, isNull);
    expect(animal.temperatureZones, isNull);
  });

  testWidgets('Animal details only render non-empty characteristics', (
    tester,
  ) async {
    final boxId = await BoxRepository(database)
        .createBox('TM:BOX:33333333-3333-4333-8333-333333333333');
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      originHabitat: 'Savanna',
      weight: '  ',
      temperatureZones: 'Cool side 20 °C',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(database: database, animalId: animalId),
      ),
    );
    await tester.pumpAndSettle();

    final heading = find.byKey(const Key('additional-characteristics-heading'));
    await tester.scrollUntilVisible(heading, 300);
    await tester.pumpAndSettle();

    expect(heading, findsOneWidget);
    expect(find.byKey(const Key('origin-habitat-detail')), findsOneWidget);
    expect(find.byKey(const Key('temperature-zones-detail')), findsOneWidget);
    expect(find.byKey(const Key('weight-detail')), findsNothing);
    expect(find.byKey(const Key('shedding-notes-detail')), findsNothing);
  });
}
