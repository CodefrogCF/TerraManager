import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart' show SqlError, SqliteException;

import '../core/database/app_database.dart';
import '../core/database/enums/animal_archive_reason.dart';
import '../core/database/enums/animal_status.dart';
import '../core/database/enums/box_archive_reason.dart';
import '../core/database/enums/box_status.dart';
import '../core/database/repositories/animal_repository.dart';
import '../core/database/repositories/animal_weight_repository.dart';
import '../core/database/repositories/box_lifecycle_exception.dart';
import '../core/database/repositories/box_repository.dart';
import '../core/database/repositories/feeding_repository.dart';
import '../core/database/repositories/media_repository.dart';
import '../core/database/repositories/picture_gallery_repository.dart';
import '../core/database/repositories/shedding_repository.dart';
import '../features/feedings/application/feeding_reminder_service.dart';
import 'animal_command.dart';
import 'api_input.dart';
import 'api_models.dart';
import 'care_authenticator.dart';

typedef _Payload = Map<String, dynamic>;

class CareApi {
  final AppDatabase database;
  final CareAuthenticator authenticator;
  final Map<String, _IdempotentReply> _feedingRequests = {};

  CareApi({required this.database, required this.authenticator});

  void clearRequestCache() => _feedingRequests.clear();

  static void _requireRevision(Map<String, dynamic>? current, String expected) {
    if (current == null || current['revision'] != expected) {
      throw const ApiProblem(
        409,
        'stale_record',
        'This record changed. Reload it and review the new data before saving.',
      );
    }
  }

  Future<HttpServer> serve({InternetAddress? address, int port = 0}) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    server.listen((request) {
      unawaited(handle(request));
    });
    return server;
  }

  Future<void> handle(HttpRequest request) async {
    try {
      if (!await authenticator.isAuthenticated(request)) {
        throw const ApiProblem(401, 'unauthorized', 'Authentication required.');
      }
      final reply = await _dispatch(request);
      await _send(request.response, reply);
    } on ApiProblem catch (problem) {
      await _send(
        request.response,
        _Reply(problem.status, {
          'error': {'code': problem.code, 'message': problem.message},
        }),
      );
    } on BoxArchiveBlockedException {
      await _send(
        request.response,
        _error(409, 'conflict', 'Box contains active Animals.'),
      );
    } on BoxAssignmentException {
      await _send(
        request.response,
        _error(409, 'conflict', 'Destination Box is not active.'),
      );
    } on ArgumentError catch (error) {
      await _send(
        request.response,
        _error(
          400,
          'invalid_data',
          error.message?.toString() ?? 'Invalid data.',
        ),
      );
    } on StateError {
      await _send(
        request.response,
        _error(409, 'conflict', 'Operation conflicts with current data.'),
      );
    } on SqliteException catch (error) {
      await _send(
        request.response,
        error.resultCode == SqlError.SQLITE_CONSTRAINT ||
                error.resultCode == SqlError.SQLITE_BUSY ||
                error.resultCode == SqlError.SQLITE_LOCKED
            ? _error(409, 'conflict', 'Database state prevents this change.')
            : _error(
                500,
                'internal_error',
                'The request could not be completed.',
              ),
      );
    } catch (_) {
      await _send(
        request.response,
        _error(500, 'internal_error', 'The request could not be completed.'),
      );
    }
  }

  Future<_Reply> _dispatch(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.length < 3 || segments[0] != 'api' || segments[1] != 'v1') {
      return _error(404, 'not_found', 'Unknown API path.');
    }
    final path = segments.skip(2).toList(growable: false);
    final method = request.method;
    if (path[0] == 'boxes') return _boxes(path, method, request);
    if (path[0] == 'animals') return _animals(path, method, request);
    if (path[0] == 'feedings') return _feedings(path, method, request);
    if (path[0] == 'reminders' && path.length == 1 && method == 'GET') {
      final states = await FeedingReminderService(database).getReminderStates();
      return _Reply(200, {
        'reminders': [
          for (final state in states)
            {
              'animalId': state.animalId,
              'dueAt': state.dueAt.toUtc().toIso8601String(),
              'latestFeedingAt': state.latestFeedingAt
                  ?.toUtc()
                  .toIso8601String(),
            },
        ],
      });
    }
    if (path[0] == 'media') return _media(path, method, request);
    return _error(404, 'not_found', 'Unknown API path.');
  }

  Future<_Reply> _boxes(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final boxes = BoxRepository(database);
    if (path.length == 1 && method == 'GET') {
      return _Reply(200, {
        'boxes': (await boxes.getAllBoxes()).map(boxJson).toList(),
      });
    }
    if (path.length == 1 && method == 'POST') {
      final input = await _body(request);
      input.allow(const {
        'name',
        'widthCm',
        'heightCm',
        'depthCm',
        'temperatureZones',
        'notes',
        'pictureMediaId',
      });
      final width = _positiveOptional(input, 'widthCm');
      final height = _positiveOptional(input, 'heightCm');
      final depth = _positiveOptional(input, 'depthCm');
      final mediaId = input.nullableInteger('pictureMediaId');
      await _requireMedia(mediaId);
      final id = await boxes.createBoxWithGeneratedQrId(
        name: input.nullableString('name', maxLength: 200),
        widthCm: width,
        heightCm: height,
        depthCm: depth,
        temperatureZones: input.nullableString('temperatureZones'),
        notes: input.nullableString('notes'),
        pictureMediaId: mediaId,
      );
      return _Reply(201, {'box': boxJson((await boxes.getBoxById(id))!)});
    }
    if (path.length == 3 && path[1] == 'qr' && method == 'GET') {
      final box = await boxes.getBoxByQrId(path[2]);
      return box == null
          ? _error(404, 'not_found', 'Box not found.')
          : _Reply(200, {'box': boxJson(box)});
    }
    if (path.length < 2) {
      return _error(404, 'not_found', 'Unknown Box operation.');
    }
    final id = _pathId(path[1]);
    final existing = await boxes.getBoxById(id);
    if (existing == null) return _error(404, 'not_found', 'Box not found.');
    if (path.length == 2 && method == 'GET') {
      return _Reply(200, {'box': boxJson(existing)});
    }
    if (path.length == 3 && path[2] == 'duplicate' && method == 'POST') {
      final input = await _body(request);
      input.allow(const {'name'});
      final newId = await boxes.duplicateBox(
        sourceBoxId: id,
        name: input.nullableString('name', maxLength: 200),
      );
      return _Reply(201, {'box': boxJson((await boxes.getBoxById(newId))!)});
    }
    if (path.length >= 3 && path[2] == 'pictures') {
      return _boxPictures(path, method, request, existing);
    }
    if (path.length == 2 && method == 'PATCH') {
      if (existing.status != BoxStatus.active) {
        return _error(409, 'conflict', 'Only active Boxes can be edited.');
      }
      final input = await _body(request);
      input.allow(const {
        'expectedRevision',
        'name',
        'widthCm',
        'heightCm',
        'depthCm',
        'temperatureZones',
        'notes',
        'pictureMediaId',
      });
      final expectedRevision = input.string('expectedRevision', maxLength: 64);
      if (input.values.length == 1) {
        return _error(400, 'invalid_data', 'No fields to update.');
      }
      final mediaId = input.nullableInteger('pictureMediaId');
      if (input.values.containsKey('pictureMediaId')) {
        await _requireMedia(mediaId);
      }
      final updated = await database.transaction(() async {
        final current = await boxes.getBoxById(id);
        _requireRevision(
          current == null ? null : boxJson(current),
          expectedRevision,
        );
        return boxes.updateBox(
          boxId: id,
          name: input.values.containsKey('name')
              ? Value(input.nullableString('name', maxLength: 200))
              : const Value.absent(),
          widthCm: input.values.containsKey('widthCm')
              ? Value(_positiveOptional(input, 'widthCm'))
              : const Value.absent(),
          heightCm: input.values.containsKey('heightCm')
              ? Value(_positiveOptional(input, 'heightCm'))
              : const Value.absent(),
          depthCm: input.values.containsKey('depthCm')
              ? Value(_positiveOptional(input, 'depthCm'))
              : const Value.absent(),
          temperatureZones: input.values.containsKey('temperatureZones')
              ? Value(input.nullableString('temperatureZones'))
              : const Value.absent(),
          notes: input.values.containsKey('notes')
              ? Value(input.nullableString('notes'))
              : const Value.absent(),
          pictureMediaId: input.values.containsKey('pictureMediaId')
              ? Value(mediaId)
              : const Value.absent(),
        );
      });
      return updated
          ? _Reply(200, {'box': boxJson((await boxes.getBoxById(id))!)})
          : _error(409, 'conflict', 'Box could not be updated.');
    }
    if (path.length == 3 && path[2] == 'archive' && method == 'POST') {
      final input = await _body(request);
      input.allow(const {'reason', 'archivedAt', 'archiveNotes'});
      final archived = await boxes.archiveBox(
        boxId: id,
        reason: input.enumerated('reason', BoxArchiveReason.values),
        archivedAt: input.dateTime('archivedAt', fallback: DateTime.now()),
        archiveNotes: input.nullableString('archiveNotes'),
      );
      return archived
          ? _Reply(200, {'box': boxJson((await boxes.getBoxById(id))!)})
          : _error(409, 'conflict', 'Box is not active.');
    }
    if (path.length == 3 && path[2] == 'restore' && method == 'POST') {
      final restored = await boxes.restoreBox(id);
      return restored
          ? _Reply(200, {'box': boxJson((await boxes.getBoxById(id))!)})
          : _error(409, 'conflict', 'Box is not archived.');
    }
    if (path.length == 2 && method == 'DELETE') {
      final deleted = await boxes.permanentlyDeleteArchivedBox(id);
      return deleted
          ? _Reply(200, {'deleted': true})
          : _error(409, 'conflict', 'Only archived Boxes can be deleted.');
    }
    return _error(404, 'not_found', 'Unknown Box operation.');
  }

  Future<_Reply> _animals(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final animals = AnimalRepository(database);
    if (path.length == 1 && method == 'GET') {
      final records = await animals.getAllAnimals();
      final latest = await FeedingRepository(database)
          .getLatestFeedingTimes(records.map((animal) => animal.id));
      return _Reply(200, {
        'animals': [
          for (final animal in records)
            {
              ...animalJson(animal),
              'latestFeedingAt': latest[animal.id]?.toUtc().toIso8601String(),
            },
        ],
      });
    }
    if (path.length == 1 && method == 'POST') {
      final data = AnimalCommand.fromInput(
        await _body(request),
        creating: true,
      );
      await _requireMedia(data.pictureMediaId);
      final id = await animals.createAnimal(
        boxId: data.boxId,
        commonName: data.commonName,
        latinName: data.latinName,
        category: data.category,
        subcategory: data.subcategory,
        sex: data.sex,
        birthDate: data.birthDate,
        birthDateAccuracy: data.birthDateAccuracy,
        tempMin: data.tempMin,
        tempMax: data.tempMax,
        nighttimeTemperatureMin: data.nighttimeTemperatureMin,
        nighttimeTemperatureMax: data.nighttimeTemperatureMax,
        humidityMin: data.humidityMin,
        humidityMax: data.humidityMax,
        originHabitat: data.originHabitat,
        restOrDormancyPeriods: data.restOrDormancyPeriods,
        notes: data.notes,
        pictureMediaId: data.pictureMediaId,
        feedingReminderIntervalDays: data.feedingReminderIntervalDays,
        feedingReminderBaseline: data.feedingReminderBaseline,
        weightGrams: data.weightGrams,
        weightMeasuredAt: data.weightMeasuredAt,
        showWeightOnDetail: data.showWeightOnDetail,
        showSheddingOnDetail: data.showSheddingOnDetail,
      );
      return _Reply(201, {
        'animal': animalJson((await animals.getAnimalById(id))!),
      });
    }
    if (path.length < 2) {
      return _error(404, 'not_found', 'Unknown Animal operation.');
    }
    final id = _pathId(path[1]);
    final existing = await animals.getAnimalById(id);
    if (existing == null) return _error(404, 'not_found', 'Animal not found.');
    if (path.length == 2 && method == 'GET') {
      return _Reply(200, {'animal': animalJson(existing)});
    }
    if (path.length == 3 && path[2] == 'duplicate' && method == 'POST') {
      final input = await _body(request);
      input.allow(const {'boxId', 'commonName'});
      final newId = await animals.duplicateAnimal(
        sourceAnimalId: id,
        boxId: input.integer('boxId'),
        commonName: input.string('commonName'),
      );
      return _Reply(201, {
        'animal': animalJson((await animals.getAnimalById(newId))!),
      });
    }
    if (path.length >= 3 && path[2] == 'pictures') {
      return _animalPictures(path, method, request, existing);
    }
    if (path.length == 2 && method == 'PUT') {
      if (existing.status != AnimalStatus.active) {
        return _error(409, 'conflict', 'Only active Animals can be edited.');
      }
      final input = await _body(request);
      final expectedRevision = input.string('expectedRevision', maxLength: 64);
      input.values.remove('expectedRevision');
      final data = AnimalCommand.fromInput(input);
      await _requireMedia(data.pictureMediaId);
      final updated = await database.transaction(() async {
        final current = await animals.getAnimalById(id);
        _requireRevision(
          current == null ? null : animalJson(current),
          expectedRevision,
        );
        return animals.updateAnimal(
          animalId: id,
          boxId: data.boxId,
          commonName: data.commonName,
          latinName: data.latinName,
          category: data.category,
          subcategory: data.subcategory,
          sex: data.sex,
          birthDate: data.birthDate,
          birthDateAccuracy: data.birthDateAccuracy,
          tempMin: data.tempMin,
          tempMax: data.tempMax,
          nighttimeTemperatureMin: data.nighttimeTemperatureMin,
          nighttimeTemperatureMax: data.nighttimeTemperatureMax,
          humidityMin: data.humidityMin,
          humidityMax: data.humidityMax,
          originHabitat: data.originHabitat,
          restOrDormancyPeriods: data.restOrDormancyPeriods,
          notes: data.notes,
          pictureMediaId: data.pictureMediaId,
          feedingReminderIntervalDays: data.feedingReminderIntervalDays,
          feedingReminderBaseline: data.feedingReminderBaseline,
          weightGrams: data.weightGrams,
          weightMeasuredAt: data.weightMeasuredAt,
          showWeightOnDetail: data.showWeightOnDetail,
          showSheddingOnDetail: data.showSheddingOnDetail,
        );
      });
      return updated
          ? _Reply(200, {
              'animal': animalJson((await animals.getAnimalById(id))!),
            })
          : _error(409, 'conflict', 'Animal could not be updated.');
    }
    if (path.length == 3 && path[2] == 'feeding-reminder' && method == 'PUT') {
      final input = await _body(request);
      input.allow(const {'expectedRevision', 'intervalDays', 'baseline'});
      final expectedRevision = input.string('expectedRevision', maxLength: 64);
      final intervalDays = input.nullableInteger('intervalDays');
      final baseline = input.nullableDateTime('baseline');
      if ((intervalDays == null) != (baseline == null)) {
        throw const ApiProblem(
          400,
          'invalid_data',
          'Reminder interval and baseline must both be set or both be null.',
        );
      }
      final updated = await database.transaction(() async {
        final current = await animals.getAnimalById(id);
        _requireRevision(
          current == null ? null : animalJson(current),
          expectedRevision,
        );
        return animals.updateFeedingReminder(
          animalId: id,
          intervalDays: intervalDays,
          baseline: baseline,
        );
      });
      return updated
          ? _Reply(200, {
              'animal': animalJson((await animals.getAnimalById(id))!),
            })
          : _error(409, 'conflict', 'Only active Animals can be edited.');
    }
    if (path.length == 3 && path[2] == 'move' && method == 'POST') {
      final input = await _body(request);
      input.allow(const {'boxId', 'expectedRevision'});
      final boxId = input.integer('boxId');
      final expectedRevision = input.nullableString(
        'expectedRevision',
        maxLength: 64,
      );
      final moved = await database.transaction(() async {
        if (expectedRevision != null) {
          final current = await animals.getAnimalById(id);
          _requireRevision(
            current == null ? null : animalJson(current),
            expectedRevision,
          );
        }
        return animals.moveAnimalToBox(animalId: id, boxId: boxId);
      });
      return moved
          ? _Reply(200, {
              'animal': animalJson((await animals.getAnimalById(id))!),
            })
          : _error(409, 'conflict', 'Animal cannot move to that Box.');
    }
    if (path.length == 3 && path[2] == 'archive' && method == 'POST') {
      final input = await _body(request);
      input.allow(const {'reason', 'archivedAt', 'archiveNotes'});
      final archived = await animals.archiveAnimal(
        animalId: id,
        reason: input.enumerated('reason', AnimalArchiveReason.values),
        archivedAt: input.dateTime('archivedAt', fallback: DateTime.now()),
        archiveNotes: input.nullableString('archiveNotes'),
      );
      return archived
          ? _Reply(200, {
              'animal': animalJson((await animals.getAnimalById(id))!),
            })
          : _error(409, 'conflict', 'Animal is not active.');
    }
    if (path.length == 3 && path[2] == 'restore' && method == 'POST') {
      final input = await _body(request);
      input.allow(const {'boxId'});
      final restored = await animals.restoreAnimal(
        animalId: id,
        boxId: input.integer('boxId'),
      );
      return restored
          ? _Reply(200, {
              'animal': animalJson((await animals.getAnimalById(id))!),
            })
          : _error(409, 'conflict', 'Animal is not archived.');
    }
    if (path.length == 2 && method == 'DELETE') {
      final deleted = await animals.permanentlyDeleteArchivedAnimal(id);
      return deleted
          ? _Reply(200, {'deleted': true})
          : _error(409, 'conflict', 'Only archived Animals can be deleted.');
    }
    if (path.length >= 3 && path[2] == 'weights') {
      return _weights(path, method, request, existing);
    }
    if (path.length >= 3 && path[2] == 'shedding') {
      return _shedding(path, method, request, existing);
    }
    if (path.length == 3 && path[2] == 'feedings' && method == 'GET') {
      return _Reply(200, {
        'feedings': (await FeedingRepository(database).getFeedingsForAnimal(id))
            .map(feedingJson)
            .toList(),
      });
    }
    return _error(404, 'not_found', 'Unknown Animal operation.');
  }

  Future<_Reply> _boxPictures(
    List<String> path,
    String method,
    HttpRequest request,
    Box box,
  ) async {
    final pictures = PictureGalleryRepository(database);
    if (path.length == 3 && method == 'GET') {
      return _Reply(200, {
        'pictures': (await pictures.getBoxPictures(box.id))
            .map(pictureJson)
            .toList(),
      });
    }
    if (box.status != BoxStatus.active) {
      return _error(409, 'conflict', 'Box is not active.');
    }
    if (path.length == 3 && method == 'POST') {
      final input = await _body(request, maxBytes: 12 * 1024 * 1024);
      input.allow(const {
        'fileName',
        'mimeType',
        'dataBase64',
        'capturedAt',
        'makePrimary',
      });
      final image = _image(input);
      final mediaId = await pictures.addBoxPicture(
        boxId: box.id,
        fileName: image.fileName,
        mimeType: image.mimeType,
        data: image.bytes,
        capturedAt: input.nullableDateTime('capturedAt'),
        makePrimary: input.boolean('makePrimary', fallback: true),
      );
      final entries = await pictures.getBoxPictures(box.id);
      return _Reply(201, {
        'picture': pictureJson(
          entries.firstWhere((entry) => entry.media.id == mediaId),
        ),
      });
    }
    if (path.length < 4) {
      return _error(404, 'not_found', 'Unknown Box picture operation.');
    }
    final mediaId = _pathId(path[3]);
    if (path.length == 5 && path[4] == 'primary' && method == 'POST') {
      final changed = await pictures.setBoxPrimaryPicture(
        boxId: box.id,
        mediaId: mediaId,
      );
      return changed
          ? _Reply(200, {'pictureMediaId': mediaId})
          : _error(404, 'not_found', 'Box picture not found.');
    }
    if (path.length == 4 && method == 'DELETE') {
      final deleted = await pictures.deleteBoxPicture(
        boxId: box.id,
        mediaId: mediaId,
      );
      return deleted
          ? _Reply(200, {'deleted': true})
          : _error(404, 'not_found', 'Box picture not found.');
    }
    return _error(404, 'not_found', 'Unknown Box picture operation.');
  }

  Future<_Reply> _animalPictures(
    List<String> path,
    String method,
    HttpRequest request,
    Animal animal,
  ) async {
    final pictures = PictureGalleryRepository(database);
    if (path.length == 3 && method == 'GET') {
      return _Reply(200, {
        'pictures': (await pictures.getAnimalPictures(animal.id))
            .map(pictureJson)
            .toList(),
      });
    }
    if (animal.status != AnimalStatus.active) {
      return _error(409, 'conflict', 'Animal is not active.');
    }
    if (path.length == 3 && method == 'POST') {
      final input = await _body(request, maxBytes: 12 * 1024 * 1024);
      input.allow(const {
        'fileName',
        'mimeType',
        'dataBase64',
        'capturedAt',
        'makePrimary',
      });
      final image = _image(input);
      final mediaId = await pictures.addAnimalPicture(
        animalId: animal.id,
        fileName: image.fileName,
        mimeType: image.mimeType,
        data: image.bytes,
        capturedAt: input.nullableDateTime('capturedAt'),
        makePrimary: input.boolean('makePrimary', fallback: true),
      );
      final entries = await pictures.getAnimalPictures(animal.id);
      return _Reply(201, {
        'picture': pictureJson(
          entries.firstWhere((entry) => entry.media.id == mediaId),
        ),
      });
    }
    if (path.length < 4) {
      return _error(404, 'not_found', 'Unknown Animal picture operation.');
    }
    final mediaId = _pathId(path[3]);
    if (path.length == 5 && path[4] == 'primary' && method == 'POST') {
      final changed = await pictures.setAnimalPrimaryPicture(
        animalId: animal.id,
        mediaId: mediaId,
      );
      return changed
          ? _Reply(200, {'pictureMediaId': mediaId})
          : _error(404, 'not_found', 'Animal picture not found.');
    }
    if (path.length == 4 && method == 'DELETE') {
      final deleted = await pictures.deleteAnimalPicture(
        animalId: animal.id,
        mediaId: mediaId,
      );
      return deleted
          ? _Reply(200, {'deleted': true})
          : _error(404, 'not_found', 'Animal picture not found.');
    }
    return _error(404, 'not_found', 'Unknown Animal picture operation.');
  }

  Future<_Reply> _feedings(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final feedings = FeedingRepository(database);
    if (path.length == 1 && method == 'POST') {
      final input = await _body(request);
      input.allow(const {'animalIds', 'fedAt', 'notes', 'boxId'});
      final requestId = request.headers.value('Idempotency-Key');
      if (requestId == null ||
          !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(requestId)) {
        return _error(
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
            await _requireActiveAnimal(animalId);
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
        return _Reply(201, {
          'feedings': [
            for (final id in ids)
              feedingJson((await feedings.getFeedingById(id))!),
          ],
        });
      });
    }
    if (path.length != 2) {
      return _error(404, 'not_found', 'Unknown Feeding operation.');
    }
    final id = _pathId(path[1]);
    final existing = await feedings.getFeedingById(id);
    if (existing == null) {
      return _error(404, 'not_found', 'Feeding not found.');
    }
    if (method == 'GET') return _Reply(200, {'feeding': feedingJson(existing)});
    if (method == 'PUT') {
      final input = await _body(request);
      input.allow(const {'fedAt', 'notes'});
      final changed = await feedings.updateFeeding(
        feedingId: id,
        fedAt: input.dateTime('fedAt'),
        notes: input.nullableString('notes'),
      );
      return changed
          ? _Reply(200, {
              'feeding': feedingJson((await feedings.getFeedingById(id))!),
            })
          : _error(409, 'conflict', 'Feeding could not be updated.');
    }
    if (method == 'DELETE') {
      final deleted = await feedings.deleteFeeding(id);
      return deleted
          ? _Reply(200, {'deleted': true})
          : _error(409, 'conflict', 'Feeding could not be deleted.');
    }
    return _error(404, 'not_found', 'Unknown Feeding operation.');
  }

  Future<_Reply> _idempotentFeeding(
    String key,
    Map<String, dynamic> payload,
    Future<_Reply> Function() operation,
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
        return _error(
          409,
          'idempotency_conflict',
          'Request key was reused with different data.',
        );
      }
      return existing.result;
    }
    if (_feedingRequests.length >= 10000) {
      return _error(429, 'rate_limited', 'Too many recent feeding requests.');
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

  Future<_Reply> _weights(
    List<String> path,
    String method,
    HttpRequest request,
    Animal animal,
  ) async {
    final weights = AnimalWeightRepository(database);
    if (path.length == 3 && method == 'GET') {
      return _Reply(200, {
        'weights': (await weights.getHistory(animal.id))
            .map(weightJson)
            .toList(),
      });
    }
    if (path.length == 3 && method == 'POST') {
      if (animal.status != AnimalStatus.active) {
        return _error(409, 'conflict', 'Animal is not active.');
      }
      final input = await _body(request);
      input.allow(const {'weightGrams', 'measuredAt'});
      final id = await weights.add(
        animalId: animal.id,
        weightGrams: input.number('weightGrams'),
        measuredAt: input.nullableDateTime('measuredAt'),
      );
      final entry = (await weights.getHistory(animal.id))
          .firstWhere((entry) => entry.id == id);
      return _Reply(201, {'weight': weightJson(entry)});
    }
    if (path.length != 4) {
      return _error(404, 'not_found', 'Unknown Weight operation.');
    }
    final id = _pathId(path[3]);
    final entry = (await weights.getHistory(animal.id))
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (entry == null) {
      return _error(404, 'not_found', 'Weight entry not found.');
    }
    if (method == 'PUT') {
      final input = await _body(request);
      input.allow(const {'weightGrams', 'measuredAt'});
      final changed = await weights.update(
        entryId: id,
        animalId: animal.id,
        weightGrams: input.number('weightGrams'),
        measuredAt: input.dateTime('measuredAt'),
      );
      if (!changed) {
        return _error(409, 'conflict', 'Weight could not be updated.');
      }
      final updated = (await weights.getHistory(animal.id))
          .firstWhere((entry) => entry.id == id);
      return _Reply(200, {'weight': weightJson(updated)});
    }
    if (method == 'DELETE') {
      final deleted = await weights.delete(entryId: id, animalId: animal.id);
      return deleted
          ? _Reply(200, {'deleted': true})
          : _error(409, 'conflict', 'Weight could not be deleted.');
    }
    return _error(404, 'not_found', 'Unknown Weight operation.');
  }

  Future<_Reply> _shedding(
    List<String> path,
    String method,
    HttpRequest request,
    Animal animal,
  ) async {
    final shedding = SheddingRepository(database);
    if (path.length == 3 && method == 'GET') {
      return _Reply(200, {
        'shedding': (await shedding.getHistory(animal.id))
            .map(sheddingJson)
            .toList(),
      });
    }
    if (path.length == 3 && method == 'POST') {
      if (animal.status != AnimalStatus.active) {
        return _error(409, 'conflict', 'Animal is not active.');
      }
      final input = await _body(request);
      input.allow(const {'shedAt', 'notes'});
      final id = await shedding.add(
        animalId: animal.id,
        shedAt: input.nullableDateTime('shedAt'),
        notes: input.nullableString('notes'),
      );
      final event = (await shedding.getHistory(animal.id))
          .firstWhere((event) => event.id == id);
      return _Reply(201, {'shedding': sheddingJson(event)});
    }
    if (path.length != 4) {
      return _error(404, 'not_found', 'Unknown Shedding operation.');
    }
    final id = _pathId(path[3]);
    final event = (await shedding.getHistory(animal.id))
        .where((event) => event.id == id)
        .firstOrNull;
    if (event == null) {
      return _error(404, 'not_found', 'Shedding event not found.');
    }
    if (method == 'PUT') {
      final input = await _body(request);
      input.allow(const {'shedAt', 'notes'});
      final changed = await shedding.update(
        eventId: id,
        animalId: animal.id,
        shedAt: input.dateTime('shedAt'),
        notes: input.nullableString('notes'),
      );
      if (!changed) {
        return _error(409, 'conflict', 'Shedding could not be updated.');
      }
      final updated = (await shedding.getHistory(animal.id))
          .firstWhere((entry) => entry.id == id);
      return _Reply(200, {'shedding': sheddingJson(updated)});
    }
    if (method == 'DELETE') {
      final deleted = await shedding.delete(eventId: id, animalId: animal.id);
      return deleted
          ? _Reply(200, {'deleted': true})
          : _error(409, 'conflict', 'Shedding could not be deleted.');
    }
    return _error(404, 'not_found', 'Unknown Shedding operation.');
  }

  Future<_Reply> _media(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final media = MediaRepository(database);
    if (path.length == 1 && method == 'POST') {
      final input = await _body(request, maxBytes: 12 * 1024 * 1024);
      input.allow(const {'fileName', 'mimeType', 'dataBase64'});
      final image = _image(input);
      final id = await media.createMedia(
        fileName: image.fileName,
        mimeType: image.mimeType,
        data: image.bytes,
      );
      return _Reply(201, {'id': id});
    }
    if (path.length == 2 && method == 'GET') {
      final asset = await media.getMediaById(_pathId(path[1]));
      if (asset == null) return _error(404, 'not_found', 'Media not found.');
      return _Reply.bytes(200, asset.data, asset.mimeType);
    }
    return _error(404, 'not_found', 'Unknown Media operation.');
  }

  Future<void> _requireActiveAnimal(int id) async {
    final animal = await AnimalRepository(database).getAnimalById(id);
    if (animal == null || animal.status != AnimalStatus.active) {
      throw ApiProblem(409, 'conflict', 'Animal $id is not active.');
    }
  }

  Future<void> _requireMedia(int? id) async {
    if (id == null) return;
    if (await MediaRepository(database).getMediaById(id) == null) {
      throw ApiProblem(400, 'invalid_data', 'Media asset $id does not exist.');
    }
  }

  static _ImageUpload _image(ApiInput input) {
    final mime = input.string('mimeType', maxLength: 100);
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
      throw const ApiProblem(
        400,
        'invalid_data',
        'Unsupported image MIME type.',
      );
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(
        input.string('dataBase64', maxLength: 12 * 1024 * 1024),
      );
    } on FormatException {
      throw const ApiProblem(400, 'invalid_data', 'Invalid base64 image.');
    }
    if (bytes.isEmpty ||
        bytes.length > 8 * 1024 * 1024 ||
        !_validImageSignature(mime, bytes)) {
      throw const ApiProblem(
        400,
        'invalid_data',
        'Invalid or oversized image.',
      );
    }
    return (
      fileName: input.string('fileName', maxLength: 255),
      mimeType: mime,
      bytes: bytes,
    );
  }

  static double? _positiveOptional(ApiInput input, String key) {
    final value = input.nullableNumber(key);
    if (value != null && value <= 0) {
      throw ApiProblem(400, 'invalid_data', '$key must be positive.');
    }
    return value;
  }

  static int _pathId(String raw) {
    final id = int.tryParse(raw);
    if (id == null || id < 1) {
      throw const ApiProblem(400, 'invalid_data', 'Invalid record ID.');
    }
    return id;
  }

  static Future<ApiInput> _body(
    HttpRequest request, {
    int maxBytes = 256 * 1024,
  }) async {
    if (request.headers.contentType?.mimeType != 'application/json') {
      throw const ApiProblem(
        415,
        'unsupported_media_type',
        'Content-Type must be application/json.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final part in request) {
      builder.add(part);
      if (builder.length > maxBytes) {
        throw const ApiProblem(413, 'too_large', 'Request body is too large.');
      }
    }
    final String body;
    try {
      body = utf8.decode(builder.takeBytes());
    } on FormatException {
      throw const ApiProblem(400, 'invalid_json', 'Expected UTF-8 JSON.');
    }
    return ApiInput.decode(body);
  }

  static _Reply _error(int status, String code, String message) =>
      _Reply(status, {
        'error': {'code': code, 'message': message},
      });

  static Future<void> _send(HttpResponse response, _Reply reply) async {
    response.statusCode = reply.status;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    if (reply.bytes != null) {
      response.headers.contentType = ContentType.parse(reply.mimeType!);
      response.add(reply.bytes!);
    } else {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(reply.body));
    }
    await response.close();
  }

  static bool _validImageSignature(String mime, Uint8List bytes) {
    if (mime == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    }
    if (mime == 'image/png') {
      return bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
    }
    if (mime == 'image/webp') {
      return bytes.length >= 12 &&
          utf8.decode(bytes.sublist(0, 4)) == 'RIFF' &&
          utf8.decode(bytes.sublist(8, 12)) == 'WEBP';
    }
    return false;
  }
}

class _Reply {
  final int status;
  final _Payload? body;
  final Uint8List? bytes;
  final String? mimeType;

  const _Reply(this.status, this.body) : bytes = null, mimeType = null;

  const _Reply.bytes(this.status, this.bytes, this.mimeType) : body = null;
}

class _IdempotentReply {
  final DateTime createdAt;
  final String fingerprint;
  final Future<_Reply> result;

  const _IdempotentReply(this.createdAt, this.fingerprint, this.result);
}

typedef _ImageUpload = ({String fileName, String mimeType, Uint8List bytes});
