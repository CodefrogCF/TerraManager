import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/backup_data.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_settings.dart';

typedef BackupArchiveWriter = Future<BackupExportMetadata> Function(
  OutputStream output,
);

class BackupExportMetadata {
  final String fileName;

  final BackupManifest manifest;
  final BackupData data;
  final BackupSettings settings;

  final int mediaFileCount;

  const BackupExportMetadata({
    required this.fileName,
    required this.manifest,
    required this.data,
    required this.settings,
    required this.mediaFileCount,
  });
}

/// Used by in-memory export fallbacks and tests.
class BackupExportResult extends BackupExportMetadata {
  final Uint8List bytes;

  const BackupExportResult({
    required this.bytes,
    required super.fileName,
    required super.manifest,
    required super.data,
    required super.settings,
    required super.mediaFileCount,
  });

  BackupExportResult.fromMetadata({
    required this.bytes,
    required BackupExportMetadata metadata,
  }) : super(
         fileName: metadata.fileName,
         manifest: metadata.manifest,
         data: metadata.data,
         settings: metadata.settings,
         mediaFileCount: metadata.mediaFileCount,
       );
}
