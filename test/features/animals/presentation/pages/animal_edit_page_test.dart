import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_edit_page.dart';

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
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      sex: Sex.female,
      birthDate: DateTime(2024, 5, 10),
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      notes: 'Original notes',
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required int animalId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalEditPage(
          database: database,
          animalId: animalId,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpPageWithNavigation(
    WidgetTester tester, {
    required int animalId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-edit-page-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnimalEditPage(
                          database: database,
                          animalId: animalId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('open-edit-page-button')),
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows loading indicator while loading animal',
    (tester) async {
      final animalId = await createTestAnimal();

      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditPage(
            database: database,
            animalId: animalId,
          ),
        ),
      );

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Edit Animal'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'loads existing animal data into form',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const Key('common-name-field'),
              ),
            )
            .controller!
            .text,
        'Test Snake',
      );

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const Key('latin-name-field'),
              ),
            )
            .controller!
            .text,
        'Pantherophis guttatus',
      );

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const Key('temp-min-field'),
              ),
            )
            .controller!
            .text,
        '24.0',
      );

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const Key('temp-max-field'),
              ),
            )
            .controller!
            .text,
        '28.0',
      );

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const Key('humidity-min-field'),
              ),
            )
            .controller!
            .text,
        '40.0',
      );

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const Key('humidity-max-field'),
              ),
            )
            .controller!
            .text,
        '60.0',
      );

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(
                const Key('notes-field'),
              ),
            )
            .controller!
            .text,
        'Original notes',
      );

      expect(
        find.byKey(const Key('sex-field')),
        findsOneWidget,
      );

      expect(
        find.text('Sex.female'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('birth-date-field')),
        findsOneWidget,
      );

      expect(
        find.text('10.05.2024'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('box-field')),
        findsOneWidget,
      );

      expect(
        find.text('test-box-001'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows error when animal does not exist',
    (tester) async {
      await pumpPage(
        tester,
        animalId: 999,
      );

      expect(
        find.text('Animal not found'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'saves changed animal data',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.enterText(
        find.byKey(const Key('common-name-field')),
        'Updated Snake',
      );

      await tester.pump();

      await tester.tap(
        find.byTooltip('Save'),
      );

      await tester.pumpAndSettle();

      final updatedAnimal =
          await AnimalRepository(database).getAnimalById(animalId);

      expect(
        updatedAnimal,
        isNotNull,
      );

      expect(
        updatedAnimal!.commonName,
        'Updated Snake',
      );
    },
  );

  testWidgets(
    'can change associated box',
    (tester) async {
      final animalId = await createTestAnimal();

      final secondBoxId =
          await database.into(database.boxes).insert(
                BoxesCompanion.insert(
                  qrId: 'test-box-002',
                ),
              );

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(const Key('box-field')),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.text('test-box-002').last,
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byTooltip('Save'),
      );

      await tester.pumpAndSettle();

      final updatedAnimal =
          await AnimalRepository(database).getAnimalById(animalId);

      expect(
        updatedAnimal,
        isNotNull,
      );

      expect(
        updatedAnimal!.boxId,
        secondBoxId,
      );
    },
  );

  testWidgets(
    'validates required common name',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.enterText(
        find.byKey(const Key('common-name-field')),
        '',
      );

      await tester.tap(
        find.byTooltip('Save'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a common name'),
        findsOneWidget,
      );

      final unchangedAnimal =
          await AnimalRepository(database).getAnimalById(animalId);

      expect(
        unchangedAnimal!.commonName,
        'Test Snake',
      );
    },
  );

  testWidgets(
    'validates required latin name',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.enterText(
        find.byKey(const Key('latin-name-field')),
        '',
      );

      await tester.tap(
        find.byTooltip('Save'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a latin name'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'validates numeric fields',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPage(
        tester,
        animalId: animalId,
      );

      await tester.enterText(
        find.byKey(const Key('temp-min-field')),
        'not-a-number',
      );

      await tester.tap(
        find.byTooltip('Save'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid number'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows unsaved changes dialog when leaving',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPageWithNavigation(
        tester,
        animalId: animalId,
      );

      await tester.enterText(
        find.byKey(const Key('common-name-field')),
        'Changed Snake',
      );

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('back-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Unsaved changes'),
        findsOneWidget,
      );

      expect(
        find.text(
          'You have unsaved changes. Do you really want to leave?',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Cancel'),
        findsOneWidget,
      );

      expect(
        find.text('Discard'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cancel keeps edit page open',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPageWithNavigation(
        tester,
        animalId: animalId,
      );

      await tester.enterText(
        find.byKey(const Key('common-name-field')),
        'Changed Snake',
      );

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('back-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Unsaved changes'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Cancel'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Unsaved changes'),
        findsNothing,
      );

      expect(
        find.text('Edit Animal'),
        findsOneWidget,
      );

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('common-name-field')),
      );

      expect(
        field.controller!.text,
        'Changed Snake',
      );
    },
  );

  testWidgets(
    'discard leaves edit page without saving changes',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPageWithNavigation(
        tester,
        animalId: animalId,
      );

      await tester.enterText(
        find.byKey(const Key('common-name-field')),
        'Changed Snake',
      );

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('back-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Unsaved changes'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Discard'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Edit Animal'),
        findsNothing,
      );

      expect(
        find.text('Open Edit'),
        findsOneWidget,
      );

      final animal =
          await AnimalRepository(database).getAnimalById(animalId);

      expect(
        animal,
        isNotNull,
      );

      expect(
        animal!.commonName,
        'Test Snake',
      );
    },
  );

  testWidgets(
    'leaves without confirmation when nothing changed',
    (tester) async {
      final animalId = await createTestAnimal();

      await pumpPageWithNavigation(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(const Key('back-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Unsaved changes'),
        findsNothing,
      );

      expect(
        find.text('Open Edit'),
        findsOneWidget,
      );
    },
  );
}