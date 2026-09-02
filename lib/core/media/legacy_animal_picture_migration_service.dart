import 'package:drift/drift.dart';
import 'package:image_picker/image_picker.dart';

import '../database/app_database.dart';
import '../database/repositories/media_repository.dart';
import 'image_media_info.dart';

class LegacyPictureData {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const LegacyPictureData({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

class LegacyPictureMigrationResult {
  final int migrated;
  final int skipped;

  const LegacyPictureMigrationResult({
    required this.migrated,
    required this.skipped,
  });
}

typedef LegacyPictureReader = Future<LegacyPictureData> Function(String path);

class LegacyAnimalPictureMigrationService {
  final AppDatabase database;
  final LegacyPictureReader _pictureReader;

  LegacyAnimalPictureMigrationService(
    this.database, {
    LegacyPictureReader? pictureReader,
  }) : _pictureReader = pictureReader ?? _readPicture;

  Future<LegacyPictureMigrationResult> migrate() async {
    final query = database.select(database.animals)
      ..where(
        (animal) =>
            animal.pictureMediaId.isNull() & animal.picturePath.isNotNull(),
      );

    final animals = await query.get();

    var migrated = 0;
    var skipped = 0;

    for (final animal in animals) {
      final path = animal.picturePath?.trim();

      if (path == null || path.isEmpty) {
        skipped++;
        continue;
      }

      try {
        final picture = await _pictureReader(path);

        if (picture.bytes.isEmpty) {
          skipped++;
          continue;
        }

        final wasMigrated = await database.transaction(() async {
          final current = await (database.select(
            database.animals,
          )..where((row) => row.id.equals(animal.id))).getSingleOrNull();

          if (current == null ||
              current.pictureMediaId != null ||
              current.picturePath != animal.picturePath) {
            return false;
          }

          final mediaId = await MediaRepository(database).createMedia(
            fileName: picture.fileName,
            mimeType: picture.mimeType,
            data: picture.bytes,
          );

          final updated =
              await (database.update(database.animals)..where(
                    (row) =>
                        row.id.equals(animal.id) & row.pictureMediaId.isNull(),
                  ))
                  .write(
                    AnimalsCompanion(
                      pictureMediaId: Value(mediaId),
                      picturePath: const Value(null),
                      updatedAt: Value(DateTime.now()),
                    ),
                  );

          if (updated != 1) {
            throw StateError(
              'Failed to migrate legacy picture '
              'for animal ${animal.id}',
            );
          }

          return true;
        });

        if (wasMigrated) {
          migrated++;
        } else {
          skipped++;
        }
      } catch (_) {
        // Legacy paths may already be invalid,
        // especially browser Blob URLs.
        // Preserve picturePath and continue.
        skipped++;
      }
    }

    return LegacyPictureMigrationResult(migrated: migrated, skipped: skipped);
  }

  static Future<LegacyPictureData> _readPicture(String path) async {
    final file = XFile(path);

    final bytes = await file.readAsBytes();

    final info = ImageMediaInfo.fromXFile(file);

    return LegacyPictureData(
      fileName: info.fileName,
      mimeType: info.mimeType,
      bytes: bytes,
    );
  }
}
