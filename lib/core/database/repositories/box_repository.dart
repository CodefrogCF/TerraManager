import 'package:drift/drift.dart';

import '../../qr/qr_id_generator.dart';
import '../app_database.dart';
import '../enums/box_status.dart';
import '../enums/box_archive_reason.dart';
import 'animal_repository.dart';
import 'box_lifecycle_exception.dart';
import 'picture_gallery_repository.dart';

class BoxRepository {
  final AppDatabase database;

  BoxRepository(this.database);

  Future<Box?> getBoxById(int boxId) {
    return (database.select(
      database.boxes,
    )..where((box) => box.id.equals(boxId))).getSingleOrNull();
  }

  Future<Box?> getBoxByQrId(String qrId) {
    return (database.select(
      database.boxes,
    )..where((box) => box.qrId.equals(qrId))).getSingleOrNull();
  }

  Future<List<Box>> getAllBoxes() {
    return database.select(database.boxes).get();
  }

  Future<List<Box>> getActiveBoxes() {
    return (database.select(
      database.boxes,
    )..where((box) => box.status.equalsValue(BoxStatus.active))).get();
  }

  Future<List<Box>> getArchivedBoxes() {
    return (database.select(database.boxes)
          ..where((box) => box.status.equalsValue(BoxStatus.archived))
          ..orderBy([
            (box) => OrderingTerm.desc(box.archivedAt),
            (box) => OrderingTerm.desc(box.id),
          ]))
        .get();
  }

  Future<bool> archiveBox({
    required int boxId,
    required BoxArchiveReason reason,
    required DateTime archivedAt,
    String? archiveNotes,
  }) {
    return database.transaction(() async {
      final box = await getBoxById(boxId);
      if (box == null || box.status != BoxStatus.active) {
        return false;
      }
      final animals = await AnimalRepository(database).getAnimalsForBox(boxId);
      if (animals.isNotEmpty) {
        throw BoxArchiveBlockedException(animals);
      }
      final notes = archiveNotes?.trim();
      final updated =
          await (database.update(database.boxes)..where(
                (box) =>
                    box.id.equals(boxId) &
                    box.status.equalsValue(BoxStatus.active),
              ))
              .write(
                BoxesCompanion(
                  status: const Value(BoxStatus.archived),
                  archiveReason: Value(reason),
                  archivedAt: Value(archivedAt),
                  archiveNotes: Value(
                    notes == null || notes.isEmpty ? null : notes,
                  ),
                  updatedAt: Value(DateTime.now()),
                ),
              );
      return updated == 1;
    });
  }

  Future<bool> restoreBox(int boxId) async {
    final updated =
        await (database.update(database.boxes)..where(
              (box) =>
                  box.id.equals(boxId) &
                  box.status.equalsValue(BoxStatus.archived),
            ))
            .write(
              BoxesCompanion(
                status: const Value(BoxStatus.active),
                archiveReason: const Value(null),
                archivedAt: const Value(null),
                archiveNotes: const Value(null),
                updatedAt: Value(DateTime.now()),
              ),
            );
    return updated == 1;
  }

  Future<int> createBox(
    String qrId, {
    String? name,
    double? widthCm,
    double? heightCm,
    double? depthCm,
    String? temperatureZones,
    String? notes,
    int? pictureMediaId,
  }) {
    return database.transaction(() async {
      final boxId = await database
          .into(database.boxes)
          .insert(
            BoxesCompanion.insert(
              qrId: qrId,
              name: Value(name),
              widthCm: Value(widthCm),
              heightCm: Value(heightCm),
              depthCm: Value(depthCm),
              temperatureZones: Value(temperatureZones),
              notes: Value(notes),
              pictureMediaId: Value(pictureMediaId),
            ),
          );
      if (pictureMediaId != null) {
        await PictureGalleryRepository(database)
            .ensureBoxPictureAssociation(boxId: boxId, mediaId: pictureMediaId);
      }
      return boxId;
    });
  }

  Future<int> createBoxWithGeneratedQrId({
    String? name,
    double? widthCm,
    double? heightCm,
    double? depthCm,
    String? temperatureZones,
    String? notes,
    int? pictureMediaId,
  }) {
    return createBox(
      generateBoxQrId(),
      name: name,
      widthCm: widthCm,
      heightCm: heightCm,
      depthCm: depthCm,
      temperatureZones: temperatureZones,
      notes: notes,
      pictureMediaId: pictureMediaId,
    );
  }

  Future<bool> renameBox({required int boxId, required String? name}) async {
    final normalizedName = name?.trim();
    final updatedRows =
        await (database.update(database.boxes)..where(
              (box) =>
                  box.id.equals(boxId) &
                  box.status.equalsValue(BoxStatus.active),
            ))
            .write(
              BoxesCompanion(
                name: Value(
                  normalizedName == null || normalizedName.isEmpty
                      ? null
                      : normalizedName,
                ),
                updatedAt: Value(DateTime.now()),
              ),
            );

    return updatedRows == 1;
  }

  Future<int> duplicateBox({required int sourceBoxId, required String? name}) {
    return database.transaction(() async {
      final source = await getBoxById(sourceBoxId);
      if (source == null) {
        throw StateError('Box $sourceBoxId does not exist');
      }

      final galleryRepository = PictureGalleryRepository(database);
      if (source.pictureMediaId != null) {
        await galleryRepository.ensureBoxPictureAssociation(
          boxId: source.id,
          mediaId: source.pictureMediaId!,
          makePrimary: false,
        );
      }
      final normalizedName = name?.trim();

      final targetBoxId = await createBoxWithGeneratedQrId(
        name: normalizedName == null || normalizedName.isEmpty
            ? null
            : normalizedName,
        widthCm: source.widthCm,
        heightCm: source.heightCm,
        depthCm: source.depthCm,
        temperatureZones: source.temperatureZones,
        notes: source.notes,
      );
      await galleryRepository.duplicateBoxGallery(
        sourceBoxId: source.id,
        targetBoxId: targetBoxId,
      );
      return targetBoxId;
    });
  }

  Future<bool> updateBox({
    required int boxId,
    Value<String?> name = const Value.absent(),
    Value<double?> widthCm = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
    Value<double?> depthCm = const Value.absent(),
    Value<String?> temperatureZones = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<int?> pictureMediaId = const Value.absent(),
  }) async {
    return database.transaction(() async {
      final existing = await getBoxById(boxId);

      if (existing == null) {
        return false;
      }

      final updatedRows =
          await (database.update(
            database.boxes,
          )..where((box) => box.id.equals(boxId))).write(
            BoxesCompanion(
              name: name,
              widthCm: widthCm,
              heightCm: heightCm,
              depthCm: depthCm,
              temperatureZones: temperatureZones,
              notes: notes,
              pictureMediaId: pictureMediaId,
              updatedAt: Value(DateTime.now()),
            ),
          );

      if (updatedRows == 0) {
        return false;
      }

      if (pictureMediaId.present && pictureMediaId.value != null) {
        await PictureGalleryRepository(database).ensureBoxPictureAssociation(
          boxId: boxId,
          mediaId: pictureMediaId.value!,
        );
      }

      return true;
    });
  }

  Future<bool> deleteBox(int boxId) async {
    return database.transaction(() async {
      final existing = await getBoxById(boxId);

      if (existing == null) {
        return false;
      }

      final galleryRepository = PictureGalleryRepository(database);
      final mediaIds = await galleryRepository.getBoxGalleryMediaIds(boxId);
      if (existing.pictureMediaId != null) {
        mediaIds.add(existing.pictureMediaId!);
      }

      final rowsDeleted = await (database.delete(
        database.boxes,
      )..where((box) => box.id.equals(boxId))).go();

      if (rowsDeleted == 0) {
        return false;
      }

      await galleryRepository.deleteUnreferencedMedia(mediaIds);

      return true;
    });
  }

  Future<bool> permanentlyDeleteArchivedBox(int boxId) async {
    return database.transaction(() async {
      final existing = await getBoxById(boxId);

      if (existing == null || existing.status != BoxStatus.archived) {
        return false;
      }

      final galleryRepository = PictureGalleryRepository(database);
      final mediaIds = await galleryRepository.getBoxGalleryMediaIds(boxId);
      if (existing.pictureMediaId != null) {
        mediaIds.add(existing.pictureMediaId!);
      }

      final rowsDeleted =
          await (database.delete(database.boxes)..where(
                (box) =>
                    box.id.equals(boxId) &
                    box.status.equalsValue(BoxStatus.archived),
              ))
              .go();

      if (rowsDeleted != 1) {
        return false;
      }

      await galleryRepository.deleteUnreferencedMedia(mediaIds);

      return true;
    });
  }
}
