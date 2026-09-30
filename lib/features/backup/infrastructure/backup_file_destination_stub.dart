import '../application/backup_export_result.dart';

Future<String?> saveGeneratedBackupToFile(BackupArchiveWriter writer) =>
    throw UnsupportedError('Native backup file saving is unavailable.');

Future<String?> saveGeneratedEncryptedBackupToFile(
  BackupArchiveWriter writer, {
  required String password,
}) => throw UnsupportedError('Native backup file saving is unavailable.');
