import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/backup_export_result.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/backup/application/portable_backup_exporter.dart';
import 'package:terramanager/features/backup/application/validated_backup.dart';
import 'package:terramanager/features/backup/domain/backup_settings.dart';

/// Portable collection archives contain no account database or browser prefs.
class SharedPortableBackups {
  SharedPortableBackups(this.database);

  final AppDatabase database;

  static const collectionSettings = BackupSettings(
    scope: 'collectionOnly',
    themeMode: 'system',
    accent: 'green',
  );

  /// Includes archived records, histories, associations and orphan media.
  /// Account records and SQLite bookkeeping are not collection data.
  Future<bool> isEmpty() async {
    for (final table in database.allTables) {
      final rows = await database
          .customSelect('SELECT 1 FROM "${table.actualTableName}" LIMIT 1')
          .get();
      if (rows.isNotEmpty) return false;
    }
    return true;
  }

  PortableBackupExporter _exporter() => PortableBackupExporter(
    database,
    mediaReader: (_) => throw StateError(
      'A legacy device-local picture cannot be read by the shared server.',
    ),
  );

  Future<BackupExportResult> export() => _exporter().createBackup(
    appVersion: 'TerraManager shared care',
    settings: collectionSettings,
  );

  Future<BackupExportMetadata> exportToFile(String path) async {
    final output = OutputFileStream(path);
    try {
      final metadata = await _exporter().writeBackup(
        appVersion: 'TerraManager shared care',
        settings: collectionSettings,
        output: output,
      );
      await output.close();
      return metadata;
    } catch (_) {
      await output.close();
      rethrow;
    }
  }

  ValidatedBackup validate(Uint8List bytes, {String? legacyTimeZone}) =>
      _validator(legacyTimeZone).validate(bytes);

  ValidatedBackup validateFile(String path, {String? legacyTimeZone}) {
    final input = InputFileStream(path);
    try {
      return _validator(legacyTimeZone).validateStream(input);
    } finally {
      input.closeSync();
    }
  }

  BackupValidationService _validator(String? legacyTimeZone) =>
      BackupValidationService(
        maxExpandedBytes: 512 * 1024 * 1024,
        legacyTimeZone: legacyTimeZone,
        requireLegacyTimeZone: true,
      );

  Future<int> restore(ValidatedBackup backup) =>
      PortableBackupDatabaseRestorer(database).restore(backup);
}
