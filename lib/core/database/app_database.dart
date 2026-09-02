import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters/birth_date_accuracy_converter.dart';
import 'converters/sex_converter.dart';
import 'converters/animal_archive_reason_converter.dart';
import 'converters/animal_status_converter.dart';
import 'enums/animal_archive_reason.dart';
import 'enums/animal_status.dart';
import 'enums/birth_date_accuracy.dart';
import 'enums/sex.dart';

import 'tables/boxes.dart';
import 'tables/animals.dart';
import 'tables/feeding_events.dart';
import 'tables/media_assets.dart';

import 'app_database.steps.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Boxes, MediaAssets, Animals, FeedingEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'terramanager',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.dart.js'),
              ),
            ),
      );

  AppDatabase.test(super.executor);

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        await customStatement('PRAGMA foreign_keys = OFF');

        try {
          await m.runMigrationSteps(
            from: from,
            to: to,
            steps: migrationSteps(
              from1To2: (m, schema) async {
                await m.alterTable(
                  TableMigration(
                    schema.animals,
                    newColumns: [
                      schema.animals.status,
                      schema.animals.archiveReason,
                      schema.animals.archivedAt,
                      schema.animals.archiveNotes,
                    ],
                  ),
                );
              },

              from2To3: (m, schema) async {
                await m.createTable(schema.mediaAssets);

                await m.addColumn(
                  schema.animals,
                  schema.animals.pictureMediaId,
                );
              },
            ),
          );

          final foreignKeyErrors = await customSelect(
            'PRAGMA foreign_key_check',
          ).get();

          if (foreignKeyErrors.isNotEmpty) {
            throw StateError(
              'Foreign key violations after migration: '
              '${foreignKeyErrors.map((row) => row.data).toList()}',
            );
          }
        } finally {
          await customStatement('PRAGMA foreign_keys = ON');
        }
      },
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  @override
  int get schemaVersion => 3;
}
