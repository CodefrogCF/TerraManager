import 'package:drift/drift.dart';

import '../../qr/qr_id_generator.dart';
import '../app_database.dart';

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

  Future<int> createBox(
    String qrId, {
    double? widthCm,
    double? heightCm,
    double? depthCm,
    int? pictureMediaId,
  }) {
    return database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: qrId,
            widthCm: Value(widthCm),
            heightCm: Value(heightCm),
            depthCm: Value(depthCm),
            pictureMediaId: Value(pictureMediaId),
          ),
        );
  }

  Future<int> createBoxWithGeneratedQrId({
    double? widthCm,
    double? heightCm,
    double? depthCm,
    int? pictureMediaId,
  }) {
    return createBox(
      generateBoxQrId(),
      widthCm: widthCm,
      heightCm: heightCm,
      depthCm: depthCm,
      pictureMediaId: pictureMediaId,
    );
  }

  Future<bool> updateBox({
    required int boxId,
    Value<double?> widthCm = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
    Value<double?> depthCm = const Value.absent(),
    Value<int?> pictureMediaId = const Value.absent(),
  }) async {
    return database.transaction(() async {
      final existing = await getBoxById(boxId);

      if (existing == null) {
        return false;
      }

      final oldPictureMediaId = existing.pictureMediaId;

      final updatedRows =
          await (database.update(
            database.boxes,
          )..where((box) => box.id.equals(boxId))).write(
            BoxesCompanion(
              widthCm: widthCm,
              heightCm: heightCm,
              depthCm: depthCm,
              pictureMediaId: pictureMediaId,
              updatedAt: Value(DateTime.now()),
            ),
          );

      if (updatedRows == 0) {
        return false;
      }

      if (pictureMediaId.present) {
        final newPictureMediaId = pictureMediaId.value;

        if (oldPictureMediaId != null &&
            oldPictureMediaId != newPictureMediaId) {
          await (database.delete(
            database.mediaAssets,
          )..where((media) => media.id.equals(oldPictureMediaId))).go();
        }
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

      final pictureMediaId = existing.pictureMediaId;

      final rowsDeleted = await (database.delete(
        database.boxes,
      )..where((box) => box.id.equals(boxId))).go();

      if (rowsDeleted == 0) {
        return false;
      }

      if (pictureMediaId != null) {
        await (database.delete(
          database.mediaAssets,
        )..where((media) => media.id.equals(pictureMediaId))).go();
      }

      return true;
    });
  }
}
