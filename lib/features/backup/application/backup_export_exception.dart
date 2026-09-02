class BackupExportException implements Exception {
  final String message;
  final Object? cause;

  const BackupExportException(this.message, {this.cause});

  @override
  String toString() {
    return 'BackupExportException: $message';
  }
}
