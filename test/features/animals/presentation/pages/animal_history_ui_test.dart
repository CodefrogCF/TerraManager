import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_history_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animalRepository;
  late BoxRepository boxRepository;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());

    animalRepository = AnimalRepository(database);

    boxRepository = BoxRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createBox(String qrId) {
    return boxRepository.createBox(qrId);
  }

  Future<int> createAnimal({required int boxId, required String commonName}) {
    return animalRepository.createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  Future<void> scrollToKey(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();
  }

  testWidgets('animal overview opens empty history', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AnimalsPage(database: database)));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('animal-history-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('animal-history-button')));

    await tester.pumpAndSettle();

    expect(find.text('Animal History'), findsOneWidget);

    expect(find.byKey(const Key('animal-history-empty-state')), findsOneWidget);

    expect(find.text('No archived animals'), findsOneWidget);
  });

  testWidgets('history displays archived animal metadata', (tester) async {
    final boxId = await createBox(
      'TM:BOX:11111111-aaaa-4111-8111-111111111111',
    );

    final animalId = await createAnimal(
      boxId: boxId,
      commonName: 'Archived Snake',
    );

    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.sold,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );

    await tester.pumpAndSettle();

    expect(find.text('Archived Snake'), findsOneWidget);

    expect(find.text('Pantherophis guttatus'), findsOneWidget);

    expect(find.text('Sold • 01.09.2026'), findsOneWidget);

    expect(
      find.byKey(Key('archived-animal-list-item-$animalId')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(Key('archived-animal-list-item-$animalId')));

    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('restore-animal-button'));

    expect(
      find.byKey(const Key('archive-information-heading')),
      findsOneWidget,
    );
  });

  testWidgets('restored animal leaves history and returns to active overview', (
    tester,
  ) async {
    final firstBoxId = await createBox(
      'TM:BOX:22222222-aaaa-4222-8222-222222222222',
    );

    final secondBoxId = await createBox(
      'TM:BOX:33333333-aaaa-4333-8333-333333333333',
    );

    final animalId = await createAnimal(
      boxId: firstBoxId,
      commonName: 'Restore Me',
    );

    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.rehomed,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(MaterialApp(home: AnimalsPage(database: database)));

    await tester.pumpAndSettle();

    expect(find.text('Restore Me'), findsNothing);

    await tester.tap(find.byKey(const Key('animal-history-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('archived-animal-list-item-$animalId')));

    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('restore-animal-button'));

    await tester.tap(find.byKey(const Key('restore-animal-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restore-box-field')));

    await tester.pumpAndSettle();

    expect(find.text('Box $firstBoxId'), findsOneWidget);
    expect(find.text('Box $secondBoxId'), findsOneWidget);

    expect(
      find.text('TM:BOX:22222222-aaaa-4222-8222-222222222222'),
      findsNothing,
    );

    expect(
      find.text('TM:BOX:33333333-aaaa-4333-8333-333333333333'),
      findsNothing,
    );

    await tester.tap(find.text('Box $secondBoxId').last);

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-restore-animal-button')));

    await tester.pumpAndSettle();

    final animal = await animalRepository.getAnimalById(animalId);

    expect(animal!.boxId, secondBoxId);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Restore Me'), findsNothing);

    expect(find.text('No archived animals'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Restore Me'), findsOneWidget);
  });

  testWidgets('archived animal can be permanently deleted from history', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:44444444-aaaa-4444-8444-444444444444',
    );

    final animalId = await createAnimal(boxId: boxId, commonName: 'Delete Me');

    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('archived-animal-list-item-$animalId')));

    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('permanent-delete-animal-button'));

    await tester.tap(find.byKey(const Key('permanent-delete-animal-button')));

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('permanent-delete-animal-dialog')),
      findsOneWidget,
    );

    expect(
      find.textContaining('all associated feeding history'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('confirm-permanent-delete-animal-button')),
    );

    await tester.pumpAndSettle();

    expect(await animalRepository.getAnimalById(animalId), isNull);

    expect(find.text('Delete Me'), findsNothing);

    expect(find.text('No archived animals'), findsOneWidget);
  });
}
