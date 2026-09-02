import 'dart:typed_data';

import '../domain/backup_data.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_settings.dart';

class BackupExportResult {
  final Uint8List bytes;
  final String fileName;

  final BackupManifest manifest;
  final BackupData data;
  final BackupSettings settings;

  final int mediaFileCount;

  const BackupExportResult({
    required this.bytes,
    required this.fileName,
    required this.manifest,
    required this.data,
    required this.settings,
    required this.mediaFileCount,
  });
}
