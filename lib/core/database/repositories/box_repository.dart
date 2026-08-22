import 'package:drift/drift.dart';

import '../app_database.dart';

class BoxRepository {
  final AppDatabase database;

  BoxRepository(this.database);

  Future<Box?> getBoxById(int boxId) {
    return (database.select(database.boxes)
          ..where((box) => box.id.equals(boxId)))
        .getSingleOrNull();
  }

  Future<Box?> getBoxByQrId(String qrId) {
    return (database.select(database.boxes)
          ..where((box) => box.qrId.equals(qrId)))
        .getSingleOrNull();
  }

  Future<List<Box>> getAllBoxes() {
    return database.select(database.boxes).get();
  }

  Future<int> createBox(String qrId) {
    return database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: qrId,
          ),
        );
  }

  Future<bool> updateBox({
    required int boxId,
    required String qrId,
  }) async {
    final updatedRows = await (database.update(database.boxes)
          ..where((box) => box.id.equals(boxId)))
        .write(
      BoxesCompanion(
        qrId: Value(qrId),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return updatedRows > 0;
  }

  Future<bool> deleteBox(int boxId) {
    return (database.delete(database.boxes)
          ..where((box) => box.id.equals(boxId)))
        .go()
        .then((rowsDeleted) => rowsDeleted > 0);
  }
}