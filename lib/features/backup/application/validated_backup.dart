import 'dart:typed_data';

import '../domain/backup_data.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_settings.dart';

class ValidatedBackup {
  final BackupManifest manifest;
  final BackupData data;
  final BackupSettings settings;
  final bool hasLegacyTimestamps;

  final Map<String, Uint8List> mediaFiles;
  final Set<String> mediaPaths;
  final Uint8List? Function(String path)? mediaReader;
  final void Function()? disposer;

  ValidatedBackup({
    required this.manifest,
    required this.data,
    required this.settings,
    this.hasLegacyTimestamps = false,
    required Map<String, Uint8List> mediaFiles,
    Set<String>? mediaPaths,
    this.mediaReader,
    this.disposer,
  }) : mediaFiles = Map.unmodifiable(mediaFiles),
       mediaPaths = Set.unmodifiable(mediaPaths ?? mediaFiles.keys.toSet());

  Uint8List? readMedia(String path) =>
      mediaReader?.call(path) ?? mediaFiles[path];

  void dispose() => disposer?.call();

  int get boxCount => data.boxes.length;

  int get animalCount => data.animals.length;

  int get feedingEventCount => data.feedingEvents.length;

  int get mediaFileCount => mediaPaths.length;
}
