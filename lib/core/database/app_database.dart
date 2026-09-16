import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters/birth_date_accuracy_converter.dart';
import 'converters/animal_category_converter.dart';
import 'converters/sex_converter.dart';
import 'converters/box_status_converter.dart';
import 'converters/box_archive_reason_converter.dart';
import 'enums/box_status.dart';
import 'enums/box_archive_reason.dart';
import 'converters/animal_archive_reason_converter.dart';
import 'converters/animal_status_converter.dart';
import 'enums/animal_archive_reason.dart';
import 'enums/animal_category.dart';
import 'enums/animal_status.dart';
import 'enums/birth_date_accuracy.dart';
import 'enums/sex.dart';

import 'tables/boxes.dart';
import 'tables/animals.dart';
import 'tables/animal_picture_associations.dart';
import 'tables/box_picture_associations.dart';
import 'tables/feeding_events.dart';
import 'tables/media_assets.dart';

import 'app_database.steps.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Boxes,
    MediaAssets,
    Animals,
    FeedingEvents,
    AnimalPictureAssociations,
    BoxPictureAssociations,
  ],
)
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
              from3To4: (m, schema) async {
                await m.addColumn(schema.boxes, schema.boxes.widthCm);

                await m.addColumn(schema.boxes, schema.boxes.heightCm);

                await m.addColumn(schema.boxes, schema.boxes.depthCm);

                await m.addColumn(schema.boxes, schema.boxes.pictureMediaId);
              },
              from4To5: (m, schema) async {
                await m.addColumn(
                  schema.animals,
                  schema.animals.feedingReminderIntervalDays,
                );

                await m.addColumn(
                  schema.animals,
                  schema.animals.feedingReminderBaseline,
                );
              },
              from5To6: (m, schema) async {
                await m.addColumn(schema.boxes, schema.boxes.notes);
              },
              from6To7: (m, schema) async {
                await m.addColumn(schema.boxes, schema.boxes.name);
              },
              from7To8: (m, schema) async {
                await m.addColumn(schema.boxes, schema.boxes.status);
                await m.addColumn(schema.boxes, schema.boxes.archiveReason);
                await m.addColumn(schema.boxes, schema.boxes.archivedAt);
                await m.addColumn(schema.boxes, schema.boxes.archiveNotes);
              },
              from8To9: (m, schema) async {
                await m.addColumn(schema.animals, schema.animals.originHabitat);
                await m.addColumn(schema.animals, schema.animals.weight);
                await m.addColumn(schema.animals, schema.animals.sheddingNotes);
                await m.addColumn(
                  schema.animals,
                  schema.animals.restOrDormancyPeriods,
                );
                await m.addColumn(
                  schema.animals,
                  schema.animals.temperatureZones,
                );
              },
              from9To10: (m, schema) async {
                await m.addColumn(schema.animals, schema.animals.category);
                await m.addColumn(schema.animals, schema.animals.subcategory);
              },
              from10To11: (m, schema) async {
                await m.addColumn(schema.boxes, schema.boxes.temperatureZones);
                await copyLegacyAnimalTemperatureZonesToBoxes();
              },
              from11To12: (m, schema) async {
                await m.createTable(schema.animalPictureAssociations);
                await m.createTable(schema.boxPictureAssociations);
                await migrateExistingPicturesToGalleries();
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
  int get schemaVersion => 12;

  Future<void> migrateExistingPicturesToGalleries() async {
    await customStatement('''
      INSERT INTO animal_picture_associations
        (animal_id, media_asset_id, captured_at, sort_order)
      SELECT animals.id, media_assets.id, media_assets.created_at, 0
      FROM animals
      INNER JOIN media_assets
        ON media_assets.id = animals.picture_media_id
      WHERE animals.picture_media_id IS NOT NULL
    ''');

    await customStatement('''
      INSERT INTO box_picture_associations
        (box_id, media_asset_id, captured_at, sort_order)
      SELECT boxes.id, media_assets.id, media_assets.created_at, 0
      FROM boxes
      INNER JOIN media_assets
        ON media_assets.id = boxes.picture_media_id
      WHERE boxes.picture_media_id IS NOT NULL
    ''');
  }

  Future<void> copyLegacyAnimalTemperatureZonesToBoxes() async {
    await customStatement('''
      UPDATE boxes
      SET temperature_zones = (
        SELECT TRIM(animals.temperature_zones)
        FROM animals
        WHERE animals.box_id = boxes.id
          AND animals.temperature_zones IS NOT NULL
          AND TRIM(animals.temperature_zones) <> ''
        ORDER BY animals.id
        LIMIT 1
      )
      WHERE (temperature_zones IS NULL OR TRIM(temperature_zones) = '')
        AND EXISTS (
          SELECT 1
          FROM animals
          WHERE animals.box_id = boxes.id
            AND animals.temperature_zones IS NOT NULL
            AND TRIM(animals.temperature_zones) <> ''
        )
    ''');
  }
}
