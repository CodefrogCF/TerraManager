import 'package:flutter/material.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/media/legacy_animal_picture_migration_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  try {
    final result = await LegacyAnimalPictureMigrationService(database)
        .migrate();

    if (result.migrated > 0 || result.skipped > 0) {
      debugPrint(
        'Legacy animal picture migration: '
        '${result.migrated} migrated, '
        '${result.skipped} skipped.',
      );
    }
  } catch (error, stackTrace) {
    debugPrint(
      'Legacy animal picture migration failed: '
      '$error',
    );

    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(TerraManagerApp(database: database));
}
