import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_edit_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animalRepository;
  late BoxRepository boxRepository;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );

    animalRepository = AnimalRepository(database);
    boxRepository = BoxRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createBox(
    String qrId,
  ) {
    return boxRepository.createBox(qrId);
  }

  Future<int> createAnimal({
    required int boxId,
    String commonName = 'Corn Snake',
    String latinName = 'Pantherophis guttatus',
  }) {
    return animalRepository.createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: latinName,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required int animalId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(
          database: database,
          animalId: animalId,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> scrollToKey(
    WidgetTester tester,
    Key key,
  ) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'active animal can be archived',
    (tester) async {
      final boxId = await createBox(
        'TM:BOX:11111111-1111-4111-8111-111111111111',
      );

      final animalId = await createAnimal(
        boxId: boxId,
      );

      await pumpDetail(
        tester,
        animalId: animalId,
      );

      expect(
        find.byKey(
          const Key('edit-animal-button'),
        ),
        findsOneWidget,
      );

      await scrollToKey(
        tester,
        const Key('archive-animal-button'),
      );

      await tester.tap(
        find.byKey(
          const Key('archive-animal-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('archive-animal-dialog'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const Key('archive-reason-field'),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Sold').last,
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(
          const Key('archive-notes-field'),
        ),
        'Transferred to new owner',
      );

      await tester.tap(
        find.byKey(
          const Key(
            'confirm-archive-animal-button',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final animal =
          await animalRepository.getAnimalById(
        animalId,
      );

      expect(animal, isNotNull);

      expect(
        animal!.status,
        AnimalStatus.archived,
      );

      expect(
        animal.boxId,
        isNull,
      );

      expect(
        animal.archiveReason,
        AnimalArchiveReason.sold,
      );

      expect(
        animal.archivedAt,
        isNotNull,
      );

      expect(
        animal.archiveNotes,
        'Transferred to new owner',
      );

      await scrollToKey(
        tester,
        const Key('restore-animal-button'),
      );

      expect(
        find.byKey(
          const Key(
            'archive-information-heading',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text('Sold'),
        findsOneWidget,
      );

      expect(
        find.text(
          'Transferred to new owner',
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('restore-animal-button'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('edit-animal-button'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'archived animal can be restored to another box',
    (tester) async {
      final firstBoxId = await createBox(
        'TM:BOX:22222222-2222-4222-8222-222222222222',
      );

      final secondBoxId = await createBox(
        'TM:BOX:33333333-3333-4333-8333-333333333333',
      );

      final animalId = await createAnimal(
        boxId: firstBoxId,
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.traded,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
        archiveNotes: 'Trade',
      );

      await pumpDetail(
        tester,
        animalId: animalId,
      );

      await scrollToKey(
        tester,
        const Key('restore-animal-button'),
      );

      await tester.tap(
        find.byKey(
          const Key('restore-animal-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('restore-animal-dialog'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const Key('restore-box-field'),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find
            .text(
              'TM:BOX:33333333-3333-4333-8333-333333333333',
            )
            .last,
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key(
            'confirm-restore-animal-button',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final animal =
          await animalRepository.getAnimalById(
        animalId,
      );

      expect(animal, isNotNull);

      expect(
        animal!.status,
        AnimalStatus.active,
      );

      expect(
        animal.boxId,
        secondBoxId,
      );

      expect(
        animal.archiveReason,
        isNull,
      );

      expect(
        animal.archivedAt,
        isNull,
      );

      expect(
        animal.archiveNotes,
        isNull,
      );

      await scrollToKey(
        tester,
        const Key('archive-animal-button'),
      );

      expect(
        find.byKey(
          const Key('archive-animal-button'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('edit-animal-button'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'animal overview shows active animals only',
    (tester) async {
      final boxId = await createBox(
        'TM:BOX:44444444-4444-4444-8444-444444444444',
      );

      await createAnimal(
        boxId: boxId,
        commonName: 'Active Animal',
      );

      final archivedId = await createAnimal(
        boxId: boxId,
        commonName: 'Archived Animal',
      );

      await animalRepository.archiveAnimal(
        animalId: archivedId,
        reason: AnimalArchiveReason.rehomed,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimalsPage(
            database: database,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Active Animal'),
        findsOneWidget,
      );

      expect(
        find.text('Archived Animal'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'animal overview refreshes after animal is archived',
    (tester) async {
      final boxId = await createBox(
        'TM:BOX:55555555-5555-4555-8555-555555555555',
      );

      final animalId = await createAnimal(
        boxId: boxId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimalsPage(
            database: database,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Corn Snake'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          Key('animal-list-item-$animalId'),
        ),
      );

      await tester.pumpAndSettle();

      await scrollToKey(
        tester,
        const Key('archive-animal-button'),
      );

      await tester.tap(
        find.byKey(
          const Key('archive-animal-button'),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('archive-reason-field'),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Other').last,
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key(
            'confirm-archive-animal-button',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key(
            'archive-information-heading',
          ),
        ),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        find.text('Corn Snake'),
        findsNothing,
      );

      expect(
        find.text('No animals available'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'archived animal cannot be opened for editing',
    (tester) async {
      final boxId = await createBox(
        'TM:BOX:66666666-6666-4666-8666-666666666666',
      );

      final animalId = await createAnimal(
        boxId: boxId,
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.deceased,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimalEditPage(
            database: database,
            animalId: animalId,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Archived animals cannot be edited',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Save'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'restore explains when no boxes are available',
    (tester) async {
      final boxId = await createBox(
        'TM:BOX:77777777-7777-4777-8777-777777777777',
      );

      final animalId = await createAnimal(
        boxId: boxId,
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.sold,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      await boxRepository.deleteBox(boxId);

      await pumpDetail(
        tester,
        animalId: animalId,
      );

      await scrollToKey(
        tester,
        const Key('restore-animal-button'),
      );

      await tester.tap(
        find.byKey(
          const Key('restore-animal-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No Boxes Available'),
        findsOneWidget,
      );

      expect(
        find.text(
          'Create a box before restoring this animal.',
        ),
        findsOneWidget,
      );
    },
  );
}