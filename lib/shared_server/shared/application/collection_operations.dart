import 'dart:async';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

abstract class CollectionOperations {
  CollectionOperations(this.database);
  final AppDatabase database;

  void requireRevision(Map<String, dynamic>? current, String expected) {
    if (current == null || current['revision'] != expected) {
      throw const ApiProblem(
        409,
        'stale_record',
        'This record changed. Reload it and review the new data before saving.',
      );
    }
  }

  Future<void> requireActiveAnimal(int id) async {
    final animal = await AnimalRepository(database).getAnimalById(id);
    if (animal == null || animal.status != AnimalStatus.active) {
      throw ApiProblem(409, 'conflict', 'Animal $id is not active.');
    }
  }

  Future<void> requireMedia(int? id) async {
    if (id == null) return;
    if (await MediaRepository(database).getMediaById(id) == null) {
      throw ApiProblem(400, 'invalid_data', 'Media asset $id does not exist.');
    }
  }

  double? positiveOptional(ApiInput input, String key) {
    final value = input.nullableNumber(key);
    if (value != null && value <= 0) {
      throw ApiProblem(400, 'invalid_data', '$key must be positive.');
    }
    return value;
  }
}
