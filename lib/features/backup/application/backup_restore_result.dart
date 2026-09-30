import 'backup_export_result.dart';

class BackupRestoreResult {
  /// Metadata only; the saved safety archive is not retained in memory.
  final BackupExportMetadata? safetyBackup;

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
