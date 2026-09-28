import 'dart:async';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/shared_server/media/application/image_upload_validation.dart';
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

  Future<ApiReply> boxCreate(Box box, ApiInput input) async {
    final pictures = PictureGalleryRepository(database);

    input.allow(const {
      'fileName',
      'mimeType',
      'dataBase64',
      'capturedAt',
      'makePrimary',
    });
    final image = decodeImageUpload(input);
    final mediaId = await pictures.addBoxPicture(
      boxId: box.id,
      fileName: image.fileName,
      mimeType: image.mimeType,
      data: image.bytes,
      capturedAt: input.nullableDateTime('capturedAt'),
      makePrimary: input.boolean('makePrimary', fallback: true),
    );
    final entries = await pictures.getBoxPictures(box.id);
    return ApiReply(201, {
      'picture': pictureJson(
        entries.firstWhere((entry) => entry.media.id == mediaId),
      ),
    });
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

  Future<ApiReply> animalCreate(Animal animal, ApiInput input) async {
    final pictures = PictureGalleryRepository(database);

    input.allow(const {
      'fileName',
      'mimeType',
      'dataBase64',
      'capturedAt',
      'makePrimary',
    });
    final image = decodeImageUpload(input);
    final mediaId = await pictures.addAnimalPicture(
      animalId: animal.id,
      fileName: image.fileName,
      mimeType: image.mimeType,
      data: image.bytes,
      capturedAt: input.nullableDateTime('capturedAt'),
      makePrimary: input.boolean('makePrimary', fallback: true),
    );
    final entries = await pictures.getAnimalPictures(animal.id);
    return ApiReply(201, {
      'picture': pictureJson(
        entries.firstWhere((entry) => entry.media.id == mediaId),
      ),
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
