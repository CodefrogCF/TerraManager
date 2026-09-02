import 'backup_export_result.dart';

class BackupRestoreResult {
  final BackupExportResult safetyBackup;

  final int boxCount;
  final int animalCount;
  final int feedingEventCount;
  final int mediaFileCount;

  const BackupRestoreResult({
    required this.safetyBackup,
    required this.boxCount,
    required this.animalCount,
    required this.feedingEventCount,
    required this.mediaFileCount,
  });
}
