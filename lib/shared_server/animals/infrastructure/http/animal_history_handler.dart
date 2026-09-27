import 'dart:async';
import 'dart:io';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/shared_server/animals/application/animal_history_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';

class AnimalHistoryHandler {
  const AnimalHistoryHandler(this.operations);
  final AnimalHistoryOperations operations;
  Future<ApiReply> weights(
    List<String> path,
    String method,
    HttpRequest request,
    Animal animal,
  ) async {
    final weights = operations;
    if (path.length == 3 && method == 'GET') {
      return operations.weightList(animal);
    }
    if (path.length == 3 && method == 'POST') {
      if (animal.status != AnimalStatus.active) {
        return apiError(409, 'conflict', 'Animal is not active.');
      }
      final input = await readCollectionBody(request);
      return operations.weightCreate(animal, input);
    }
    if (path.length != 4) {
      return apiError(404, 'not_found', 'Unknown Weight operation.');
    }
    final id = parseRecordId(path[3]);
    final entry = (await weights.getHistory(animal.id))
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (entry == null) {
      return apiError(404, 'not_found', 'Weight entry not found.');
    }
    if (method == 'PUT') {
      final input = await readCollectionBody(request);
      return operations.weightUpdate(id, animal, input);
    }
    if (method == 'DELETE') {
      return operations.weightDelete(id, animal);
    }
    return apiError(404, 'not_found', 'Unknown Weight operation.');
  }

  Future<ApiReply> shedding(
    List<String> path,
    String method,
    HttpRequest request,
    Animal animal,
  ) async {
    final shedding = operations;
    if (path.length == 3 && method == 'GET') {
      return operations.sheddingList(animal);
    }
    if (path.length == 3 && method == 'POST') {
      if (animal.status != AnimalStatus.active) {
        return apiError(409, 'conflict', 'Animal is not active.');
      }
      final input = await readCollectionBody(request);
      return operations.sheddingCreate(animal, input);
    }
    if (path.length != 4) {
      return apiError(404, 'not_found', 'Unknown Shedding operation.');
    }
    final id = parseRecordId(path[3]);
    final event = (await shedding.getSheddingHistory(animal.id))
        .where((event) => event.id == id)
        .firstOrNull;
    if (event == null) {
      return apiError(404, 'not_found', 'Shedding event not found.');
    }
    if (method == 'PUT') {
      final input = await readCollectionBody(request);
      return operations.sheddingUpdate(id, animal, input);
    }
    if (method == 'DELETE') {
      return operations.sheddingDelete(id, animal);
    }
    return apiError(404, 'not_found', 'Unknown Shedding operation.');
  }
}
