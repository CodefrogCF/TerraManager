enum BackupValidationErrorCode {
  invalidArchive,
  unsafeArchivePath,
  duplicateArchiveEntry,
  missingRequiredFile,
  invalidJson,
  invalidManifest,
  unsupportedBackupFormat,
  invalidData,
  duplicateRecordId,
  duplicateQrId,
  invalidQrId,
  invalidEnum,
  brokenRelationship,
  invalidLifecycle,
  invalidSettings,
  invalidMediaReference,
  missingMedia,
  emptyMedia,
}

class BackupValidationException implements Exception {
  final BackupValidationErrorCode code;
  final String message;
  final Object? cause;

  const BackupValidationException({
    required this.code,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    return 'BackupValidationException('
        '${code.name}): $message';
  }
}
