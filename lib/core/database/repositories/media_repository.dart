import 'package:drift/drift.dart';

import '../app_database.dart';

class MediaRepository {
  final AppDatabase database;

  MediaRepository(this.database);

  Future<MediaAsset?> getMediaById(int mediaId) {
    return (database.select(
      database.mediaAssets,
    )..where((media) => media.id.equals(mediaId))).getSingleOrNull();
  }

  Future<int> createMedia({
    required String fileName,
    required String mimeType,
    required Uint8List data,
  }) {
    if (fileName.trim().isEmpty) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'File name must not be empty',
      );
    }

    if (mimeType.trim().isEmpty) {
      throw ArgumentError.value(
        mimeType,
        'mimeType',
        'MIME type must not be empty',
      );
    }

    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'Media data must not be empty');
    }

    return database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: fileName.trim(),
            mimeType: mimeType.trim(),
            data: data,
          ),
        );
  }

  Future<bool> updateMedia({
    required int mediaId,
    required String fileName,
    required String mimeType,
    required Uint8List data,
  }) async {
    if (fileName.trim().isEmpty) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'File name must not be empty',
      );
    }

    if (mimeType.trim().isEmpty) {
      throw ArgumentError.value(
        mimeType,
        'mimeType',
        'MIME type must not be empty',
      );
    }

    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'Media data must not be empty');
    }

    final updatedRows =
        await (database.update(
          database.mediaAssets,
        )..where((media) => media.id.equals(mediaId))).write(
          MediaAssetsCompanion(
            fileName: Value(fileName.trim()),
            mimeType: Value(mimeType.trim()),
            data: Value(data),
            updatedAt: Value(DateTime.now()),
          ),
        );

    return updatedRows == 1;
  }

  Future<bool> deleteMedia(int mediaId) async {
    final deletedRows = await (database.delete(
      database.mediaAssets,
    )..where((media) => media.id.equals(mediaId))).go();

    return deletedRows == 1;
  }
}
