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
}