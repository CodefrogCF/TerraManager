import 'dart:async';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class AnimalHistoryOperations extends CollectionOperations {
  AnimalHistoryOperations(super.database);

  Future<List<AnimalWeightEntry>> getHistory(int id) =>
      AnimalWeightRepository(database).getHistory(id);
  Future<List<SheddingEvent>> getSheddingHistory(int id) =>
      SheddingRepository(database).getHistory(id);

  Future<ApiReply> weightList(Animal animal) async {
    final weights = AnimalWeightRepository(database);

    return ApiReply(200, {
      'weights': (await weights.getHistory(animal.id)).map(weightJson).toList(),
    });
  }

  Future<ApiReply> weightCreate(Animal animal, ApiInput input) async {
    final weights = AnimalWeightRepository(database);

    if (animal.status != AnimalStatus.active) {
      return apiError(409, 'conflict', 'Animal is not active.');
    }

    input.allow(const {'weightGrams', 'measuredAt'});
    final id = await weights.add(
      animalId: animal.id,
      weightGrams: input.number('weightGrams'),
      measuredAt: input.nullableDateTime('measuredAt'),
    );
    final entry = (await weights.getHistory(animal.id))
        .firstWhere((entry) => entry.id == id);
    return ApiReply(201, {'weight': weightJson(entry)});
  }

  Future<ApiReply> weightUpdate(int id, Animal animal, ApiInput input) async {
    final weights = AnimalWeightRepository(database);

    input.allow(const {'weightGrams', 'measuredAt'});
    final changed = await weights.update(
      entryId: id,
      animalId: animal.id,
      weightGrams: input.number('weightGrams'),
      measuredAt: input.dateTime('measuredAt'),
    );
    if (!changed) {
      return apiError(409, 'conflict', 'Weight could not be updated.');
    }
    final updated = (await weights.getHistory(animal.id))
        .firstWhere((entry) => entry.id == id);
    return ApiReply(200, {'weight': weightJson(updated)});
  }

  Future<ApiReply> weightDelete(int id, Animal animal) async {
    final weights = AnimalWeightRepository(database);

    final deleted = await weights.delete(entryId: id, animalId: animal.id);
    return deleted
        ? ApiReply(200, {'deleted': true})
        : apiError(409, 'conflict', 'Weight could not be deleted.');
  }

  Future<ApiReply> sheddingList(Animal animal) async {
    final shedding = SheddingRepository(database);

    return ApiReply(200, {
      'shedding': (await shedding.getHistory(animal.id))
          .map(sheddingJson)
          .toList(),
    });
  }

  Future<ApiReply> sheddingCreate(Animal animal, ApiInput input) async {
    final shedding = SheddingRepository(database);

    if (animal.status != AnimalStatus.active) {
      return apiError(409, 'conflict', 'Animal is not active.');
    }

    input.allow(const {'shedAt', 'notes'});
    final id = await shedding.add(
      animalId: animal.id,
      shedAt: input.nullableDateTime('shedAt'),
      notes: input.nullableString('notes'),
    );
    final event = (await shedding.getHistory(animal.id))
        .firstWhere((event) => event.id == id);
    return ApiReply(201, {'shedding': sheddingJson(event)});
  }

  Future<ApiReply> sheddingUpdate(int id, Animal animal, ApiInput input) async {
    final shedding = SheddingRepository(database);

    input.allow(const {'shedAt', 'notes'});
    final changed = await shedding.update(
      eventId: id,
      animalId: animal.id,
      shedAt: input.dateTime('shedAt'),
      notes: input.nullableString('notes'),
    );
    if (!changed) {
      return apiError(409, 'conflict', 'Shedding could not be updated.');
    }
    final updated = (await shedding.getHistory(animal.id))
        .firstWhere((entry) => entry.id == id);
    return ApiReply(200, {'shedding': sheddingJson(updated)});
  }

  Future<ApiReply> sheddingDelete(int id, Animal animal) async {
    final shedding = SheddingRepository(database);

    final deleted = await shedding.delete(eventId: id, animalId: animal.id);
    return deleted
        ? ApiReply(200, {'deleted': true})
        : apiError(409, 'conflict', 'Shedding could not be deleted.');
  }
}
