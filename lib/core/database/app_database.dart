import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/boxes.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Boxes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'terramananager'));

  @override
  int get schemaVersion => 1;
}