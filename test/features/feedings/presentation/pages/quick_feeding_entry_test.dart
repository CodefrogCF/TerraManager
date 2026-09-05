import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_box_animals_page.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_history_page.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_scanner_page.dart';

const _targetQrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<Box> createBox({String qrId = 'quick-feeding-box'}) async {
    final boxId = await BoxRepository(database).createBox(qrId);

    return (await BoxRepository(database).getBoxById(boxId))!;
  }

  Future<Animal> createAnimal({
    required int boxId,
    required String commonName,
  }) async {
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    return (await AnimalRepository(database).getAnimalById(animalId))!;
  }

  Future<void> pumpDirectPage(
    WidgetTester tester, {
    required Box box,
    required List<Animal> animals,
    DateTime? initialFedAt,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: FeedingBoxAnimalsPage(
          database: database,
          box: box,
          animals: animals,
          initialFedAt: initialFedAt,
        ),
      ),
    );
  }

  Future<Completer<bool?>> openPageAsRoute(
    WidgetTester tester, {
    required Box box,
    required List<Animal> animals,
    DateTime? initialFedAt,
  }) async {
    final result = Completer<bool?>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                key: const Key('open-quick-feeding-page-button'),
                onPressed: () async {
                  final value = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => FeedingBoxAnimalsPage(
                        database: database,
                        box: box,
                        animals: animals,
                        initialFedAt: initialFedAt,
                      ),
                    ),
                  );

                  result.complete(value);
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-quick-feeding-page-button')));
    await tester.pumpAndSettle();

    return result;
  }

  testWidgets('selects all Animals and pre-fills the feeding time', (
    tester,
  ) async {
    final box = await createBox();
    final firstAnimal = await createAnimal(
      boxId: box.id,
      commonName: 'First Snake',
    );
    final secondAnimal = await createAnimal(
      boxId: box.id,
      commonName: 'Second Snake',
    );

    await pumpDirectPage(
      tester,
      box: box,
      animals: [firstAnimal, secondAnimal],
      initialFedAt: DateTime(2026, 9, 5, 14, 30),
    );

    await tester.pumpAndSettle();

    final firstSelection = tester.widget<CheckboxListTile>(
      find.byKey(Key('feeding-mode-animal-${firstAnimal.id}')),
    );
    final secondSelection = tester.widget<CheckboxListTile>(
      find.byKey(Key('feeding-mode-animal-${secondAnimal.id}')),
    );

    expect(firstSelection.value, isTrue);
    expect(secondSelection.value, isTrue);
    expect(find.text('05.09.2026 14:30'), findsOneWidget);
    expect(find.text('Save 2 Feedings'), findsOneWidget);
  });

  testWidgets('saves one FeedingEvent for every selected Animal', (
    tester,
  ) async {
    final box = await createBox();
    final firstAnimal = await createAnimal(
      boxId: box.id,
      commonName: 'First Snake',
    );
    final secondAnimal = await createAnimal(
      boxId: box.id,
      commonName: 'Second Snake',
    );
    final fedAt = DateTime(2026, 9, 5, 14, 30);

    final result = await openPageAsRoute(
      tester,
      box: box,
      animals: [firstAnimal, secondAnimal],
      initialFedAt: fedAt,
    );

    await tester.enterText(
      find.byKey(const Key('quick-feeding-notes-field')),
      '  One mouse each  ',
    );

    await tester.tap(find.byKey(const Key('save-quick-feeding-button')));
    await tester.pumpAndSettle();

    expect(await result.future, isTrue);

    final feedings = await FeedingRepository(database).getAllFeedings();

    expect(feedings, hasLength(2));
    expect(feedings.map((feeding) => feeding.animalId).toSet(), {
      firstAnimal.id,
      secondAnimal.id,
    });
    expect(feedings.every((feeding) => feeding.fedAt == fedAt), isTrue);
    expect(
      feedings.every((feeding) => feeding.notes == 'One mouse each'),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FeedingHistoryPage(database: database, animalId: firstAnimal.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('05.09.2026 14:30'), findsOneWidget);
    expect(find.text('One mouse each'), findsOneWidget);
  });

  testWidgets('ignores repeated save submissions', (tester) async {
    final box = await createBox();
    final animal = await createAnimal(boxId: box.id, commonName: 'Test Snake');

    final result = await openPageAsRoute(
      tester,
      box: box,
      animals: [animal],
      initialFedAt: DateTime(2026, 9, 5, 14, 30),
    );

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-quick-feeding-button')),
    );

    saveButton.onPressed!();
    saveButton.onPressed!();
    await tester.pumpAndSettle();

    expect(await result.future, isTrue);

    final feedings = await FeedingRepository(database)
        .getFeedingsForAnimal(animal.id);

    expect(feedings, hasLength(1));
  });

  testWidgets('allows one Animal to be excluded from the feeding', (
    tester,
  ) async {
    final box = await createBox();
    final firstAnimal = await createAnimal(
      boxId: box.id,
      commonName: 'First Snake',
    );
    final secondAnimal = await createAnimal(
      boxId: box.id,
      commonName: 'Second Snake',
    );

    final result = await openPageAsRoute(
      tester,
      box: box,
      animals: [firstAnimal, secondAnimal],
      initialFedAt: DateTime(2026, 9, 5, 14, 30),
    );

    await tester.tap(find.byKey(Key('feeding-mode-animal-${secondAnimal.id}')));
    await tester.pump();

    expect(find.text('Save Feeding'), findsOneWidget);

    final saveButton = find.byKey(const Key('save-quick-feeding-button'));

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(await result.future, isTrue);

    final feedings = await FeedingRepository(database).getAllFeedings();

    expect(feedings, hasLength(1));
    expect(feedings.single.animalId, firstAnimal.id);
  });

  testWidgets('disables saving when no Animal is selected', (tester) async {
    final box = await createBox();
    final animal = await createAnimal(boxId: box.id, commonName: 'Test Snake');

    await pumpDirectPage(tester, box: box, animals: [animal]);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('toggle-all-feeding-animals-button')),
    );
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-quick-feeding-button')),
    );

    expect(saveButton.onPressed, isNull);
    expect(find.text('Select an Animal'), findsOneWidget);
  });

  testWidgets('returns to the scanner and confirms a successful feeding', (
    tester,
  ) async {
    final box = await createBox(qrId: _targetQrId);
    final animal = await createAnimal(
      boxId: box.id,
      commonName: 'Scanner Snake',
    );

    late Future<void> Function(String) scan;
    var stopCalls = 0;
    var startCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeedingScannerPage(
          database: database,
          onHandlerReady: (handler) {
            scan = handler;
          },
          stopScanner: () async {
            stopCalls++;
          },
          startScanner: () async {
            startCalls++;
          },
        ),
      ),
    );

    await tester.pump();

    final scanFuture = scan(_targetQrId);

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-quick-feeding-button')));
    await tester.pumpAndSettle();
    await scanFuture;

    expect(find.byType(FeedingScannerPage), findsOneWidget);
    expect(find.text('Feeding events saved'), findsOneWidget);
    expect(find.byKey(const Key('feeding-mode-saved-message')), findsOneWidget);
    expect(stopCalls, 1);
    expect(startCalls, 1);

    final feedings = await FeedingRepository(database)
        .getFeedingsForAnimal(animal.id);

    expect(feedings, hasLength(1));
  });
}
