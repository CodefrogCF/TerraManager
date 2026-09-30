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
  final Uint8List? Function(String path)? _readMedia;
  final void Function()? _onDispose;

  ValidatedBackup({
    required this.manifest,
    required this.data,
    required this.settings,
    this.hasLegacyTimestamps = false,
    required Map<String, Uint8List> mediaFiles,
    Set<String>? mediaPaths,
    Uint8List? Function(String path)? readMedia,
    void Function()? onDispose,
  }) : mediaFiles = Map.unmodifiable(mediaFiles),
       mediaPaths = Set.unmodifiable(mediaPaths ?? mediaFiles.keys.toSet()),
       _readMedia = readMedia,
       _onDispose = onDispose;

  Uint8List? readMedia(String path) =>
      _readMedia?.call(path) ?? mediaFiles[path];

  void dispose() => _onDispose?.call();

  int get boxCount => data.boxes.length;

  int get animalCount => data.animals.length;

  int get feedingEventCount => data.feedingEvents.length;

  int get mediaFileCount => mediaPaths.length;
}
