import 'package:drift/drift.dart';

import '../app_database.dart';

import '../enums/birth_date_accuracy.dart';
import '../enums/sex.dart';

class AnimalRepository {
  final AppDatabase database;

  AnimalRepository(this.database);

  Future<Animal?> getAnimalById(int animalId) {
    return (database.select(database.animals)
      ..where((animal) => animal.id.equals(animalId)))
    .getSingleOrNull();
  }
  
  Future<List<Animal>> getAllAnimals() {
    return database.select(database.animals).get();
  }

  Future<List<Animal>> getAnimalsForBox(int boxId) {
    return (database.select(database.animals)
      ..where((animal) => animal.boxId.equals(boxId)))
    .get();
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
    String? picturePath,
    String? notes,
  }) {
    return database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: commonName,
            latinName: latinName,
            sex: Value.absentIfNull(sex),
            birthDate: Value.absentIfNull(birthDate),
            birthDateAccuracy: Value.absentIfNull(birthDateAccuracy),
            tempMin: tempMin,
            tempMax: tempMax,
            humidityMin: humidityMin,
            humidityMax: humidityMax,
            picturePath: Value.absentIfNull(picturePath),
            notes: Value.absentIfNull(notes),
          ),
        );
  }
}