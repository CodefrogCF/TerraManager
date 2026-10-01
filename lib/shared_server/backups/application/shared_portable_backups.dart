import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/backup_export_result.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/backup/application/portable_backup_exporter.dart';
import 'package:terramanager/features/backup/application/validated_backup.dart';
import 'package:terramanager/features/backup/domain/backup_settings.dart';
import 'package:terramanager/features/backup/infrastructure/encrypted_backup_file_io.dart';

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

  /// The server's temporary export is encrypted before ZIP bytes reach disk.
  Future<BackupExportMetadata> exportToEncryptedFile(
    String path, {
    required String password,
  }) async {
    final output = OutputFileStream(path);
    EncryptedBackupOutputStream? encrypted;
    try {
      encrypted = await EncryptedBackupContainer.newOutput(
        output,
        password: password,
      );
      final metadata = await _exporter().writeBackup(
        appVersion: 'TerraManager shared care',
        settings: collectionSettings,
        output: encrypted,
      );
      encrypted.finish();
      await output.close();
      return metadata;
    } catch (_) {
      await output.close();
      rethrow;
    } finally {
      encrypted?.dispose();
    }
  }

  ValidatedBackup validate(Uint8List bytes, {String? legacyTimeZone}) =>
      _validator(legacyTimeZone).validate(bytes);

  /// Validation keeps only ZIP metadata and decrypts referenced media on
  /// demand during the database transaction. The caller must dispose it.
  Future<ValidatedBackup> validateEncryptedFile(
    String path, {
    required String password,
    String? legacyTimeZone,
  }) async {
    final encrypted = await EncryptedBackupFile.open(path, password: password);
    try {
      return _validator(legacyTimeZone).validateLazyStream(
        encrypted.openZipStream(),
        onDispose: encrypted.close,
      );
    } catch (_) {
      encrypted.close();
      rethrow;
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
