import 'dart:io';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

/// Captures dependencies inside the same transaction as the mutation/audit.
class CareChangeHints {
  CareChangeHints._(
    this.path,
    this.method,
    this.oldBoxId,
    this.feedingAnimalId,
    this.oldPictureMediaId,
  );
  final List<String> path;
  final String method;
  final int? oldBoxId;
  final int? feedingAnimalId;
  final int? oldPictureMediaId;

  static Future<CareChangeHints> capture(
    AppDatabase database,
    HttpRequest request,
  ) async {
    final path = request.uri.pathSegments.skip(2).toList();
    final id = path.length > 1 ? int.tryParse(path[1]) : null;
    final animal = path.firstOrNull == 'animals' && id != null
        ? await AnimalRepository(database).getAnimalById(id)
        : null;
    final feeding = path.firstOrNull == 'feedings' && id != null
        ? await FeedingRepository(database).getFeedingById(id)
        : null;
    final box = path.firstOrNull == 'boxes' && id != null
        ? await BoxRepository(database).getBoxById(id)
        : null;
    return CareChangeHints._(
      path,
      request.method,
      animal?.boxId,
      feeding?.animalId,
      animal?.pictureMediaId ?? box?.pictureMediaId,
    );
  }

  Map<String, Iterable<int>?> complete(ApiReply reply) {
    if (reply.status < 200 || reply.status >= 300 || reply.replayed) return {};
    final resources = <String, Iterable<int>?>{'audit': null};
    final ids = <int>{};
    final id = path.length > 1 ? int.tryParse(path[1]) : null;
    if (id != null) ids.add(id);
    final body = reply.body ?? {};
    Set<int> mediaIds(Map? record) {
      final picture = body['picture'];
      final primary = record?['pictureMediaId'];
      final pathMediaId = path.length > 3 ? int.tryParse(path[3]) : null;
      return {
        ?oldPictureMediaId,
        ?pathMediaId,
        if (primary is int) primary,
        if (body['pictureMediaId'] is int) body['pictureMediaId'] as int,
        if (picture is Map && picture['mediaId'] is int)
          picture['mediaId'] as int,
      };
    }

    if (path.firstOrNull == 'animals') {
      final animal = body['animal'];
      if (animal is Map && animal['id'] is int) ids.add(animal['id'] as int);
      resources['animals'] = ids;
      resources['boxes'] = {
        ?oldBoxId,
        if (animal is Map && animal['boxId'] is int) animal['boxId'] as int,
      };
      if ((path.length > 2 && path[2] == 'pictures') ||
          (animal is Map && animal['pictureMediaId'] != oldPictureMediaId)) {
        resources['animalPictures'] = ids;
        resources['media'] = mediaIds(animal is Map ? animal : null);
      }
      if (!(path.length > 2 && path[2] == 'pictures')) {
        resources['reminders'] = ids;
        resources['weightHistories'] = ids;
        resources['sheddingHistories'] = ids;
        if (path.length == 2 && method == 'DELETE') {
          resources['feedingHistories'] = ids;
          resources['animalPictures'] = ids;
          resources['media'] = null;
        }
      }
    } else if (path.firstOrNull == 'boxes') {
      final box = body['box'];
      if (box is Map && box['id'] is int) ids.add(box['id'] as int);
      resources['boxes'] = ids;
      if ((path.length > 2 && path[2] == 'pictures') ||
          method == 'DELETE' ||
          (box is Map && box['pictureMediaId'] != oldPictureMediaId)) {
        resources['boxPictures'] = ids;
        resources['media'] = mediaIds(box is Map ? box : null);
      }
      if (path.length == 2 && method == 'DELETE') {
        resources['animals'] = null;
        resources['reminders'] = null;
        resources['media'] = null;
      }
    } else if (path.firstOrNull == 'feedings') {
      final animals = <int>{?feedingAnimalId};
      final entries =
          body['feedings'] ?? [if (body['feeding'] != null) body['feeding']];
      if (entries is List) {
        for (final entry in entries) {
          if (entry is Map) {
            if (entry['id'] is int) ids.add(entry['id'] as int);
            if (entry['animalId'] is int) animals.add(entry['animalId'] as int);
          }
        }
      }
      resources.addAll({
        'feedings': ids,
        'animals': animals,
        'feedingHistories': animals,
        'reminders': animals,
      });
    } else {
      // A newly added successful mutation must never become invisible.
      resources['collection'] = null;
    }
    return resources;
  }
}
