import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animals;
  late BoxRepository boxes;
  late MediaRepository media;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    animals = AnimalRepository(database);
    boxes = BoxRepository(database);
    media = MediaRepository(database);
  });

  tearDown(() => database.close());

  test(
    'duplicates a Box with independent identity, lifecycle and media',
    () async {
      final pictureId = await media.createMedia(
        fileName: 'source-box.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([1, 2, 3, 4]),
      );
      final sourceId = await boxes.createBox(
        'source-qr',
        name: 'Source Box',
        widthCm: 60,
        heightCm: 45,
        depthCm: 40,
        temperatureZones: 'Warm side 28 °C',
        notes: 'Source notes',
        pictureMediaId: pictureId,
      );
      await boxes.archiveBox(
        boxId: sourceId,
        reason: BoxArchiveReason.replaced,
        archivedAt: DateTime(2026, 9, 14),
        archiveNotes: 'Archived source',
      );

      final duplicateId = await boxes.duplicateBox(
        sourceBoxId: sourceId,
        name: 'Copied Box',
      );
      final source = (await boxes.getBoxById(sourceId))!;
      final duplicate = (await boxes.getBoxById(duplicateId))!;

      expect(duplicate.id, isNot(source.id));
      expect(duplicate.qrId, startsWith('TM:BOX:'));
      expect(duplicate.qrId, isNot(source.qrId));
      expect(duplicate.name, 'Copied Box');
      expect(duplicate.widthCm, source.widthCm);
      expect(duplicate.heightCm, source.heightCm);
      expect(duplicate.depthCm, source.depthCm);
      expect(duplicate.temperatureZones, source.temperatureZones);
      expect(duplicate.notes, source.notes);
      expect(duplicate.status, BoxStatus.active);
      expect(duplicate.archiveReason, isNull);
      expect(duplicate.archivedAt, isNull);
      expect(duplicate.archiveNotes, isNull);
      expect(source.status, BoxStatus.archived);
      expect(source.archiveReason, BoxArchiveReason.replaced);
      expect(duplicate.pictureMediaId, isNotNull);
      expect(duplicate.pictureMediaId, isNot(source.pictureMediaId));
      expect((await media.getMediaById(duplicate.pictureMediaId!))!.data, [
        1,
        2,
        3,
        4,
      ]);

      await boxes.updateBox(
        boxId: duplicateId,
        name: const drift.Value('Independently edited'),
      );
      expect((await boxes.getBoxById(sourceId))!.name, 'Source Box');
      expect(
        (await boxes.getBoxById(duplicateId))!.name,
        'Independently edited',
      );

      await boxes.permanentlyDeleteArchivedBox(sourceId);
      expect(await media.getMediaById(pictureId), isNull);
      expect(await media.getMediaById(duplicate.pictureMediaId!), isNotNull);
    },
  );

  test(
    'duplicates an Animal without lifecycle metadata or feeding history',
    () async {
      final sourceBoxId = await boxes.createBox('source-box');
      final destinationBoxId = await boxes.createBox('destination-box');
      final pictureId = await media.createMedia(
        fileName: 'source-animal.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([5, 6, 7, 8]),
      );
      final sourceId = await animals.createAnimal(
        boxId: sourceBoxId,
        commonName: 'Source Animal',
        latinName: 'Testudo test',
        category: AnimalCategory.reptile,
        subcategory: AnimalSubcategory.turtle,
        sex: Sex.other,
        birthDate: DateTime(2020, 3, 4),
        birthDateAccuracy: BirthDateAccuracy.exact,
        tempMin: 22,
        tempMax: 31,
        nighttimeTemperature: 19,
        humidityMin: 45,
        humidityMax: 70,
        originHabitat: 'Forest',
        weight: '420 g',
        sheddingNotes: 'Complete sheds',
        restOrDormancyPeriods: 'Winter rest',
        pictureMediaId: pictureId,
        notes: 'Profile notes',
        feedingReminderIntervalDays: 7,
        feedingReminderBaseline: DateTime(2026, 9, 1),
      );
      await FeedingRepository(database)
          .addFeeding(sourceId, DateTime(2026, 9, 10), notes: 'Source feeding');
      await animals.archiveAnimal(
        animalId: sourceId,
        reason: AnimalArchiveReason.rehomed,
        archivedAt: DateTime(2026, 9, 14),
        archiveNotes: 'Archived source',
      );

      final duplicateId = await animals.duplicateAnimal(
        sourceAnimalId: sourceId,
        boxId: destinationBoxId,
        commonName: 'Copied Animal',
      );
      final source = (await animals.getAnimalById(sourceId))!;
      final duplicate = (await animals.getAnimalById(duplicateId))!;

      expect(duplicate.id, isNot(source.id));
      expect(duplicate.boxId, destinationBoxId);
      expect(duplicate.status, AnimalStatus.active);
      expect(duplicate.archiveReason, isNull);
      expect(duplicate.archivedAt, isNull);
      expect(duplicate.archiveNotes, isNull);
      expect(duplicate.commonName, 'Copied Animal');
      expect(duplicate.latinName, source.latinName);
      expect(duplicate.category, AnimalCategory.reptile);
      expect(duplicate.subcategory, AnimalSubcategory.turtle);
      expect(duplicate.sex, source.sex);
      expect(duplicate.birthDate, source.birthDate);
      expect(duplicate.birthDateAccuracy, source.birthDateAccuracy);
      expect(duplicate.tempMin, source.tempMin);
      expect(duplicate.tempMax, source.tempMax);
      expect(duplicate.nighttimeTemperature, source.nighttimeTemperature);
      expect(duplicate.humidityMin, source.humidityMin);
      expect(duplicate.humidityMax, source.humidityMax);
      expect(duplicate.originHabitat, source.originHabitat);
      expect(duplicate.weight, source.weight);
      expect(duplicate.sheddingNotes, isNull);
      expect(duplicate.restOrDormancyPeriods, source.restOrDormancyPeriods);
      expect(duplicate.notes, source.notes);
      expect(
        duplicate.feedingReminderIntervalDays,
        source.feedingReminderIntervalDays,
      );
      expect(duplicate.feedingReminderBaseline, source.feedingReminderBaseline);
      expect(duplicate.pictureMediaId, isNot(source.pictureMediaId));
      expect((await media.getMediaById(duplicate.pictureMediaId!))!.data, [
        5,
        6,
        7,
        8,
      ]);
      expect(
        await FeedingRepository(database).getFeedingsForAnimal(duplicateId),
        isEmpty,
      );
      expect(
        await FeedingRepository(database).getFeedingsForAnimal(sourceId),
        hasLength(1),
      );

      await animals.updateAnimal(
        animalId: duplicateId,
        boxId: destinationBoxId,
        commonName: 'Independently edited',
        latinName: duplicate.latinName,
        sex: duplicate.sex,
        birthDate: duplicate.birthDate,
        birthDateAccuracy: duplicate.birthDateAccuracy,
        tempMin: duplicate.tempMin,
        tempMax: duplicate.tempMax,
        humidityMin: duplicate.humidityMin,
        humidityMax: duplicate.humidityMax,
        originHabitat: duplicate.originHabitat,
        weight: duplicate.weight,
        sheddingNotes: duplicate.sheddingNotes,
        restOrDormancyPeriods: duplicate.restOrDormancyPeriods,
        pictureMediaId: duplicate.pictureMediaId,
        notes: duplicate.notes,
        feedingReminderIntervalDays: duplicate.feedingReminderIntervalDays,
        feedingReminderBaseline: duplicate.feedingReminderBaseline,
      );
      expect(
        (await animals.getAnimalById(sourceId))!.commonName,
        'Source Animal',
      );
      final independentlyEdited = (await animals.getAnimalById(duplicateId))!;
      expect(independentlyEdited.category, AnimalCategory.reptile);
      expect(independentlyEdited.subcategory, AnimalSubcategory.turtle);

      await animals.permanentlyDeleteArchivedAnimal(sourceId);
      expect(await media.getMediaById(pictureId), isNull);
      expect(await media.getMediaById(duplicate.pictureMediaId!), isNotNull);
    },
  );

  test('rename operations change only the active record name', () async {
    final boxId = await boxes.createBox('rename-box', name: 'Old Box');
    final animalId = await animals.createAnimal(
      boxId: boxId,
      commonName: 'Old Animal',
      latinName: 'Species unchanged',
      tempMin: 20,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 60,
    );

    expect(await boxes.renameBox(boxId: boxId, name: '  New Box  '), isTrue);
    expect(
      await animals.renameAnimal(
        animalId: animalId,
        commonName: '  New Animal  ',
      ),
      isTrue,
    );
    expect((await boxes.getBoxById(boxId))!.name, 'New Box');
    final animal = (await animals.getAnimalById(animalId))!;
    expect(animal.commonName, 'New Animal');
    expect(animal.latinName, 'Species unchanged');
  });
}
