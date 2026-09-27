import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class BoxOperations extends CollectionOperations {
  BoxOperations(super.database);
  Future<Box?> getBoxById(int id) => BoxRepository(database).getBoxById(id);
  Future<ApiReply> list() async {
    final boxes = BoxRepository(database);

    return ApiReply(200, {
      'boxes': (await boxes.getAllBoxes()).map(boxJson).toList(),
    });
  }

  Future<ApiReply> create(ApiInput input) async {
    final boxes = BoxRepository(database);

    input.allow(const {
      'name',
      'widthCm',
      'heightCm',
      'depthCm',
      'temperatureZones',
      'notes',
      'pictureMediaId',
    });
    final width = positiveOptional(input, 'widthCm');
    final height = positiveOptional(input, 'heightCm');
    final depth = positiveOptional(input, 'depthCm');
    final mediaId = input.nullableInteger('pictureMediaId');
    await requireMedia(mediaId);
    final id = await boxes.createBoxWithGeneratedQrId(
      name: input.nullableString('name', maxLength: 200),
      widthCm: width,
      heightCm: height,
      depthCm: depth,
      temperatureZones: input.nullableString('temperatureZones'),
      notes: input.nullableString('notes'),
      pictureMediaId: mediaId,
    );
    return ApiReply(201, {'box': boxJson((await boxes.getBoxById(id))!)});
  }

  Future<ApiReply> findByQrId(String qrId) async {
    final boxes = BoxRepository(database);

    final box = await boxes.getBoxByQrId(qrId);
    return box == null
        ? apiError(404, 'not_found', 'Box not found.')
        : ApiReply(200, {'box': boxJson(box)});
  }

  Future<ApiReply> duplicate(int id, ApiInput input) async {
    final boxes = BoxRepository(database);

    input.allow(const {'name'});
    final newId = await boxes.duplicateBox(
      sourceBoxId: id,
      name: input.nullableString('name', maxLength: 200),
    );
    return ApiReply(201, {'box': boxJson((await boxes.getBoxById(newId))!)});
  }

  Future<ApiReply> update(int id, Box existing, ApiInput input) async {
    final boxes = BoxRepository(database);

    if (existing.status != BoxStatus.active) {
      return apiError(409, 'conflict', 'Only active Boxes can be edited.');
    }

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
      return apiError(400, 'invalid_data', 'No fields to update.');
    }
    final mediaId = input.nullableInteger('pictureMediaId');
    if (input.values.containsKey('pictureMediaId')) {
      await requireMedia(mediaId);
    }
    final updated = await database.transaction(() async {
      final current = await boxes.getBoxById(id);
      requireRevision(
        current == null ? null : boxJson(current),
        expectedRevision,
      );
      return boxes.updateBox(
        boxId: id,
        name: input.values.containsKey('name')
            ? Value(input.nullableString('name', maxLength: 200))
            : const Value.absent(),
        widthCm: input.values.containsKey('widthCm')
            ? Value(positiveOptional(input, 'widthCm'))
            : const Value.absent(),
        heightCm: input.values.containsKey('heightCm')
            ? Value(positiveOptional(input, 'heightCm'))
            : const Value.absent(),
        depthCm: input.values.containsKey('depthCm')
            ? Value(positiveOptional(input, 'depthCm'))
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
        ? ApiReply(200, {'box': boxJson((await boxes.getBoxById(id))!)})
        : apiError(409, 'conflict', 'Box could not be updated.');
  }

  Future<ApiReply> archive(int id, ApiInput input) async {
    final boxes = BoxRepository(database);

    input.allow(const {'reason', 'archivedAt', 'archiveNotes'});
    final archived = await boxes.archiveBox(
      boxId: id,
      reason: input.enumerated('reason', BoxArchiveReason.values),
      archivedAt: input.dateTime('archivedAt', fallback: DateTime.now()),
      archiveNotes: input.nullableString('archiveNotes'),
    );
    return archived
        ? ApiReply(200, {'box': boxJson((await boxes.getBoxById(id))!)})
        : apiError(409, 'conflict', 'Box is not active.');
  }

  Future<ApiReply> restore(int id) async {
    final boxes = BoxRepository(database);

    final restored = await boxes.restoreBox(id);
    return restored
        ? ApiReply(200, {'box': boxJson((await boxes.getBoxById(id))!)})
        : apiError(409, 'conflict', 'Box is not archived.');
  }

  Future<ApiReply> delete(int id) async {
    final boxes = BoxRepository(database);

    final deleted = await boxes.permanentlyDeleteArchivedBox(id);
    return deleted
        ? ApiReply(200, {'deleted': true})
        : apiError(409, 'conflict', 'Only archived Boxes can be deleted.');
  }
}
