import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters/birth_date_accuracy_converter.dart';
import 'converters/sex_converter.dart';
import 'enums/birth_date_accuracy.dart';
import 'enums/sex.dart';

import 'tables/boxes.dart';
import 'tables/animals.dart';
import 'tables/feeding_events.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Boxes,
    Animals,
    FeedingEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(
    driftDatabase(
      name: 'terramanager',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    )
  );

  AppDatabase.test(super.executor);

  @override
  int get schemaVersion => 1;
}