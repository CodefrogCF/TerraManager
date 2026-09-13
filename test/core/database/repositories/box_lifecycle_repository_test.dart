import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_lifecycle_exception.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';

void main() {
  late AppDatabase database;
  late BoxRepository boxes;
  late AnimalRepository animals;
  final archivedAt = DateTime(2026, 9, 13, 15, 30);

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    boxes = BoxRepository(database);
    animals = AnimalRepository(database);
  });
  tearDown(() => database.close());

  Future<int> createAnimal(int boxId, {String name = 'Snake'}) =>
      animals.createAnimal(
        boxId: boxId,
        commonName: name,
        latinName: 'Test species',
        tempMin: 20,
        tempMax: 30,
        humidityMin: 40,
        humidityMax: 60,
      );

  Future<bool> archive(int id, {String? notes}) => boxes.archiveBox(
    boxId: id,
    reason: BoxArchiveReason.sold,
    archivedAt: archivedAt,
    archiveNotes: notes,
  );

  test(
    'archive retains Box data and restore clears only archive metadata',
    () async {
      final mediaId = await MediaRepository(database).createMedia(
        fileName: 'box.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([1, 2, 3]),
      );
      final id = await boxes.createBoxWithGeneratedQrId(
        name: 'Rainforest',
        widthCm: 60,
        heightCm: 50,
        depthCm: 40,
        notes: 'Ordinary notes',
        pictureMediaId: mediaId,
      );
      final original = (await boxes.getBoxById(id))!;
      expect(
        await archive(id, notes: '  Sold with enclosure\nAdditional context  '),
        isTrue,
      );
      final archived = (await boxes.getBoxByQrId(original.qrId))!;
      expect(archived.status, BoxStatus.archived);
      expect(archived.archiveReason, BoxArchiveReason.sold);
      expect(archived.archivedAt, archivedAt);
      expect(archived.archiveNotes, 'Sold with enclosure\nAdditional context');
      expect(archived.name, original.name);
      expect(archived.widthCm, original.widthCm);
      expect(archived.heightCm, original.heightCm);
      expect(archived.depthCm, original.depthCm);
      expect(archived.notes, original.notes);
      expect(archived.pictureMediaId, original.pictureMediaId);
      expect(archived.createdAt, original.createdAt);
      expect(await boxes.getActiveBoxes(), isEmpty);
      expect((await boxes.getArchivedBoxes()).single.id, id);
      expect((await boxes.getAllBoxes()).single.id, id);
      expect(await boxes.restoreBox(id), isTrue);
      final restored = (await boxes.getBoxById(id))!;
      expect(restored.status, BoxStatus.active);
      expect(restored.archiveReason, isNull);
      expect(restored.archivedAt, isNull);
      expect(restored.archiveNotes, isNull);
      expect(restored.qrId, original.qrId);
      expect(restored.pictureMediaId, original.pictureMediaId);
      expect((await MediaRepository(database).getMediaById(mediaId))!.data, [
        1,
        2,
        3,
      ]);
      expect((await boxes.getActiveBoxes()).single.id, id);
      expect(await boxes.getArchivedBoxes(), isEmpty);
    },
  );

  test(
    'occupied Box reports all active Animals and changes no stored data',
    () async {
      final id = await boxes.createBoxWithGeneratedQrId();
      final first = await createAnimal(id, name: 'First');
      final second = await createAnimal(id, name: 'Second');
      await FeedingRepository(database).addFeeding(first, archivedAt);
      final beforeBox = (await boxes.getBoxById(id))!.toJson();
      final beforeAnimals = (await animals.getAllAnimals())
          .map((animal) => animal.toJson())
          .toList();
      final beforeFeedings = (await FeedingRepository(
        database,
      ).getAllFeedings()).map((feeding) => feeding.toJson()).toList();
      await expectLater(
        archive(id),
        throwsA(
          isA<BoxArchiveBlockedException>().having(
            (error) => error.animals.map((animal) => animal.id),
            'assigned Animals',
            unorderedEquals([first, second]),
          ),
        ),
      );
      expect((await boxes.getBoxById(id))!.toJson(), beforeBox);
      expect(
        (await animals.getAllAnimals()).map((animal) => animal.toJson()),
        beforeAnimals,
      );
      expect(
        (await FeedingRepository(
          database,
        ).getAllFeedings()).map((feeding) => feeding.toJson()),
        beforeFeedings,
      );
    },
  );

  test(
    'archived Animals do not block Box archive and are not restored with it',
    () async {
      final id = await boxes.createBoxWithGeneratedQrId();
      final animalId = await createAnimal(id);
      await animals.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.sold,
        archivedAt: archivedAt,
      );
      final before = (await animals.getAnimalById(animalId))!.toJson();
      expect(await archive(id, notes: '   '), isTrue);
      expect((await boxes.getBoxById(id))!.archiveNotes, isNull);
      expect(await boxes.restoreBox(id), isTrue);
      expect((await animals.getAnimalById(animalId))!.toJson(), before);
    },
  );

  test(
    'duplicate concurrent lifecycle operations cannot overwrite metadata',
    () async {
      final id = await boxes.createBoxWithGeneratedQrId();
      expect(
        await Future.wait([
          archive(id, notes: 'First'),
          archive(id, notes: 'Second'),
        ]),
        [true, false],
      );
      expect((await boxes.getBoxById(id))!.archiveNotes, 'First');
      expect(await Future.wait([boxes.restoreBox(id), boxes.restoreBox(id)]), [
        true,
        false,
      ]);
      final active = (await boxes.getBoxById(id))!;
      expect(active.status, BoxStatus.active);
      expect(active.archivedAt, isNull);
      expect(active.archiveReason, isNull);
      expect(active.archiveNotes, isNull);
      expect(await archive(9999), isFalse);
      expect(await boxes.restoreBox(9999), isFalse);
    },
  );

  test(
    'permanent deletion accepts only archived Boxes and removes picture media',
    () async {
      final mediaId = await MediaRepository(database).createMedia(
        fileName: 'delete.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([4, 5, 6]),
      );
      final id = await boxes.createBoxWithGeneratedQrId(
        pictureMediaId: mediaId,
      );

      expect(await boxes.permanentlyDeleteArchivedBox(id), isFalse);
      expect(await boxes.getBoxById(id), isNotNull);
      expect(await MediaRepository(database).getMediaById(mediaId), isNotNull);

      expect(await archive(id), isTrue);
      expect(await boxes.permanentlyDeleteArchivedBox(id), isTrue);
      expect(await boxes.getBoxById(id), isNull);
      expect(await MediaRepository(database).getMediaById(mediaId), isNull);
      expect(await boxes.permanentlyDeleteArchivedBox(id), isFalse);
    },
  );

  test(
    'create, move and restore Animal all reject archived destination Boxes',
    () async {
      final activeId = await boxes.createBoxWithGeneratedQrId();
      final archivedId = await boxes.createBoxWithGeneratedQrId();
      final animalId = await createAnimal(activeId);
      await archive(archivedId);
      await expectLater(
        createAnimal(archivedId),
        throwsA(isA<BoxAssignmentException>()),
      );
      await expectLater(
        animals.updateAnimal(
          animalId: animalId,
          boxId: archivedId,
          commonName: 'Changed',
          latinName: 'Test species',
          tempMin: 20,
          tempMax: 30,
          humidityMin: 40,
          humidityMax: 60,
        ),
        throwsA(isA<BoxAssignmentException>()),
      );
      expect((await animals.getAnimalById(animalId))!.boxId, activeId);
      expect((await animals.getAnimalById(animalId))!.commonName, 'Snake');
      await animals.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.sold,
        archivedAt: archivedAt,
      );
      await expectLater(
        animals.restoreAnimal(animalId: animalId, boxId: archivedId),
        throwsA(isA<BoxAssignmentException>()),
      );
      expect(
        (await animals.getAnimalById(animalId))!.status,
        AnimalStatus.archived,
      );
      expect((await animals.getAllAnimals()), hasLength(1));
      await boxes.restoreBox(archivedId);
      expect(
        await animals.restoreAnimal(animalId: animalId, boxId: archivedId),
        isTrue,
      );
    },
  );

  for (final archiveFirst in [true, false]) {
    test(
      'concurrent assignment and archive remain consistent (archive first: $archiveFirst)',
      () async {
        final id = await boxes.createBoxWithGeneratedQrId();
        Future<Object> capture(Future<Object> operation) async {
          try {
            return await operation;
          } catch (error) {
            return error;
          }
        }

        final operations = archiveFirst
            ? [capture(archive(id)), capture(createAnimal(id))]
            : [capture(createAnimal(id)), capture(archive(id))];
        final outcomes = await Future.wait(operations);
        final box = (await boxes.getBoxById(id))!;
        final assigned = await animals.getAnimalsForBox(id);
        if (box.status == BoxStatus.archived) {
          expect(assigned, isEmpty);
          expect(outcomes.whereType<BoxAssignmentException>(), hasLength(1));
        } else {
          expect(assigned, hasLength(1));
          expect(assigned.single.status, AnimalStatus.active);
          expect(
            outcomes.whereType<BoxArchiveBlockedException>(),
            hasLength(1),
          );
        }
      },
    );
  }
}
