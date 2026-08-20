import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/animals.dart';
import '../tables/feeding_events.dart';

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
  
  Future<DateTime?> getLastFeeding(int animalId) async {
    final feeding = await (database.select(database.feedingEvents)
      ..where((event) => event.animalId.equals(animalId))
      ..orderBy([
        (event) => OrderingTerm(
          expression: event.fedAt,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(1))
      .getSingleOrNull();
    return feeding?.fedAt;
  }
}