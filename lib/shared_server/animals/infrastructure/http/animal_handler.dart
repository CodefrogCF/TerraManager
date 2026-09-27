import 'dart:async';
import 'dart:io';

import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/shared_server/animals/application/animal_operations.dart';
import 'package:terramanager/shared_server/animals/infrastructure/http/animal_history_handler.dart';
import 'package:terramanager/shared_server/feedings/application/feeding_operations.dart';
import 'package:terramanager/shared_server/media/infrastructure/http/media_handler.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class AnimalHandler {
  const AnimalHandler({
    required this.operations,
    required this.pictures,
    required this.history,
    required this.feedings,
  });
  final AnimalOperations operations;
  final MediaHandler pictures;
  final AnimalHistoryHandler history;
  final FeedingOperations feedings;
  Future<ApiReply> handle(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final animals = operations;
    if (path.length == 1 && method == 'GET') {
      return operations.list();
    }
    if (path.length == 1 && method == 'POST') {
      final input = await readCollectionBody(request);

      return operations.create(input);
    }
    if (path.length < 2) {
      return apiError(404, 'not_found', 'Unknown Animal operation.');
    }
    final id = parseRecordId(path[1]);
    final existing = await animals.getAnimalById(id);
    if (existing == null) {
      return apiError(404, 'not_found', 'Animal not found.');
    }
    if (path.length == 2 && method == 'GET') {
      return ApiReply(200, {'animal': animalJson(existing)});
    }
    if (path.length == 3 && path[2] == 'duplicate' && method == 'POST') {
      final input = await readCollectionBody(request);
      return operations.duplicate(id, input);
    }
    if (path.length >= 3 && path[2] == 'pictures') {
      return pictures.animalPictures(path, method, request, existing);
    }
    if (path.length == 2 && method == 'PUT') {
      if (existing.status != AnimalStatus.active) {
        return apiError(409, 'conflict', 'Only active Animals can be edited.');
      }
      final input = await readCollectionBody(request);
      return operations.update(id, existing, input);
    }
    if (path.length == 3 && path[2] == 'feeding-reminder' && method == 'PUT') {
      final input = await readCollectionBody(request);
      return operations.updateReminder(id, input);
    }
    if (path.length == 3 && path[2] == 'move' && method == 'POST') {
      final input = await readCollectionBody(request);
      return operations.move(id, input);
    }
    if (path.length == 3 && path[2] == 'archive' && method == 'POST') {
      final input = await readCollectionBody(request);
      return operations.archive(id, input);
    }
    if (path.length == 3 && path[2] == 'restore' && method == 'POST') {
      final input = await readCollectionBody(request);
      return operations.restore(id, input);
    }
    if (path.length == 2 && method == 'DELETE') {
      return operations.delete(id);
    }
    if (path.length >= 3 && path[2] == 'weights') {
      return history.weights(path, method, request, existing);
    }
    if (path.length >= 3 && path[2] == 'shedding') {
      return history.shedding(path, method, request, existing);
    }
    if (path.length == 3 && path[2] == 'feedings' && method == 'GET') {
      return feedings.forAnimal(id);
    }
    return apiError(404, 'not_found', 'Unknown Animal operation.');
  }
}
