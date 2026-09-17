import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';
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

  Future<int> createBox(String id) {
    return BoxRepository(database).createBox(id);
  }

  testWidgets('New Animal uses paired ranges and stores numeric weight', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:11111111-1111-4111-8111-111111111111',
    );
    await openPage(
      tester,
      NewAnimalPage(database: database, initialBoxId: boxId),
    );

    expect(find.byKey(const Key('birth-date-field')), findsNothing);
    await revealCharacteristics(tester);

    for (final pair in [
      ('temp-min-field', 'temp-max-field'),
      ('humidity-min-field', 'humidity-max-field'),
      ('nighttime-temperature-min-field', 'nighttime-temperature-max-field'),
    ]) {
      final minimum = tester.getTopLeft(find.byKey(Key(pair.$1)));
      final maximum = tester.getTopLeft(find.byKey(Key(pair.$2)));
      expect(minimum.dy, maximum.dy);
      expect(minimum.dx, lessThan(maximum.dx));
    }

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
    await tester.enterText(find.byKey(const Key('weight-field')), '125,5');
    await tester.enterText(
      find.byKey(const Key('origin-habitat-field')),
      'South America',
    );
    await tester.enterText(
      find.byKey(const Key('nighttime-temperature-min-field')),
      '18',
    );
    await tester.enterText(
      find.byKey(const Key('nighttime-temperature-max-field')),
      '20',
    );
    await tester.enterText(
      find.byKey(const Key('rest-or-dormancy-periods-field')),
      'Reduced activity in winter',
    );
    await tester.enterText(
      find.byKey(const Key('shedding-notes-field')),
      'Complete sheds',
    );
    await tester.enterText(find.byKey(const Key('notes-field')), 'Calm animal');

    await tester.tap(find.byKey(const Key('save-animal-button')));
    await tester.pumpAndSettle();

    final animal = await database.select(database.animals).getSingle();
    expect(animal.originHabitat, 'South America');
    expect(animal.weight, isNull);
    expect(animal.nighttimeTemperature, isNull);
    expect(animal.nighttimeTemperatureMin, 18);
    expect(animal.nighttimeTemperatureMax, 20);
    expect(animal.restOrDormancyPeriods, 'Reduced activity in winter');
    expect(animal.sheddingNotes, 'Complete sheds');
    expect(animal.notes, 'Calm animal');

    final history = await AnimalWeightRepository(database)
        .getHistory(animal.id);
    expect(history, hasLength(1));
    expect(history.single.weightGrams, 125.5);
  });

  testWidgets('Edit Animal creates history only for changed numeric weight', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:22222222-2222-4222-8222-222222222222',
    );
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      weightGrams: 80,
      nighttimeTemperatureMin: 17,
      nighttimeTemperatureMax: 19,
    );

    await openPage(
      tester,
      AnimalEditPage(database: database, animalId: animalId),
    );
    expect(find.byKey(const Key('weight-field')), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('weight-field')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '80.0',
    );

    await tester.tap(find.byKey(const Key('save-animal-button')));
    await tester.pumpAndSettle();
    expect(
      await AnimalWeightRepository(database).getHistory(animalId),
      hasLength(1),
    );

    await openPage(
      tester,
      AnimalEditPage(database: database, animalId: animalId),
    );
    await tester.enterText(find.byKey(const Key('weight-field')), '82.5');
    await tester.tap(find.byKey(const Key('save-animal-button')));
    await tester.pumpAndSettle();

    final history = await AnimalWeightRepository(database).getHistory(animalId);
    expect(history.map((entry) => entry.weightGrams), [82.5, 80]);
  });

  testWidgets('legacy free-form weight stays visible until replaced', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:33333333-3333-4333-8333-333333333333',
    );
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Legacy Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      weight: 'about 80 g after feeding',
    );

    await openPage(
      tester,
      AnimalEditPage(database: database, animalId: animalId),
    );
    expect(
      find.textContaining('Legacy value: about 80 g after feeding'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('weight-field')), '81');
    await tester.tap(find.byKey(const Key('save-animal-button')));
    await tester.pumpAndSettle();

    final animal = await AnimalRepository(database).getAnimalById(animalId);
    expect(animal!.weight, isNull);
    expect(
      (await AnimalWeightRepository(database).getLatest(animalId))!.weightGrams,
      81,
    );
  });

  testWidgets('Animal details show nighttime range and weight history', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:44444444-4444-4444-8444-444444444444',
    );
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      nighttimeTemperatureMin: 17,
      nighttimeTemperatureMax: 19,
      weightGrams: 125,
    );

    await openPage(
      tester,
      AnimalDetailPage(database: database, animalId: animalId),
    );

    final night = find.byKey(const Key('nighttime-temperature-detail'));
    await tester.scrollUntilVisible(night, 250);
    await tester.pumpAndSettle();
    expect(find.text('17.0 °C – 19.0 °C'), findsOneWidget);

    final weight = find.byKey(const Key('weight-detail'));
    await tester.scrollUntilVisible(weight, 250);
    expect(find.text('125 g'), findsOneWidget);

    final addWeight = find.byKey(const Key('weight-add-button'));
    final weightHistory = find.byKey(const Key('weight-history-button'));
    expect(addWeight, findsOneWidget);
    expect(weightHistory, findsOneWidget);
    expect(
      tester.getCenter(addWeight).dx,
      lessThan(tester.getCenter(weightHistory).dx),
    );

    await tester.tap(addWeight);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('weight-value-field')),
      '130,5',
    );
    await tester.tap(find.byKey(const Key('save-weight-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weight-dialog')), findsNothing);
    expect(
      (await AnimalWeightRepository(database).getLatest(animalId))!.weightGrams,
      130.5,
    );
    await tester.drag(
      find.byKey(ValueKey<String>('animal-detail-list-$animalId')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('130.5 g'), findsOneWidget);

    await tester.tap(weightHistory);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weight-history-list')), findsOneWidget);
    expect(find.text('125 g'), findsOneWidget);
    expect(find.text('130.5 g'), findsOneWidget);
  });
}
