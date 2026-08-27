import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/new_animal_page.dart';

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

  Future<int> createTestBox({
    String qrId = 'test-box-001',
  }) {
    return BoxRepository(database).createBox(qrId);
  }

  Future<void> pumpPage(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewAnimalPage(
          database: database,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpPageWithNavigation(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-new-animal-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewAnimalPage(
                          database: database,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open New Animal'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const Key('open-new-animal-button'),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> fillRequiredFields(
    WidgetTester tester, {
    required String boxQrId,
  }) async {
    await tester.tap(
      find.byKey(const Key('box-field')),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.text(boxQrId).last,
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'Test Snake',
    );

    await tester.enterText(
      find.byKey(const Key('latin-name-field')),
      'Pantherophis guttatus',
    );

    await tester.enterText(
      find.byKey(const Key('temp-min-field')),
      '24',
    );

    await tester.enterText(
      find.byKey(const Key('temp-max-field')),
      '28',
    );

    await tester.enterText(
      find.byKey(const Key('humidity-min-field')),
      '40',
    );

    await tester.enterText(
      find.byKey(const Key('humidity-max-field')),
      '60',
    );
  }

  testWidgets(
    'shows loading indicator while loading boxes',
    (tester) async {
      await createTestBox();

      await tester.pumpWidget(
        MaterialApp(
          home: NewAnimalPage(
            database: database,
          ),
        ),
      );

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );

      await tester.pumpAndSettle();

      expect(
        find.text('New Animal'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows form when boxes are available',
    (tester) async {
      await createTestBox();

      await pumpPage(tester);

      expect(
        find.byKey(const Key('box-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('common-name-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('latin-name-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('sex-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('birth-date-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('birth-date-accuracy-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('temp-min-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('temp-max-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('humidity-min-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('humidity-max-field')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows message when no boxes exist',
    (tester) async {
      await pumpPage(tester);

      expect(
        find.text(
          'No boxes available. Create a box before adding an animal.',
        ),
        findsOneWidget,
      );

      final button = tester.widget<IconButton>(
        find.byKey(const Key('save-animal-button')),
      );

      expect(
        button.onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'validates required fields',
    (tester) async {
      await createTestBox();

      await pumpPage(tester);

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Please select a box'),
        findsOneWidget,
      );

      expect(
        find.text('Please enter a common name'),
        findsOneWidget,
      );

      expect(
        find.text('Please enter a latin name'),
        findsOneWidget,
      );

      expect(
        find.text('Please enter a value'),
        findsNWidgets(4),
      );

      final animals =
          await AnimalRepository(database).getAllAnimals();

      expect(
        animals,
        isEmpty,
      );
    },
  );

  testWidgets(
    'validates numeric fields',
    (tester) async {
      await createTestBox();

      await pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('temp-min-field')),
        'invalid',
      );

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid number'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'creates animal in database',
    (tester) async {
      final boxId = await createTestBox();

      await pumpPageWithNavigation(tester);

      await fillRequiredFields(
        tester,
        boxQrId: 'test-box-001',
      );

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      final animals =
          await AnimalRepository(database).getAllAnimals();

      expect(
        animals.length,
        1,
      );

      final animal = animals.single;

      expect(animal.boxId, boxId);
      expect(animal.commonName, 'Test Snake');
      expect(
        animal.latinName,
        'Pantherophis guttatus',
      );
      expect(animal.tempMin, 24);
      expect(animal.tempMax, 28);
      expect(animal.humidityMin, 40);
      expect(animal.humidityMax, 60);
    },
  );

  testWidgets(
    'can create animal with optional sex',
    (tester) async {
      await createTestBox();

      await pumpPageWithNavigation(tester);

      await fillRequiredFields(
        tester,
        boxQrId: 'test-box-001',
      );

      final sexField = find.byKey(
        const Key('sex-field'),
      );

      await tester.ensureVisible(sexField);
      await tester.pumpAndSettle();

      await tester.tap(sexField);
      await tester.pumpAndSettle();

      expect(
        find.text('Sex.female'),
        findsWidgets,
      );

      await tester.tap(
        find.text('Sex.female').last,
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      final animals =
          await AnimalRepository(database).getAllAnimals();

      expect(
        animals.length,
        1,
      );

      expect(
        animals.single.sex,
        Sex.female,
      );
    },
  );

  testWidgets(
    'can select associated box',
    (tester) async {
      await createTestBox(
        qrId: 'test-box-001',
      );

      final secondBoxId = await createTestBox(
        qrId: 'test-box-002',
      );

      await pumpPageWithNavigation(tester);

      await fillRequiredFields(
        tester,
        boxQrId: 'test-box-002',
      );

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      final animals =
          await AnimalRepository(database).getAllAnimals();

      expect(
        animals.single.boxId,
        secondBoxId,
      );
    },
  );

  testWidgets(
    'returns to previous page after successful creation',
    (tester) async {
      await createTestBox();

      await pumpPageWithNavigation(tester);

      await fillRequiredFields(
        tester,
        boxQrId: 'test-box-001',
      );

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('New Animal'),
        findsNothing,
      );

      expect(
        find.text('Open New Animal'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'can create animal with notes',
    (tester) async {
      await createTestBox();

      await pumpPageWithNavigation(tester);

      await fillRequiredFields(
        tester,
        boxQrId: 'test-box-001',
      );

      final notesField = find.byKey(
        const Key('notes-field'),
      );

      await tester.ensureVisible(notesField);
      await tester.enterText(
        notesField,
        'Calm animal, feeds well.',
      );

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      final animals =
          await AnimalRepository(database).getAllAnimals();

      expect(
        animals.single.notes,
        'Calm animal, feeds well.',
      );
    },
  );

  testWidgets(
    'stores empty notes as null',
    (tester) async {
      await createTestBox();

      await pumpPageWithNavigation(tester);

      await fillRequiredFields(
        tester,
        boxQrId: 'test-box-001',
      );

      await tester.tap(
        find.byTooltip('Save Animal'),
      );

      await tester.pumpAndSettle();

      final animals =
          await AnimalRepository(database).getAllAnimals();

      expect(
        animals.single.notes,
        isNull,
      );
    },
  );

  testWidgets(
    'shows picture selection control',
    (tester) async {
      await createTestBox();

      await pumpPage(tester);

      expect(
        find.byKey(const Key('select-picture-button')),
        findsOneWidget,
      );

      expect(
        find.text('Select Picture'),
        findsOneWidget,
      );

      expect(
        find.text('No picture'),
        findsOneWidget,
      );
    },
  );
}