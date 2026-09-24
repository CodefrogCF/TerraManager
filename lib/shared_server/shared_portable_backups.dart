import 'dart:typed_data';

import '../core/database/app_database.dart';
import '../features/backup/application/backup_export_result.dart';
import '../features/backup/application/backup_validation_service.dart';
import '../features/backup/application/portable_backup_database_restorer.dart';
import '../features/backup/application/portable_backup_exporter.dart';
import '../features/backup/application/validated_backup.dart';
import '../features/backup/domain/backup_settings.dart';

/// Portable collection archives contain no account database or browser prefs.
class SharedPortableBackups {
  SharedPortableBackups(this.database);

  final AppDatabase database;

  static const collectionSettings = BackupSettings(
    scope: 'collectionOnly',
    themeMode: 'system',
    accent: 'green',
  );

  Future<BackupExportResult> export() =>
      PortableBackupExporter(
        database,
        mediaReader: (_) => throw StateError(
          'A legacy device-local picture cannot be read by the shared server.',
        ),
      ).createBackup(
        appVersion: 'TerraManager shared care',
        settings: collectionSettings,
      );

  ValidatedBackup validate(Uint8List bytes) =>
      BackupValidationService(maxExpandedBytes: 512 * 1024 * 1024)
          .validate(bytes);

  Future<int> restore(ValidatedBackup backup) =>
      PortableBackupDatabaseRestorer(database).restore(backup);
}
