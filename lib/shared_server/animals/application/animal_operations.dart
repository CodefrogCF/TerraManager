import 'dart:async';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/feedings/domain/feeding_weekday_schedule.dart';
import 'package:terramanager/shared_server/animals/application/animal_command.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class AnimalOperations extends CollectionOperations {
  AnimalOperations(super.database);
  Future<Animal?> getAnimalById(int id) =>
      AnimalRepository(database).getAnimalById(id);
  Future<ApiReply> list() async {
    final animals = AnimalRepository(database);

    final records = await animals.getAllAnimals();
    final latest = await FeedingRepository(database)
        .getLatestFeedingTimes(records.map((animal) => animal.id));
    return ApiReply(200, {
      'animals': [
        for (final animal in records)
          {
            ...animalJson(animal),
            'latestFeedingAt': latest[animal.id]?.toUtc().toIso8601String(),
          },
      ],
    });
  }

  Future<ApiReply> create(ApiInput input) async {
    final animals = AnimalRepository(database);

    final data = AnimalCommand.fromInput(input, creating: true);
    await requireMedia(data.pictureMediaId);
    final id = await animals.createAnimal(
      boxId: data.boxId,
      commonName: data.commonName,
      latinName: data.latinName,
      category: data.category,
      subcategory: data.subcategory,
      sex: data.sex,
      birthDate: data.birthDate,
      birthDateAccuracy: data.birthDateAccuracy,
      tempMin: data.tempMin,
      tempMax: data.tempMax,
      nighttimeTemperatureMin: data.nighttimeTemperatureMin,
      nighttimeTemperatureMax: data.nighttimeTemperatureMax,
      humidityMin: data.humidityMin,
      humidityMax: data.humidityMax,
      originHabitat: data.originHabitat,
      restOrDormancyPeriods: data.restOrDormancyPeriods,
      notes: data.notes,
      pictureMediaId: data.pictureMediaId,
      feedingReminderIntervalDays: data.feedingReminderIntervalDays,
      feedingReminderBaseline: data.feedingReminderBaseline,
      feedingReminderWeekdays: data.feedingReminderWeekdays,
      feedingReminderMinuteOfDay: data.feedingReminderMinuteOfDay,
      feedingReminderTimeZone: data.feedingReminderTimeZone,
      weightGrams: data.weightGrams,
      weightMeasuredAt: data.weightMeasuredAt,
      showWeightOnDetail: data.showWeightOnDetail,
      showSheddingOnDetail: data.showSheddingOnDetail,
    );
    return ApiReply(201, {
      'animal': animalJson((await animals.getAnimalById(id))!),
    });
  }

  Future<ApiReply> duplicate(int id, ApiInput input) async {
    final animals = AnimalRepository(database);

    input.allow(const {'boxId', 'commonName'});
    final newId = await animals.duplicateAnimal(
      sourceAnimalId: id,
      boxId: input.integer('boxId'),
      commonName: input.string('commonName'),
    );
    return ApiReply(201, {
      'animal': animalJson((await animals.getAnimalById(newId))!),
    });
  }

  Future<ApiReply> update(int id, Animal existing, ApiInput input) async {
    final animals = AnimalRepository(database);

    if (existing.status != AnimalStatus.active) {
      return apiError(409, 'conflict', 'Only active Animals can be edited.');
    }

    final expectedRevision = input.string('expectedRevision', maxLength: 64);
    input.values.remove('expectedRevision');
    final data = AnimalCommand.fromInput(input);
    await requireMedia(data.pictureMediaId);
    final updated = await database.transaction(() async {
      final current = await animals.getAnimalById(id);
      requireRevision(
        current == null ? null : animalJson(current),
        expectedRevision,
      );
      return animals.updateAnimal(
        animalId: id,
        boxId: data.boxId,
        commonName: data.commonName,
        latinName: data.latinName,
        category: data.category,
        subcategory: data.subcategory,
        sex: data.sex,
        birthDate: data.birthDate,
        birthDateAccuracy: data.birthDateAccuracy,
        tempMin: data.tempMin,
        tempMax: data.tempMax,
        nighttimeTemperatureMin: data.nighttimeTemperatureMin,
        nighttimeTemperatureMax: data.nighttimeTemperatureMax,
        humidityMin: data.humidityMin,
        humidityMax: data.humidityMax,
        originHabitat: data.originHabitat,
        restOrDormancyPeriods: data.restOrDormancyPeriods,
        notes: data.notes,
        pictureMediaId: data.pictureMediaId,
        feedingReminderIntervalDays: data.feedingReminderIntervalDays,
        feedingReminderBaseline: data.feedingReminderBaseline,
        feedingReminderWeekdays: data.feedingReminderWeekdays,
        feedingReminderMinuteOfDay: data.feedingReminderMinuteOfDay,
        feedingReminderTimeZone: data.feedingReminderTimeZone,
        weightGrams: data.weightGrams,
        weightMeasuredAt: data.weightMeasuredAt,
        showWeightOnDetail: data.showWeightOnDetail,
        showSheddingOnDetail: data.showSheddingOnDetail,
      );
    });
    return updated
        ? ApiReply(200, {
            'animal': animalJson((await animals.getAnimalById(id))!),
          })
        : apiError(409, 'conflict', 'Animal could not be updated.');
  }

  Future<ApiReply> updateReminder(int id, ApiInput input) async {
    final animals = AnimalRepository(database);

    input.allow(const {
      'expectedRevision',
      'intervalDays',
      'baseline',
      'weekdays',
      'minuteOfDay',
      'timeZone',
    });
    final expectedRevision = input.string('expectedRevision', maxLength: 64);
    final intervalDays = input.nullableInteger('intervalDays');
    final baseline = input.nullableDateTime('baseline');
    final weekdays = input.nullableInteger('weekdays');
    final minuteOfDay = input.nullableInteger('minuteOfDay');
    final timeZone = input.nullableString('timeZone');
    try {
      FeedingWeekdaySchedule.validate(
        intervalDays: intervalDays,
        baseline: baseline,
        weekdays: weekdays,
        minuteOfDay: minuteOfDay,
        timeZone: timeZone,
      );
    } on ArgumentError {
      throw const ApiProblem(
        400,
        'invalid_data',
        'Invalid feeding reminder configuration.',
      );
    }
    final updated = await database.transaction(() async {
      final current = await animals.getAnimalById(id);
      requireRevision(
        current == null ? null : animalJson(current),
        expectedRevision,
      );
      return animals.updateFeedingReminder(
        animalId: id,
        intervalDays: intervalDays,
        baseline: baseline,
        weekdays: weekdays,
        minuteOfDay: minuteOfDay,
        timeZone: timeZone,
      );
    });
    return updated
        ? ApiReply(200, {
            'animal': animalJson((await animals.getAnimalById(id))!),
          })
        : apiError(409, 'conflict', 'Only active Animals can be edited.');
  }

  Future<ApiReply> move(int id, ApiInput input) async {
    final animals = AnimalRepository(database);

    input.allow(const {'boxId', 'expectedRevision'});
    final boxId = input.integer('boxId');
    final expectedRevision = input.nullableString(
      'expectedRevision',
      maxLength: 64,
    );
    final moved = await database.transaction(() async {
      if (expectedRevision != null) {
        final current = await animals.getAnimalById(id);
        requireRevision(
          current == null ? null : animalJson(current),
          expectedRevision,
        );
      }
      return animals.moveAnimalToBox(animalId: id, boxId: boxId);
    });
    return moved
        ? ApiReply(200, {
            'animal': animalJson((await animals.getAnimalById(id))!),
          })
        : apiError(409, 'conflict', 'Animal cannot move to that Box.');
  }

  Future<ApiReply> archive(int id, ApiInput input) async {
    final animals = AnimalRepository(database);

    input.allow(const {'reason', 'archivedAt', 'archiveNotes'});
    final archived = await animals.archiveAnimal(
      animalId: id,
      reason: input.enumerated('reason', AnimalArchiveReason.values),
      archivedAt: input.dateTime('archivedAt', fallback: DateTime.now()),
      archiveNotes: input.nullableString('archiveNotes'),
    );
    return archived
        ? ApiReply(200, {
            'animal': animalJson((await animals.getAnimalById(id))!),
          })
        : apiError(409, 'conflict', 'Animal is not active.');
  }

  Future<ApiReply> restore(int id, ApiInput input) async {
    final animals = AnimalRepository(database);

    input.allow(const {'boxId'});
    final restored = await animals.restoreAnimal(
      animalId: id,
      boxId: input.integer('boxId'),
    );
    return restored
        ? ApiReply(200, {
            'animal': animalJson((await animals.getAnimalById(id))!),
          })
        : apiError(409, 'conflict', 'Animal is not archived.');
  }

  Future<ApiReply> delete(int id) async {
    final animals = AnimalRepository(database);

    final deleted = await animals.permanentlyDeleteArchivedAnimal(id);
    return deleted
        ? ApiReply(200, {'deleted': true})
        : apiError(409, 'conflict', 'Only archived Animals can be deleted.');
  }
}
