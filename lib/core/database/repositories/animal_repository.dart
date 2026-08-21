import '../app_database.dart';

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
}