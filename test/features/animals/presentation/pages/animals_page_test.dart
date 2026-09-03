import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createTestBox() {
    return BoxRepository(database).createBox('test-box-001');
  }

  Future<int> createTestAnimal({
    required int boxId,
    String commonName = 'Test Snake',
    String latinName = 'Pantherophis guttatus',
  }) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: latinName,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AnimalsPage(database: database)));

    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no animals exist', (tester) async {
    await pumpPage(tester);

    expect(find.text('No animals available'), findsOneWidget);
  });

  testWidgets('shows animal from database', (tester) async {
    final boxId = await createTestBox();

    await createTestAnimal(boxId: boxId);

    await pumpPage(tester);

    expect(find.text('Test Snake'), findsOneWidget);

    expect(find.text('Pantherophis guttatus'), findsOneWidget);
  });

  testWidgets('shows multiple animals', (tester) async {
    final boxId = await createTestBox();

    await createTestAnimal(boxId: boxId, commonName: 'Snake One');

    await createTestAnimal(boxId: boxId, commonName: 'Snake Two');

    await pumpPage(tester);

    expect(find.text('Snake One'), findsOneWidget);

    expect(find.text('Snake Two'), findsOneWidget);
  });

  testWidgets('opens animal detail page', (tester) async {
    final boxId = await createTestBox();

    await createTestAnimal(boxId: boxId);

    await pumpPage(tester);

    await tester.tap(find.text('Test Snake'));

    await tester.pumpAndSettle();

    expect(find.text('Animal Details'), findsOneWidget);

    expect(find.text('Test Snake'), findsOneWidget);
  });

  testWidgets('add button opens new animal page', (tester) async {
    await createTestBox();

    await pumpPage(tester);

    expect(find.byKey(const Key('add-animal-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-animal-button')));

    await tester.pumpAndSettle();

    expect(find.text('New Animal'), findsOneWidget);

    expect(find.byKey(const Key('common-name-field')), findsOneWidget);
  });

  testWidgets('newly created animal appears in overview', (tester) async {
    await createTestBox();

    await pumpPage(tester);

    expect(find.text('No animals available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-animal-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('box-field')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Box 1').last);

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'New Snake',
    );

    await tester.enterText(
      find.byKey(const Key('latin-name-field')),
      'Pantherophis guttatus',
    );

    await tester.enterText(find.byKey(const Key('temp-min-field')), '24');

    await tester.enterText(find.byKey(const Key('temp-max-field')), '28');

    await tester.enterText(find.byKey(const Key('humidity-min-field')), '40');

    await tester.enterText(find.byKey(const Key('humidity-max-field')), '60');

    await tester.tap(find.byTooltip('Save Animal'));

    await tester.pumpAndSettle();

    expect(find.text('Animals'), findsOneWidget);

    expect(find.text('New Snake'), findsOneWidget);

    expect(find.text('Pantherophis guttatus'), findsOneWidget);

    expect(find.text('No animals available'), findsNothing);

    final animals = await AnimalRepository(database).getAllAnimals();

    expect(animals.length, 1);

    expect(animals.single.commonName, 'New Snake');
  });
}
