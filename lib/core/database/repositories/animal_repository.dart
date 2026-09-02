import 'package:drift/drift.dart';

import '../app_database.dart';
import '../enums/animal_archive_reason.dart';
import '../enums/animal_status.dart';
import '../enums/birth_date_accuracy.dart';
import '../enums/sex.dart';

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
    Sex? sex,
    DateTime? birthDate,
    BirthDateAccuracy? birthDateAccuracy,
    required double tempMin,
    required double tempMax,
    required double humidityMin,
    required double humidityMax,
    int? pictureMediaId,
    String? picturePath,
    String? notes,
  }) {
    return database
        .into(database.animals)
        .insert(
          AnimalsCompanion.insert(
            boxId: Value(boxId),
            commonName: commonName,
            latinName: latinName,
            sex: Value.absentIfNull(sex),
            birthDate: Value.absentIfNull(birthDate),
            birthDateAccuracy: Value.absentIfNull(birthDateAccuracy),
            tempMin: tempMin,
            tempMax: tempMax,
            humidityMin: humidityMin,
            humidityMax: humidityMax,
            pictureMediaId: Value.absentIfNull(pictureMediaId),
            picturePath: Value.absentIfNull(picturePath),
            notes: Value.absentIfNull(notes),
          ),
        );
  }

  Future<bool> updateAnimal({
    required int animalId,
    required int boxId,
    required String commonName,
    required String latinName,
    Sex? sex,
    DateTime? birthDate,
    BirthDateAccuracy? birthDateAccuracy,
    required double tempMin,
    required double tempMax,
    required double humidityMin,
    required double humidityMax,
    int? pictureMediaId,
    String? picturePath,
    String? notes,
  }) async {
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
                sex: Value(sex),
                birthDate: Value(birthDate),
                birthDateAccuracy: Value(birthDateAccuracy),
                tempMin: Value(tempMin),
                tempMax: Value(tempMax),
                humidityMin: Value(humidityMin),
                humidityMax: Value(humidityMax),
                pictureMediaId: Value(pictureMediaId),
                picturePath: Value(picturePath),
                notes: Value(notes),
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
    final boxQuery = database.select(database.boxes)
      ..where((box) => box.id.equals(boxId));

    final box = await boxQuery.getSingleOrNull();

    if (box == null) {
      throw ArgumentError.value(boxId, 'boxId', 'Box does not exist');
    }

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
  }

  Future<bool> permanentlyDeleteArchivedAnimal(int animalId) {
    return database.transaction(() async {
      final animal = await getAnimalById(animalId);

      if (animal == null || animal.status != AnimalStatus.archived) {
        return false;
      }

      final pictureMediaId = animal.pictureMediaId;

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

      if (pictureMediaId != null) {
        await (database.delete(
          database.mediaAssets,
        )..where((media) => media.id.equals(pictureMediaId))).go();
      }

      return true;
    });
  }

  Future<bool> deleteAnimal(int id) {
    return database.transaction(() async {
      final animal = await getAnimalById(id);

      if (animal == null) {
        return false;
      }

      final pictureMediaId = animal.pictureMediaId;

      final deletedRows = await (database.delete(
        database.animals,
      )..where((animal) => animal.id.equals(id))).go();

      if (deletedRows != 1) {
        return false;
      }

      if (pictureMediaId != null) {
        await (database.delete(
          database.mediaAssets,
        )..where((media) => media.id.equals(pictureMediaId))).go();
      }

      return true;
    });
  }
}
