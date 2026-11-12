import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';

typedef CareMutationRecords = ({
  Animal? animal,
  Box? box,
  int? feedingAnimalId,
});

/// Read before dispatch so audit and change notifications can identify deletions.
Future<CareMutationRecords> readCareMutationRecords(
  AppDatabase database,
  List<String> path,
) async {
  final id = path.length > 1 ? int.tryParse(path[1]) : null;
  final root = path.firstOrNull;
  return (
    animal: root == 'animals' && id != null
        ? await AnimalRepository(database).getAnimalById(id)
        : null,
    box: root == 'boxes' && id != null
        ? await BoxRepository(database).getBoxById(id)
        : null,
    feedingAnimalId: root == 'feedings' && id != null
        ? (await FeedingRepository(database).getFeedingById(id))?.animalId
        : null,
  );
}
