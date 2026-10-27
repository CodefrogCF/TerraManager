import 'package:drift/drift.dart';

import '../app_database.dart';
import 'media_repository.dart';

class PictureGalleryEntry {
  const PictureGalleryEntry({
    required this.associationId,
    required this.media,
    required this.capturedAt,
    required this.sortOrder,
    required this.isPrimary,
  });

  final int associationId;
  final MediaAsset media;
  final DateTime capturedAt;
  final int sortOrder;
  final bool isPrimary;
}

class PictureGalleryRepository {
  PictureGalleryRepository(this.database);

  final AppDatabase database;

  Future<List<PictureGalleryEntry>> getAnimalPictures(int animalId) async {
    final animal = await (database.select(
      database.animals,
    )..where((row) => row.id.equals(animalId))).getSingleOrNull();
    if (animal == null) {
      return const [];
    }

    final query = database.select(database.animalPictureAssociations)
      ..where((row) => row.animalId.equals(animalId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.id),
      ]);
    final associations = await query.get();

    return _animalEntries(associations, animal.pictureMediaId);
  }

  Future<List<PictureGalleryEntry>> getBoxPictures(int boxId) async {
    final box = await (database.select(
      database.boxes,
    )..where((row) => row.id.equals(boxId))).getSingleOrNull();
    if (box == null) {
      return const [];
    }

    final query = database.select(database.boxPictureAssociations)
      ..where((row) => row.boxId.equals(boxId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.id),
      ]);
    final associations = await query.get();

    return _boxEntries(associations, box.pictureMediaId);
  }

  Future<int> addAnimalPicture({
    required int animalId,
    required String fileName,
    required String mimeType,
    required Uint8List data,
    DateTime? capturedAt,
    bool makePrimary = true,
  }) {
    return database.transaction(() async {
      await _requireAnimal(animalId);
      final mediaId = await MediaRepository(database)
          .createMedia(fileName: fileName, mimeType: mimeType, data: data);
      await _attachAnimalPicture(
        animalId: animalId,
        mediaId: mediaId,
        capturedAt: capturedAt,
        makePrimary: makePrimary,
      );
      return mediaId;
    });
  }

  Future<int> addBoxPicture({
    required int boxId,
    required String fileName,
    required String mimeType,
    required Uint8List data,
    DateTime? capturedAt,
    bool makePrimary = true,
  }) {
    return database.transaction(() async {
      await _requireBox(boxId);
      final mediaId = await MediaRepository(database)
          .createMedia(fileName: fileName, mimeType: mimeType, data: data);
      await _attachBoxPicture(
        boxId: boxId,
        mediaId: mediaId,
        capturedAt: capturedAt,
        makePrimary: makePrimary,
      );
      return mediaId;
    });
  }

  Future<void> ensureAnimalPictureAssociation({
    required int animalId,
    required int mediaId,
    DateTime? capturedAt,
    int? sortOrder,
    bool makePrimary = true,
  }) {
    return database.transaction(
      () => _attachAnimalPicture(
        animalId: animalId,
        mediaId: mediaId,
        capturedAt: capturedAt,
        sortOrder: sortOrder,
        makePrimary: makePrimary,
      ),
    );
  }

  Future<void> ensureBoxPictureAssociation({
    required int boxId,
    required int mediaId,
    DateTime? capturedAt,
    int? sortOrder,
    bool makePrimary = true,
  }) {
    return database.transaction(
      () => _attachBoxPicture(
        boxId: boxId,
        mediaId: mediaId,
        capturedAt: capturedAt,
        sortOrder: sortOrder,
        makePrimary: makePrimary,
      ),
    );
  }

  Future<bool> setAnimalPrimaryPicture({
    required int animalId,
    required int mediaId,
  }) {
    return database.transaction(() async {
      final association =
          await (database.select(database.animalPictureAssociations)..where(
                (row) =>
                    row.animalId.equals(animalId) &
                    row.mediaAssetId.equals(mediaId),
              ))
              .getSingleOrNull();
      if (association == null) {
        return false;
      }
      final updated =
          await (database.update(
            database.animals,
          )..where((row) => row.id.equals(animalId))).write(
            AnimalsCompanion(
              pictureMediaId: Value(mediaId),
              updatedAt: Value(DateTime.now()),
            ),
          );
      return updated == 1;
    });
  }

  Future<bool> setBoxPrimaryPicture({
    required int boxId,
    required int mediaId,
  }) {
    return database.transaction(() async {
      final association =
          await (database.select(database.boxPictureAssociations)..where(
                (row) =>
                    row.boxId.equals(boxId) & row.mediaAssetId.equals(mediaId),
              ))
              .getSingleOrNull();
      if (association == null) {
        return false;
      }
      final updated =
          await (database.update(
            database.boxes,
          )..where((row) => row.id.equals(boxId))).write(
            BoxesCompanion(
              pictureMediaId: Value(mediaId),
              updatedAt: Value(DateTime.now()),
            ),
          );
      return updated == 1;
    });
  }

  Future<void> clearAnimalPrimaryPicture(int animalId) async {
    await (database.update(
      database.animals,
    )..where((row) => row.id.equals(animalId))).write(
      AnimalsCompanion(
        pictureMediaId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> clearBoxPrimaryPicture(int boxId) async {
    await (database.update(
      database.boxes,
    )..where((row) => row.id.equals(boxId))).write(
      BoxesCompanion(
        pictureMediaId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<bool> deleteAnimalPicture({
    required int animalId,
    required int mediaId,
  }) {
    return database.transaction(() async {
      final animal = await _requireAnimal(animalId);
      final association =
          await (database.select(database.animalPictureAssociations)..where(
                (row) =>
                    row.animalId.equals(animalId) &
                    row.mediaAssetId.equals(mediaId),
              ))
              .getSingleOrNull();
      if (association == null) {
        return false;
      }

      if (animal.pictureMediaId == mediaId) {
        final replacement =
            await (database.select(database.animalPictureAssociations)
                  ..where(
                    (row) =>
                        row.animalId.equals(animalId) &
                        row.mediaAssetId.equals(mediaId).not(),
                  )
                  ..orderBy([
                    (row) => OrderingTerm.desc(row.sortOrder),
                    (row) => OrderingTerm.desc(row.id),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        await (database.update(
          database.animals,
        )..where((row) => row.id.equals(animalId))).write(
          AnimalsCompanion(
            pictureMediaId: Value(replacement?.mediaAssetId),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      await (database.delete(
        database.animalPictureAssociations,
      )..where((row) => row.id.equals(association.id))).go();
      await _deleteMediaIfUnreferenced(mediaId);
      return true;
    });
  }

  Future<bool> deleteBoxPicture({required int boxId, required int mediaId}) {
    return database.transaction(() async {
      final box = await _requireBox(boxId);
      final association =
          await (database.select(database.boxPictureAssociations)..where(
                (row) =>
                    row.boxId.equals(boxId) & row.mediaAssetId.equals(mediaId),
              ))
              .getSingleOrNull();
      if (association == null) {
        return false;
      }

      if (box.pictureMediaId == mediaId) {
        final replacement =
            await (database.select(database.boxPictureAssociations)
                  ..where(
                    (row) =>
                        row.boxId.equals(boxId) &
                        row.mediaAssetId.equals(mediaId).not(),
                  )
                  ..orderBy([
                    (row) => OrderingTerm.desc(row.sortOrder),
                    (row) => OrderingTerm.desc(row.id),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        await (database.update(
          database.boxes,
        )..where((row) => row.id.equals(boxId))).write(
          BoxesCompanion(
            pictureMediaId: Value(replacement?.mediaAssetId),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      await (database.delete(
        database.boxPictureAssociations,
      )..where((row) => row.id.equals(association.id))).go();
      await _deleteMediaIfUnreferenced(mediaId);
      return true;
    });
  }

  Future<List<int>> getAnimalGalleryMediaIds(int animalId) async {
    final rows = await (database.select(
      database.animalPictureAssociations,
    )..where((row) => row.animalId.equals(animalId))).get();
    return rows.map((row) => row.mediaAssetId).toList();
  }

  Future<List<int>> getBoxGalleryMediaIds(int boxId) async {
    final rows = await (database.select(
      database.boxPictureAssociations,
    )..where((row) => row.boxId.equals(boxId))).get();
    return rows.map((row) => row.mediaAssetId).toList();
  }

  Future<void> deleteUnreferencedMedia(Iterable<int> mediaIds) async {
    for (final mediaId in mediaIds.toSet()) {
      await _deleteMediaIfUnreferenced(mediaId);
    }
  }

  Future<void> duplicateAnimalGallery({
    required int sourceAnimalId,
    required int targetAnimalId,
  }) {
    return database.transaction(() async {
      final pictures = await getAnimalPictures(sourceAnimalId);
      int? targetPrimaryId;
      for (final picture in pictures) {
        final mediaId = await _copyMedia(picture.media);
        await _attachAnimalPicture(
          animalId: targetAnimalId,
          mediaId: mediaId,
          capturedAt: picture.capturedAt,
          sortOrder: picture.sortOrder,
          makePrimary: false,
        );
        if (picture.isPrimary) {
          targetPrimaryId = mediaId;
        }
      }
      if (targetPrimaryId != null) {
        await setAnimalPrimaryPicture(
          animalId: targetAnimalId,
          mediaId: targetPrimaryId,
        );
      }
    });
  }

  Future<void> duplicateBoxGallery({
    required int sourceBoxId,
    required int targetBoxId,
  }) {
    return database.transaction(() async {
      final pictures = await getBoxPictures(sourceBoxId);
      int? targetPrimaryId;
      for (final picture in pictures) {
        final mediaId = await _copyMedia(picture.media);
        await _attachBoxPicture(
          boxId: targetBoxId,
          mediaId: mediaId,
          capturedAt: picture.capturedAt,
          sortOrder: picture.sortOrder,
          makePrimary: false,
        );
        if (picture.isPrimary) {
          targetPrimaryId = mediaId;
        }
      }
      if (targetPrimaryId != null) {
        await setBoxPrimaryPicture(
          boxId: targetBoxId,
          mediaId: targetPrimaryId,
        );
      }
    });
  }

  Future<List<PictureGalleryEntry>> _animalEntries(
    List<AnimalPictureAssociation> associations,
    int? primaryMediaId,
  ) async {
    final entries = <PictureGalleryEntry>[];
    for (final association in associations) {
      final media = await MediaRepository(database)
          .getMediaById(association.mediaAssetId);
      if (media != null) {
        entries.add(
          PictureGalleryEntry(
            associationId: association.id,
            media: media,
            capturedAt: association.capturedAt,
            sortOrder: association.sortOrder,
            isPrimary: association.mediaAssetId == primaryMediaId,
          ),
        );
      }
    }
    return entries;
  }

  Future<List<PictureGalleryEntry>> _boxEntries(
    List<BoxPictureAssociation> associations,
    int? primaryMediaId,
  ) async {
    final entries = <PictureGalleryEntry>[];
    for (final association in associations) {
      final media = await MediaRepository(database)
          .getMediaById(association.mediaAssetId);
      if (media != null) {
        entries.add(
          PictureGalleryEntry(
            associationId: association.id,
            media: media,
            capturedAt: association.capturedAt,
            sortOrder: association.sortOrder,
            isPrimary: association.mediaAssetId == primaryMediaId,
          ),
        );
      }
    }
    return entries;
  }

  Future<void> _attachAnimalPicture({
    required int animalId,
    required int mediaId,
    DateTime? capturedAt,
    int? sortOrder,
    required bool makePrimary,
  }) async {
    await _requireAnimal(animalId);
    final media = await _requireMedia(mediaId);
    final existing =
        await (database.select(database.animalPictureAssociations)..where(
              (row) =>
                  row.animalId.equals(animalId) &
                  row.mediaAssetId.equals(mediaId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await database
          .into(database.animalPictureAssociations)
          .insert(
            AnimalPictureAssociationsCompanion.insert(
              animalId: animalId,
              mediaAssetId: mediaId,
              capturedAt: capturedAt ?? media.createdAt,
              sortOrder: sortOrder ?? await _nextAnimalSortOrder(animalId),
            ),
          );
    }
    if (makePrimary) {
      await (database.update(
        database.animals,
      )..where((row) => row.id.equals(animalId))).write(
        AnimalsCompanion(
          pictureMediaId: Value(mediaId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> _attachBoxPicture({
    required int boxId,
    required int mediaId,
    DateTime? capturedAt,
    int? sortOrder,
    required bool makePrimary,
  }) async {
    await _requireBox(boxId);
    final media = await _requireMedia(mediaId);
    final existing =
        await (database.select(database.boxPictureAssociations)..where(
              (row) =>
                  row.boxId.equals(boxId) & row.mediaAssetId.equals(mediaId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await database
          .into(database.boxPictureAssociations)
          .insert(
            BoxPictureAssociationsCompanion.insert(
              boxId: boxId,
              mediaAssetId: mediaId,
              capturedAt: capturedAt ?? media.createdAt,
              sortOrder: sortOrder ?? await _nextBoxSortOrder(boxId),
            ),
          );
    }
    if (makePrimary) {
      await (database.update(
        database.boxes,
      )..where((row) => row.id.equals(boxId))).write(
        BoxesCompanion(
          pictureMediaId: Value(mediaId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<int> _nextAnimalSortOrder(int animalId) async {
    final last =
        await (database.select(database.animalPictureAssociations)
              ..where((row) => row.animalId.equals(animalId))
              ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return (last?.sortOrder ?? -1) + 1;
  }

  Future<int> _nextBoxSortOrder(int boxId) async {
    final last =
        await (database.select(database.boxPictureAssociations)
              ..where((row) => row.boxId.equals(boxId))
              ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return (last?.sortOrder ?? -1) + 1;
  }

  Future<Animal> _requireAnimal(int animalId) async {
    final animal = await (database.select(
      database.animals,
    )..where((row) => row.id.equals(animalId))).getSingleOrNull();
    if (animal == null) {
      throw StateError('Animal $animalId does not exist');
    }
    return animal;
  }

  Future<Box> _requireBox(int boxId) async {
    final box = await (database.select(
      database.boxes,
    )..where((row) => row.id.equals(boxId))).getSingleOrNull();
    if (box == null) {
      throw StateError('Box $boxId does not exist');
    }
    return box;
  }

  Future<MediaAsset> _requireMedia(int mediaId) async {
    final media = await MediaRepository(database).getMediaById(mediaId);
    if (media == null) {
      throw StateError('Media asset $mediaId does not exist');
    }
    return media;
  }

  Future<int> _copyMedia(MediaAsset source) {
    return database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: source.fileName,
            mimeType: source.mimeType,
            data: Uint8List.fromList(source.data),
            createdAt: Value(source.createdAt),
            updatedAt: Value(source.updatedAt),
          ),
        );
  }

  Future<void> _deleteMediaIfUnreferenced(int mediaId) async {
    final animalAssociation = await (database.select(
      database.animalPictureAssociations,
    )..where((row) => row.mediaAssetId.equals(mediaId))).getSingleOrNull();
    final boxAssociation = await (database.select(
      database.boxPictureAssociations,
    )..where((row) => row.mediaAssetId.equals(mediaId))).getSingleOrNull();
    final animalPrimary = await (database.select(
      database.animals,
    )..where((row) => row.pictureMediaId.equals(mediaId))).getSingleOrNull();
    final boxPrimary = await (database.select(
      database.boxes,
    )..where((row) => row.pictureMediaId.equals(mediaId))).getSingleOrNull();

    if (animalAssociation == null &&
        boxAssociation == null &&
        animalPrimary == null &&
        boxPrimary == null) {
      await MediaRepository(database).deleteMedia(mediaId);
    }
  }
}
