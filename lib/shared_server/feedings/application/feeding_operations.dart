import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class FeedingOperations extends CollectionOperations {
  FeedingOperations(super.database);

  Future<ApiReply> forAnimal(int animalId) async => ApiReply(200, {
    'feedings': (await FeedingRepository(
      database,
    ).getFeedingsForAnimal(animalId)).map(feedingJson).toList(),
  });

  final Map<String, _IdempotentReply> _feedingRequests = {};
  void clearRequestCache() => _feedingRequests.clear();
  Future<FeedingEvent?> getFeedingById(int id) =>
      FeedingRepository(database).getFeedingById(id);
  Future<ApiReply> _idempotentFeeding(
    String key,
    Map<String, dynamic> payload,
    Future<ApiReply> Function() operation,
  ) async {
    final now = DateTime.now();
    _feedingRequests.removeWhere(
      (_, entry) => now.difference(entry.createdAt) > const Duration(hours: 24),
    );
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    final existing = _feedingRequests[key];
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        return apiError(
          409,
          'idempotency_conflict',
          'Request key was reused with different data.',
        );
      }
      final reply = await existing.result;
      return ApiReply(reply.status, reply.body, replayed: true);
    }
    if (_feedingRequests.length >= 10000) {
      return apiError(429, 'rate_limited', 'Too many recent feeding requests.');
    }
    final result = operation();
    _feedingRequests[key] = _IdempotentReply(now, fingerprint, result);
    try {
      return await result;
    } catch (_) {
      _feedingRequests.remove(key);
      rethrow;
    }
  }

  Future<ApiReply> create(ApiInput input, String? requestId) async {
    final feedings = FeedingRepository(database);

    input.allow(const {'animalIds', 'fedAt', 'notes', 'boxId'});

    if (requestId == null ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(requestId)) {
      return apiError(
        400,
        'invalid_data',
        'A UUID Idempotency-Key header is required.',
      );
    }
    final animalIds = input.integerList('animalIds');
    final fedAt = input.dateTime('fedAt');
    final notes = input.nullableString('notes');
    final boxId = input.nullableInteger('boxId');
    return _idempotentFeeding(requestId, input.values, () async {
      final ids = await database.transaction(() async {
        if (boxId != null) {
          final box = await BoxRepository(database).getBoxById(boxId);
          if (box == null || box.status != BoxStatus.active) {
            throw const ApiProblem(409, 'conflict', 'Box is not active.');
          }
        }
        for (final animalId in animalIds) {
          await requireActiveAnimal(animalId);
          if (boxId != null) {
            final animal = await AnimalRepository(database)
                .getAnimalById(animalId);
            if (animal?.boxId != boxId) {
              throw ApiProblem(
                409,
                'conflict',
                'Animal $animalId is no longer assigned to Box $boxId.',
              );
            }
          }
        }
        return feedings.addFeedings(
          animalIds: animalIds,
          fedAt: fedAt,
          notes: notes,
        );
      });
      return ApiReply(201, {
        'feedings': [
          for (final id in ids)
            feedingJson((await feedings.getFeedingById(id))!),
        ],
      });
    });
  }

  Future<ApiReply> update(int id, ApiInput input) async {
    final feedings = FeedingRepository(database);

    input.allow(const {'fedAt', 'notes'});
    final changed = await feedings.updateFeeding(
      feedingId: id,
      fedAt: input.dateTime('fedAt'),
      notes: input.nullableString('notes'),
    );
    return changed
        ? ApiReply(200, {
            'feeding': feedingJson((await feedings.getFeedingById(id))!),
          })
        : apiError(409, 'conflict', 'Feeding could not be updated.');
  }

  Future<ApiReply> delete(int id) async {
    final feedings = FeedingRepository(database);

    final deleted = await feedings.deleteFeeding(id);
    return deleted
        ? ApiReply(200, {'deleted': true})
        : apiError(409, 'conflict', 'Feeding could not be deleted.');
  }
}

class _IdempotentReply {
  final DateTime createdAt;
  final String fingerprint;
  final Future<ApiReply> result;

  const _IdempotentReply(this.createdAt, this.fingerprint, this.result);
}
