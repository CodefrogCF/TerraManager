import 'dart:typed_data';

import '../domain/backup_data.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_settings.dart';

class ValidatedBackup {
  final BackupManifest manifest;
  final BackupData data;
  final BackupSettings settings;

  final Map<String, Uint8List> mediaFiles;

  ValidatedBackup({
    required this.manifest,
    required this.data,
    required this.settings,
    required Map<String, Uint8List> mediaFiles,
  }) : mediaFiles = Map.unmodifiable(mediaFiles);

  int get boxCount => data.boxes.length;

  int get animalCount => data.animals.length;

  int get feedingEventCount => data.feedingEvents.length;

  int get mediaFileCount => mediaFiles.length;
}
