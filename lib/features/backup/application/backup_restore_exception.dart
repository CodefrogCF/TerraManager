enum BackupRestoreStage { safetyBackup, media, settings, database, rollback }

class BackupRestoreException implements Exception {
  final BackupRestoreStage stage;
  final String message;
  final Object? cause;

  const BackupRestoreException({
    required this.stage,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    return 'BackupRestoreException('
        '${stage.name}): $message';
  }
}
