import 'package:drift/drift.dart';

import '../app_database.dart';
import '../enums/animal_archive_reason.dart';
import '../enums/animal_category.dart';
import '../enums/animal_status.dart';
import '../enums/birth_date_accuracy.dart';
import '../enums/sex.dart';
import '../enums/box_status.dart';
import '../validation/animal_environmental_limits.dart';
import 'box_lifecycle_exception.dart';
import 'picture_gallery_repository.dart';

class AnimalRepository {
  final AppDatabase database;

  AnimalRepository(this.database);

  Future<List<Animal>> getAllAnimals() {
    return database.select(database.animals).get();
  }

  Future<List<Animal>> getActiveAnimals() {
    final query = database.select(database.animals)
      ..where((animal) => animal.status.equalsValue(AnimalStatus.active));

    return query.get();
  }

  Future<List<Animal>> getActiveAnimalsWithFeedingReminders() {
    final query = database.select(database.animals)
      ..where(
        (animal) =>
            animal.status.equalsValue(AnimalStatus.active) &
            animal.feedingReminderIntervalDays.isNotNull() &
            animal.feedingReminderIntervalDays.isBiggerThanValue(0) &
            animal.feedingReminderBaseline.isNotNull(),
      );

    return query.get();
  }

  Future<List<Animal>> getArchivedAnimals() {
    final query = database.select(database.animals)
      ..where((animal) => animal.status.equalsValue(AnimalStatus.archived))
      ..orderBy([(animal) => OrderingTerm.desc(animal.archivedAt)]);

    return query.get();
  }

  Future<Animal?> getAnimalById(int id) {
    final query = database.select(database.animals)
      ..where((animal) => animal.id.equals(id));

    return query.getSingleOrNull();
  }

  Future<List<Animal>> getAnimalsForBox(int boxId) {
    final query = database.select(database.animals)
      ..where(
        (animal) =>
            animal.boxId.equals(boxId) &
            animal.status.equalsValue(AnimalStatus.active),
      );

    return query.get();
  }

  Future<int> createAnimal({
    required int boxId,
    required String commonName,
    required String latinName,
    AnimalCategory category = AnimalCategory.other,
    AnimalSubcategory? subcategory,
    Sex? sex,
    DateTime? birthDate,
    BirthDateAccuracy? birthDateAccuracy,
    required double tempMin,
    required double tempMax,
    double? nighttimeTemperature,
    required double humidityMin,
    required double humidityMax,
    String? originHabitat,
    String? weight,
    String? sheddingNotes,
    String? restOrDormancyPeriods,
    int? pictureMediaId,
    String? picturePath,
    String? notes,
    int? feedingReminderIntervalDays,
    DateTime? feedingReminderBaseline,
  }) {
    AnimalEnvironmentalLimits.validate(
      temperatureMinimum: tempMin,
      temperatureMaximum: tempMax,
      nighttimeTemperature: nighttimeTemperature,
      humidityMinimum: humidityMin,
      humidityMaximum: humidityMax,
    );
    _validateFeedingReminder(
      intervalDays: feedingReminderIntervalDays,
      baseline: feedingReminderBaseline,
    );
    _validateTaxonomy(category, subcategory);

    return database.transaction(() async {
      await _requireActiveBox(boxId);
      final animalId = await database
          .into(database.animals)
          .insert(
            AnimalsCompanion.insert(
              boxId: Value(boxId),
              commonName: commonName,
              latinName: latinName,
              category: Value(category),
              subcategory: Value.absentIfNull(subcategory),
              sex: Value.absentIfNull(sex),
              birthDate: Value.absentIfNull(birthDate),
              birthDateAccuracy: Value.absentIfNull(birthDateAccuracy),
              tempMin: tempMin,
              tempMax: tempMax,
              nighttimeTemperature: Value.absentIfNull(nighttimeTemperature),
              humidityMin: humidityMin,
              humidityMax: humidityMax,
              originHabitat: Value.absentIfNull(originHabitat),
              weight: Value.absentIfNull(weight),
              sheddingNotes: Value.absentIfNull(sheddingNotes),
              restOrDormancyPeriods: Value.absentIfNull(restOrDormancyPeriods),
              pictureMediaId: Value.absentIfNull(pictureMediaId),
              picturePath: Value.absentIfNull(picturePath),
              notes: Value.absentIfNull(notes),
              feedingReminderIntervalDays: Value.absentIfNull(
                feedingReminderIntervalDays,
              ),
              feedingReminderBaseline: Value.absentIfNull(
                feedingReminderBaseline,
              ),
            ),
          );
      if (pictureMediaId != null) {
        await PictureGalleryRepository(database).ensureAnimalPictureAssociation(
          animalId: animalId,
          mediaId: pictureMediaId,
        );
      }
      return animalId;
    });
  }

  Future<bool> renameAnimal({
    required int animalId,
    required String commonName,
  }) async {
    final normalizedName = commonName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        commonName,
        'commonName',
        'Common name must not be empty.',
      );
    }

    final updatedRows =
        await (database.update(database.animals)..where(
              (animal) =>
                  animal.id.equals(animalId) &
                  animal.status.equalsValue(AnimalStatus.active),
            ))
            .write(
              AnimalsCompanion(
                commonName: Value(normalizedName),
                updatedAt: Value(DateTime.now()),
              ),
            );

    return updatedRows == 1;
  }

  Future<int> duplicateAnimal({
    required int sourceAnimalId,
    required int boxId,
    required String commonName,
  }) async {
    final normalizedName = commonName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        commonName,
        'commonName',
        'Common name must not be empty.',
      );
    }

    return database.transaction(() async {
      final source = await getAnimalById(sourceAnimalId);
      if (source == null) {
        throw StateError('Animal $sourceAnimalId does not exist');
      }

      await _requireActiveBox(boxId);
      AnimalEnvironmentalLimits.validate(
        temperatureMinimum: source.tempMin,
        temperatureMaximum: source.tempMax,
        nighttimeTemperature: source.nighttimeTemperature,
        humidityMinimum: source.humidityMin,
        humidityMaximum: source.humidityMax,
      );
      _validateFeedingReminder(
        intervalDays: source.feedingReminderIntervalDays,
        baseline: source.feedingReminderBaseline,
      );

      final galleryRepository = PictureGalleryRepository(database);
      if (source.pictureMediaId != null) {
        await galleryRepository.ensureAnimalPictureAssociation(
          animalId: source.id,
          mediaId: source.pictureMediaId!,
          makePrimary: false,
        );
      }

      final targetAnimalId = await database
          .into(database.animals)
          .insert(
            AnimalsCompanion.insert(
              boxId: Value(boxId),
              commonName: normalizedName,
              latinName: source.latinName,
              category: Value(source.category),
              subcategory: Value.absentIfNull(source.subcategory),
              sex: Value.absentIfNull(source.sex),
              birthDate: Value.absentIfNull(source.birthDate),
              birthDateAccuracy: Value.absentIfNull(source.birthDateAccuracy),
              tempMin: source.tempMin,
              tempMax: source.tempMax,
              nighttimeTemperature: Value.absentIfNull(
                source.nighttimeTemperature,
              ),
              humidityMin: source.humidityMin,
              humidityMax: source.humidityMax,
              originHabitat: Value.absentIfNull(source.originHabitat),
              weight: Value.absentIfNull(source.weight),
              sheddingNotes: Value.absentIfNull(source.sheddingNotes),
              restOrDormancyPeriods: Value.absentIfNull(
                source.restOrDormancyPeriods,
              ),
              picturePath: source.pictureMediaId == null
                  ? Value.absentIfNull(source.picturePath)
                  : const Value.absent(),
              notes: Value.absentIfNull(source.notes),
              feedingReminderIntervalDays: Value.absentIfNull(
                source.feedingReminderIntervalDays,
              ),
              feedingReminderBaseline: Value.absentIfNull(
                source.feedingReminderBaseline,
              ),
            ),
          );
      await galleryRepository.duplicateAnimalGallery(
        sourceAnimalId: source.id,
        targetAnimalId: targetAnimalId,
      );
      return targetAnimalId;
    });
  }

  Future<bool> updateAnimal({
    required int animalId,
    required int boxId,
    required String commonName,
    required String latinName,
    AnimalCategory? category,
    AnimalSubcategory? subcategory,
    Sex? sex,
    DateTime? birthDate,
    BirthDateAccuracy? birthDateAccuracy,
    required double tempMin,
    required double tempMax,
    double? nighttimeTemperature,
    required double humidityMin,
    required double humidityMax,
    String? originHabitat,
    String? weight,
    String? sheddingNotes,
    String? restOrDormancyPeriods,
    int? pictureMediaId,
    String? picturePath,
    String? notes,
    int? feedingReminderIntervalDays,
    DateTime? feedingReminderBaseline,
  }) async {
    AnimalEnvironmentalLimits.validate(
      temperatureMinimum: tempMin,
      temperatureMaximum: tempMax,
      nighttimeTemperature: nighttimeTemperature,
      humidityMinimum: humidityMin,
      humidityMaximum: humidityMax,
    );
    _validateFeedingReminder(
      intervalDays: feedingReminderIntervalDays,
      baseline: feedingReminderBaseline,
    );
    if (category != null) {
      _validateTaxonomy(category, subcategory);
    } else if (subcategory != null) {
      throw ArgumentError.value(
        subcategory,
        'subcategory',
        'A subcategory update requires a category.',
      );
    }

    return database.transaction(() async {
      await _requireActiveBox(boxId);
      final updatedRows =
          await (database.update(database.animals)..where(
                (animal) =>
                    animal.id.equals(animalId) &
                    animal.status.equalsValue(AnimalStatus.active),
              ))
              .write(
                AnimalsCompanion(
                  boxId: Value(boxId),
                  commonName: Value(commonName),
                  latinName: Value(latinName),
                  category: category == null
                      ? const Value.absent()
                      : Value(category),
                  subcategory: category == null
                      ? const Value.absent()
                      : Value(subcategory),
                  sex: Value(sex),
                  birthDate: Value(birthDate),
                  birthDateAccuracy: Value(birthDateAccuracy),
                  tempMin: Value(tempMin),
                  tempMax: Value(tempMax),
                  nighttimeTemperature: Value(nighttimeTemperature),
                  humidityMin: Value(humidityMin),
                  humidityMax: Value(humidityMax),
                  originHabitat: Value(originHabitat),
                  weight: Value(weight),
                  sheddingNotes: Value(sheddingNotes),
                  restOrDormancyPeriods: Value(restOrDormancyPeriods),
                  pictureMediaId: Value(pictureMediaId),
                  picturePath: Value(picturePath),
                  notes: Value(notes),
                  feedingReminderIntervalDays: Value(
                    feedingReminderIntervalDays,
                  ),
                  feedingReminderBaseline: Value(feedingReminderBaseline),
                  updatedAt: Value(DateTime.now()),
                ),
              );

      if (updatedRows > 0 && pictureMediaId != null) {
        await PictureGalleryRepository(database).ensureAnimalPictureAssociation(
          animalId: animalId,
          mediaId: pictureMediaId,
        );
      }
      return updatedRows > 0;
    });
  }

  Future<bool> updateFeedingReminder({
    required int animalId,
    required int? intervalDays,
    required DateTime? baseline,
  }) async {
    _validateFeedingReminder(intervalDays: intervalDays, baseline: baseline);

    final updatedRows =
        await (database.update(database.animals)..where(
              (animal) =>
                  animal.id.equals(animalId) &
                  animal.status.equalsValue(AnimalStatus.active),
            ))
            .write(
              AnimalsCompanion(
                feedingReminderIntervalDays: Value(intervalDays),
                feedingReminderBaseline: Value(baseline),
                updatedAt: Value(DateTime.now()),
              ),
            );

    return updatedRows > 0;
  }

  Future<bool> archiveAnimal({
    required int animalId,
    required AnimalArchiveReason reason,
    required DateTime archivedAt,
    String? archiveNotes,
  }) async {
    final normalizedNotes = archiveNotes?.trim();

    final updatedRows =
        await (database.update(database.animals)..where(
              (animal) =>
                  animal.id.equals(animalId) &
                  animal.status.equalsValue(AnimalStatus.active),
            ))
            .write(
              AnimalsCompanion(
                boxId: const Value(null),
                status: const Value(AnimalStatus.archived),
                archiveReason: Value(reason),
                archivedAt: Value(archivedAt),
                archiveNotes: Value(
                  normalizedNotes == null || normalizedNotes.isEmpty
                      ? null
                      : normalizedNotes,
                ),
                updatedAt: Value(DateTime.now()),
              ),
            );

    return updatedRows > 0;
  }

  Future<bool> restoreAnimal({
    required int animalId,
    required int boxId,
  }) async {
    return database.transaction(() async {
      await _requireActiveBox(boxId);

      final updatedRows =
          await (database.update(database.animals)..where(
                (animal) =>
                    animal.id.equals(animalId) &
                    animal.status.equalsValue(AnimalStatus.archived),
              ))
              .write(
                AnimalsCompanion(
                  boxId: Value(boxId),
                  status: const Value(AnimalStatus.active),
                  archiveReason: const Value(null),
                  archivedAt: const Value(null),
                  archiveNotes: const Value(null),
                  updatedAt: Value(DateTime.now()),
                ),
              );

      return updatedRows > 0;
    });
  }

  Future<bool> permanentlyDeleteArchivedAnimal(int animalId) {
    return database.transaction(() async {
      final animal = await getAnimalById(animalId);

      if (animal == null || animal.status != AnimalStatus.archived) {
        return false;
      }

      final galleryRepository = PictureGalleryRepository(database);
      final mediaIds = await galleryRepository.getAnimalGalleryMediaIds(
        animalId,
      );
      if (animal.pictureMediaId != null) {
        mediaIds.add(animal.pictureMediaId!);
      }

      await (database.delete(
        database.feedingEvents,
      )..where((event) => event.animalId.equals(animalId))).go();

      final deletedRows =
          await (database.delete(database.animals)..where(
                (animal) =>
                    animal.id.equals(animalId) &
                    animal.status.equalsValue(AnimalStatus.archived),
              ))
              .go();

      if (deletedRows != 1) {
        return false;
      }

      await galleryRepository.deleteUnreferencedMedia(mediaIds);

      return true;
    });
  }

  Future<bool> deleteAnimal(int id) {
    return database.transaction(() async {
      final animal = await getAnimalById(id);

      if (animal == null) {
        return false;
      }

      final galleryRepository = PictureGalleryRepository(database);
      final mediaIds = await galleryRepository.getAnimalGalleryMediaIds(id);
      if (animal.pictureMediaId != null) {
        mediaIds.add(animal.pictureMediaId!);
      }

      final deletedRows = await (database.delete(
        database.animals,
      )..where((animal) => animal.id.equals(id))).go();

      if (deletedRows != 1) {
        return false;
      }

      await galleryRepository.deleteUnreferencedMedia(mediaIds);

      return true;
    });
  }

  Future<void> _requireActiveBox(int boxId) async {
    final box =
        await (database.select(database.boxes)..where(
              (box) =>
                  box.id.equals(boxId) &
                  box.status.equalsValue(BoxStatus.active),
            ))
            .getSingleOrNull();
    if (box == null) {
      throw BoxAssignmentException(boxId);
    }
  }

  static void _validateTaxonomy(
    AnimalCategory category,
    AnimalSubcategory? subcategory,
  ) {
    if (!category.supports(subcategory)) {
      throw ArgumentError.value(
        subcategory,
        'subcategory',
        'Subcategory does not belong to ${category.name}.',
      );
    }
  }

  static void _validateFeedingReminder({
    required int? intervalDays,
    required DateTime? baseline,
  }) {
    if (intervalDays == null && baseline == null) {
      return;
    }

    if (intervalDays == null || baseline == null) {
      throw ArgumentError(
        'A feeding reminder requires both an interval and a baseline.',
      );
    }

    if (intervalDays <= 0) {
      throw ArgumentError.value(
        intervalDays,
        'feedingReminderIntervalDays',
        'Reminder interval must be greater than zero.',
      );
    }
  }
}
