import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';

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

  Future<int> createAnimal(
    int boxId, {
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

  test(
    'new animal is active by default',
    () async {
      final boxId = await createBox(
        'TM:BOX:11111111-1111-4111-8111-111111111111',
      );

      final animalId = await createAnimal(
        boxId,
      );

      final animal = await animalRepository.getAnimalById(
        animalId,
      );

      expect(animal, isNotNull);

      expect(
        animal!.status,
        AnimalStatus.active,
      );

      expect(
        animal.boxId,
        boxId,
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
    },
  );

  test(
    'archive removes animal from box and preserves record',
    () async {
      final boxId = await createBox(
        'TM:BOX:22222222-2222-4222-8222-222222222222',
      );

      final animalId = await createAnimal(
        boxId,
      );

      final archivedAt = DateTime(
        2026,
        9,
        1,
        12,
        0,
      );

      final archived = await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.sold,
        archivedAt: archivedAt,
        archiveNotes: 'Transferred to new owner',
      );

      expect(
        archived,
        isTrue,
      );

      final animal = await animalRepository.getAnimalById(
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
        archivedAt,
      );

      expect(
        animal.archiveNotes,
        'Transferred to new owner',
      );
    },
  );

  test(
    'archive trims archive notes',
    () async {
      final boxId = await createBox(
        'TM:BOX:33333333-3333-4333-8333-333333333333',
      );

      final animalId = await createAnimal(
        boxId,
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.other,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
        archiveNotes: '  Example note  ',
      );

      final animal = await animalRepository.getAnimalById(
        animalId,
      );

      expect(
        animal!.archiveNotes,
        'Example note',
      );
    },
  );

  test(
    'empty archive note is stored as null',
    () async {
      final boxId = await createBox(
        'TM:BOX:44444444-4444-4444-8444-444444444444',
      );

      final animalId = await createAnimal(
        boxId,
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.other,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
        archiveNotes: '   ',
      );

      final animal = await animalRepository.getAnimalById(
        animalId,
      );

      expect(
        animal!.archiveNotes,
        isNull,
      );
    },
  );

  test(
    'archived animal is excluded from box animals',
    () async {
      final boxId = await createBox(
        'TM:BOX:55555555-5555-4555-8555-555555555555',
      );

      final animalId = await createAnimal(
        boxId,
      );

      expect(
        await animalRepository.getAnimalsForBox(
          boxId,
        ),
        hasLength(1),
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.rehomed,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      expect(
        await animalRepository.getAnimalsForBox(
          boxId,
        ),
        isEmpty,
      );
    },
  );

  test(
    'active and archived queries return separate animals',
    () async {
      final boxId = await createBox(
        'TM:BOX:66666666-6666-4666-8666-666666666666',
      );

      await createAnimal(
        boxId,
        commonName: 'Active Animal',
      );

      final archivedId = await createAnimal(
        boxId,
        commonName: 'Archived Animal',
      );

      await animalRepository.archiveAnimal(
        animalId: archivedId,
        reason: AnimalArchiveReason.traded,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      final active = await animalRepository.getActiveAnimals();
      final archived = await animalRepository.getArchivedAnimals();

      expect(
        active,
        hasLength(1),
      );

      expect(
        active.single.commonName,
        'Active Animal',
      );

      expect(
        archived,
        hasLength(1),
      );

      expect(
        archived.single.commonName,
        'Archived Animal',
      );
    },
  );

  test(
    'restore assigns archived animal to selected box',
    () async {
      final firstBoxId = await createBox(
        'TM:BOX:77777777-7777-4777-8777-777777777777',
      );

      final secondBoxId = await createBox(
        'TM:BOX:88888888-8888-4888-8888-888888888888',
      );

      final animalId = await createAnimal(
        firstBoxId,
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.sold,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
        archiveNotes: 'Test note',
      );

      final restored = await animalRepository.restoreAnimal(
        animalId: animalId,
        boxId: secondBoxId,
      );

      expect(
        restored,
        isTrue,
      );

      final animal = await animalRepository.getAnimalById(
        animalId,
      );

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
    },
  );

  test(
    'restore fails when target box does not exist',
    () async {
      final boxId = await createBox(
        'TM:BOX:99999999-9999-4999-8999-999999999999',
      );

      final animalId = await createAnimal(
        boxId,
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.other,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      expect(
        () => animalRepository.restoreAnimal(
          animalId: animalId,
          boxId: 999999,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'normal update cannot modify archived animal',
    () async {
      final boxId = await createBox(
        'TM:BOX:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );

      final animalId = await createAnimal(
        boxId,
        commonName: 'Original Name',
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.other,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      final updated = await animalRepository.updateAnimal(
        animalId: animalId,
        boxId: boxId,
        commonName: 'Changed Name',
        latinName: 'Pantherophis guttatus',
        tempMin: 24,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 60,
      );

      expect(
        updated,
        isFalse,
      );

      final animal = await animalRepository.getAnimalById(
        animalId,
      );

      expect(
        animal!.status,
        AnimalStatus.archived,
      );

      expect(
        animal.boxId,
        isNull,
      );

      expect(
        animal.commonName,
        'Original Name',
      );
    },
  );

  test(
    'archived animal cannot be archived again',
    () async {
      final boxId = await createBox(
        'TM:BOX:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );

      final animalId = await createAnimal(
        boxId,
      );

      final firstResult = await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.sold,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      final secondResult = await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.traded,
        archivedAt: DateTime(
          2026,
          9,
          2,
        ),
      );

      expect(
        firstResult,
        isTrue,
      );

      expect(
        secondResult,
        isFalse,
      );

      final animal = await animalRepository.getAnimalById(
        animalId,
      );

      expect(
        animal!.archiveReason,
        AnimalArchiveReason.sold,
      );
    },
  );

  test(
    'active animal cannot be restored',
    () async {
      final firstBoxId = await createBox(
        'TM:BOX:cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      );

      final secondBoxId = await createBox(
        'TM:BOX:dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      );

      final animalId = await createAnimal(
        firstBoxId,
      );

      final restored = await animalRepository.restoreAnimal(
        animalId: animalId,
        boxId: secondBoxId,
      );

      expect(
        restored,
        isFalse,
      );

      final animal = await animalRepository.getAnimalById(
        animalId,
      );

      expect(
        animal!.status,
        AnimalStatus.active,
      );

      expect(
        animal.boxId,
        firstBoxId,
      );
    },
  );

  test(
    'permanent deletion removes archived animal and feeding history',
    () async {
      final boxId = await createBox(
        'TM:BOX:eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      );

      final animalId = await createAnimal(
        boxId,
        commonName: 'Archived Animal',
      );

      await database
          .into(database.feedingEvents)
          .insert(
            FeedingEventsCompanion.insert(
              animalId: animalId,
              fedAt: DateTime(
                2026,
                9,
                1,
                18,
                0,
              ),
              notes: const drift.Value(
                'Existing feeding',
              ),
            ),
          );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.sold,
        archivedAt: DateTime(
          2026,
          9,
          2,
        ),
      );

      final deleted =
          await animalRepository
              .permanentlyDeleteArchivedAnimal(
        animalId,
      );

      expect(
        deleted,
        isTrue,
      );

      expect(
        await animalRepository.getAnimalById(
          animalId,
        ),
        isNull,
      );

      final feedings =
          await (database.select(
        database.feedingEvents,
      )..where(
                  (event) =>
                      event.animalId.equals(
                        animalId,
                      ),
                ))
              .get();

      expect(
        feedings,
        isEmpty,
      );
    },
  );

  test(
    'permanent deletion rejects active animal and preserves feeding history',
    () async {
      final boxId = await createBox(
        'TM:BOX:ffffffff-ffff-4fff-8fff-ffffffffffff',
      );

      final animalId = await createAnimal(
        boxId,
        commonName: 'Active Animal',
      );

      await database
          .into(database.feedingEvents)
          .insert(
            FeedingEventsCompanion.insert(
              animalId: animalId,
              fedAt: DateTime(
                2026,
                9,
                1,
                18,
                0,
              ),
              notes: const drift.Value(
                'Must survive',
              ),
            ),
          );

      final deleted =
          await animalRepository
              .permanentlyDeleteArchivedAnimal(
        animalId,
      );

      expect(
        deleted,
        isFalse,
      );

      final animal =
          await animalRepository.getAnimalById(
        animalId,
      );

      expect(
        animal,
        isNotNull,
      );

      expect(
        animal!.status,
        AnimalStatus.active,
      );

      final feedings =
          await (database.select(
        database.feedingEvents,
      )..where(
                  (event) =>
                      event.animalId.equals(
                        animalId,
                      ),
                ))
              .get();

      expect(
        feedings,
        hasLength(1),
      );
    },
  );
}