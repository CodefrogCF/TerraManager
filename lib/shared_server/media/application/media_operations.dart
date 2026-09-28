import 'dart:async';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/shared_server/media/application/image_upload_validation.dart';
import 'package:terramanager/shared_server/media/infrastructure/picture_upload_requests.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class MediaOperations extends CollectionOperations {
  MediaOperations(super.database);

  Future<MediaAsset?> getMediaById(int id) =>
      MediaRepository(database).getMediaById(id);
  Future<List<PictureGalleryEntry>> getBoxPictures(int id) =>
      PictureGalleryRepository(database).getBoxPictures(id);
  Future<List<PictureGalleryEntry>> getAnimalPictures(int id) =>
      PictureGalleryRepository(database).getAnimalPictures(id);

  Future<ApiReply> boxList(Box box) async {
    final pictures = PictureGalleryRepository(database);

    return ApiReply(200, {
      'pictures': (await pictures.getBoxPictures(box.id))
          .map(pictureJson)
          .toList(),
    });
  }

  Future<ApiReply> boxCreate(
    Box box,
    ApiInput input,
    String? requestKey,
  ) async {
    final pictures = PictureGalleryRepository(database);
    return _createPicture(
      kind: 'boxes',
      recordId: box.id,
      input: input,
      requestKey: requestKey,
      add: (image, capturedAt, makePrimary) => pictures.addBoxPicture(
        boxId: box.id,
        fileName: image.fileName,
        mimeType: image.mimeType,
        data: image.bytes,
        capturedAt: capturedAt,
        makePrimary: makePrimary,
      ),
      list: () => pictures.getBoxPictures(box.id),
    );
  }

  Future<ApiReply> boxPrimary(Box box, int mediaId) async {
    final pictures = PictureGalleryRepository(database);

    final changed = await pictures.setBoxPrimaryPicture(
      boxId: box.id,
      mediaId: mediaId,
    );
    return changed
        ? ApiReply(200, {'pictureMediaId': mediaId})
        : apiError(404, 'not_found', 'Box picture not found.');
  }

  Future<ApiReply> boxDelete(Box box, int mediaId) async {
    final pictures = PictureGalleryRepository(database);

    final deleted = await pictures.deleteBoxPicture(
      boxId: box.id,
      mediaId: mediaId,
    );
    return deleted
        ? ApiReply(200, {'deleted': true})
        : apiError(404, 'not_found', 'Box picture not found.');
  }

  Future<ApiReply> animalList(Animal animal) async {
    final pictures = PictureGalleryRepository(database);

    return ApiReply(200, {
      'pictures': (await pictures.getAnimalPictures(animal.id))
          .map(pictureJson)
          .toList(),
    });
  }

  Future<ApiReply> animalCreate(
    Animal animal,
    ApiInput input,
    String? requestKey,
  ) async {
    final pictures = PictureGalleryRepository(database);
    return _createPicture(
      kind: 'animals',
      recordId: animal.id,
      input: input,
      requestKey: requestKey,
      add: (image, capturedAt, makePrimary) => pictures.addAnimalPicture(
        animalId: animal.id,
        fileName: image.fileName,
        mimeType: image.mimeType,
        data: image.bytes,
        capturedAt: capturedAt,
        makePrimary: makePrimary,
      ),
      list: () => pictures.getAnimalPictures(animal.id),
    );
  }

  Future<ApiReply> _createPicture({
    required String kind,
    required int recordId,
    required ApiInput input,
    required String? requestKey,
    required Future<int> Function(ImageUpload, DateTime?, bool) add,
    required Future<List<PictureGalleryEntry>> Function() list,
  }) async {
    input.allow(const {
      'fileName',
      'mimeType',
      'dataBase64',
      'capturedAt',
      'makePrimary',
    });
    if (requestKey != null &&
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(requestKey)) {
      throw const ApiProblem(
        400,
        'invalid_data',
        'Idempotency-Key must be a UUID.',
      );
    }
    final image = decodeImageUpload(input);
    final capturedAt = input.nullableDateTime('capturedAt');
    final makePrimary = input.boolean('makePrimary', fallback: true);
    final receipts = PictureUploadRequests(database);
    final fingerprint = requestKey == null
        ? null
        : PictureUploadRequests.fingerprint(
            fileName: image.fileName,
            mimeType: image.mimeType,
            bytes: image.bytes,
            capturedAt: capturedAt,
            makePrimary: makePrimary,
          );
    return database.transaction(() async {
      if (requestKey != null) {
        await receipts.prune();
        final previous = await receipts.find(requestKey);
        if (previous != null) {
          if (previous.kind != kind ||
              previous.recordId != recordId ||
              previous.payloadHash != fingerprint) {
            return apiError(
              409,
              'idempotency_conflict',
              'Request key was reused with different picture data.',
            );
          }
          final entries = await list();
          for (final entry in entries) {
            if (entry.media.id == previous.mediaId) {
              return ApiReply(201, {
                'picture': pictureJson(entry),
              }, replayed: true);
            }
          }
          return apiError(
            409,
            'idempotency_conflict',
            'The original picture is no longer in this gallery.',
          );
        }
      }

      final mediaId = await add(image, capturedAt, makePrimary);
      if (requestKey != null) {
        await receipts.remember(
          key: requestKey,
          kind: kind,
          recordId: recordId,
          payloadHash: fingerprint!,
          mediaId: mediaId,
        );
      }
      final entries = await list();
      return ApiReply(201, {
        'picture': pictureJson(
          entries.firstWhere((entry) => entry.media.id == mediaId),
        ),
      });
    });
  }

  Future<ApiReply> animalPrimary(Animal animal, int mediaId) async {
    final pictures = PictureGalleryRepository(database);

    final changed = await pictures.setAnimalPrimaryPicture(
      animalId: animal.id,
      mediaId: mediaId,
    );
    return changed
        ? ApiReply(200, {'pictureMediaId': mediaId})
        : apiError(404, 'not_found', 'Animal picture not found.');
  }

  Future<ApiReply> animalDelete(Animal animal, int mediaId) async {
    final pictures = PictureGalleryRepository(database);

    final deleted = await pictures.deleteAnimalPicture(
      animalId: animal.id,
      mediaId: mediaId,
    );
    return deleted
        ? ApiReply(200, {'deleted': true})
        : apiError(404, 'not_found', 'Animal picture not found.');
  }
}
