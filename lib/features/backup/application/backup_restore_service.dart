import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../settings/app_settings_controller.dart';
import '../domain/backup_enum_codec.dart';
import 'backup_export_result.dart';
import 'backup_export_service.dart';
import 'backup_restore_exception.dart';
import 'backup_restore_result.dart';
import 'backup_settings_codec.dart';
import 'validated_backup.dart';

typedef BackupSafetyBackupWriter = Future<void> Function(
  BackupExportResult backup,
);

class BackupRestoreService {
  final AppDatabase database;

  final AppSettingsController settingsController;

  final BackupSafetyBackupWriter safetyBackupWriter;

  final BackupExportService _exportService;

  BackupRestoreService({
    required this.database,
    required this.settingsController,
    required this.safetyBackupWriter,
    BackupExportService? exportService,
  }) : _exportService = exportService ?? BackupExportService(database);

  Future<BackupRestoreResult> restore({
    required ValidatedBackup backup,
    required String currentAppVersion,
  }) async {
    final previousThemeMode = settingsController.themeMode;

    final previousAccent = settingsController.accent;

    final previousLanguage = settingsController.language;

    final restoredThemeMode = BackupSettingsCodec.decodeThemeMode(
      backup.settings.themeMode,
    );

    final restoredAccent = BackupSettingsCodec.decodeAccent(
      backup.settings.accent,
    );

    final restoredLanguage = BackupSettingsCodec.decodeLanguage(
      backup.settings.language,
    );

    final BackupExportResult safetyBackup;

    try {
      safetyBackup = await _exportService.createBackup(
        appVersion: currentAppVersion,
        themeMode: previousThemeMode,
        accent: previousAccent,
        language: previousLanguage,
      );
    } catch (error) {
      throw BackupRestoreException(
        stage: BackupRestoreStage.safetyBackup,
        message: 'Failed to create safety backup.',
        cause: error,
      );
    }

    try {
      await safetyBackupWriter(safetyBackup);
    } catch (error) {
      throw BackupRestoreException(
        stage: BackupRestoreStage.safetyBackup,
        message: 'Failed to persist safety backup.',
        cause: error,
      );
    }

    try {
      await settingsController.replaceSettings(
        themeMode: restoredThemeMode,
        accent: restoredAccent,
        language: restoredLanguage,
      );
    } catch (error) {
      throw BackupRestoreException(
        stage: BackupRestoreStage.settings,
        message: 'Failed to restore application settings.',
        cause: error,
      );
    }

    late final int restoredMediaCount;

    try {
      restoredMediaCount = await _replaceDatabase(backup: backup);
    } catch (error) {
      try {
        await settingsController.replaceSettings(
          themeMode: previousThemeMode,
          accent: previousAccent,
          language: previousLanguage,
        );
      } catch (rollbackError) {
        throw BackupRestoreException(
          stage: BackupRestoreStage.rollback,
          message:
              'Database restore failed and '
              'settings rollback could not '
              'be completed cleanly.',
          cause: rollbackError,
        );
      }

      throw BackupRestoreException(
        stage: BackupRestoreStage.database,
        message: 'Failed to replace application data.',
        cause: error,
      );
    }

    return BackupRestoreResult(
      safetyBackup: safetyBackup,
      boxCount: backup.boxCount,
      animalCount: backup.animalCount,
      feedingEventCount: backup.feedingEventCount,
      mediaFileCount: restoredMediaCount,
    );
  }

  Future<int> _replaceDatabase({required ValidatedBackup backup}) {
    return database.transaction(() async {
      await database.delete(database.feedingEvents).go();

      await database.delete(database.animals).go();

      await database.delete(database.boxes).go();

      await database.delete(database.mediaAssets).go();

      await database.customStatement(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ("
        "'boxes', "
        "'animals', "
        "'feeding_events', "
        "'media_assets'"
        ")",
      );

      var restoredMediaCount = 0;

      for (final box in backup.data.boxes) {
        int? pictureMediaId;

        final portablePath = box.pictureMediaPath;

        if (portablePath != null) {
          final bytes = backup.mediaFiles[portablePath];

          if (bytes == null) {
            throw StateError(
              'Validated backup is missing media: '
              '$portablePath',
            );
          }

          if (bytes.isEmpty) {
            throw StateError(
              'Validated backup contains empty media: '
              '$portablePath',
            );
          }

          final fileName = _fileNameFromPortablePath(portablePath);

          pictureMediaId = await database
              .into(database.mediaAssets)
              .insert(
                MediaAssetsCompanion.insert(
                  fileName: fileName,
                  mimeType: _mimeTypeFromFileName(fileName),
                  data: bytes,
                  createdAt: Value(box.createdAt),
                  updatedAt: Value(box.updatedAt),
                ),
              );

          restoredMediaCount++;
        }

        await database
            .into(database.boxes)
            .insert(
              BoxesCompanion(
                id: Value(box.id),
                qrId: Value(box.qrId),
                widthCm: Value(box.widthCm),
                heightCm: Value(box.heightCm),
                depthCm: Value(box.depthCm),
                pictureMediaId: Value(pictureMediaId),
                createdAt: Value(box.createdAt),
                updatedAt: Value(box.updatedAt),
              ),
            );
      }

      for (final animal in backup.data.animals) {
        final status = BackupEnumCodec.decodeAnimalStatus(animal.status);

        final sex = animal.sex == null
            ? null
            : BackupEnumCodec.decodeSex(animal.sex!);

        final birthDateAccuracy = animal.birthDateAccuracy == null
            ? null
            : BackupEnumCodec.decodeBirthDateAccuracy(
                animal.birthDateAccuracy!,
              );

        final archiveReason = animal.archiveReason == null
            ? null
            : BackupEnumCodec.decodeArchiveReason(animal.archiveReason!);

        int? pictureMediaId;

        final portablePath = animal.pictureMediaPath;

        if (portablePath != null) {
          final bytes = backup.mediaFiles[portablePath];

          if (bytes == null) {
            throw StateError(
              'Validated backup is '
              'missing media: '
              '$portablePath',
            );
          }

          if (bytes.isEmpty) {
            throw StateError(
              'Validated backup contains '
              'empty media: '
              '$portablePath',
            );
          }

          final fileName = _fileNameFromPortablePath(portablePath);

          pictureMediaId = await database
              .into(database.mediaAssets)
              .insert(
                MediaAssetsCompanion.insert(
                  fileName: fileName,
                  mimeType: _mimeTypeFromFileName(fileName),
                  data: bytes,
                  createdAt: Value(animal.createdAt),
                  updatedAt: Value(animal.updatedAt),
                ),
              );

          restoredMediaCount++;
        }

        await database
            .into(database.animals)
            .insert(
              AnimalsCompanion(
                id: Value(animal.id),
                boxId: Value(animal.boxId),
                status: Value(status),
                commonName: Value(animal.commonName),
                latinName: Value(animal.latinName),
                sex: Value(sex),
                birthDate: Value(animal.birthDate),
                birthDateAccuracy: Value(birthDateAccuracy),
                tempMin: Value(animal.tempMin),
                tempMax: Value(animal.tempMax),
                humidityMin: Value(animal.humidityMin),
                humidityMax: Value(animal.humidityMax),
                picturePath: const Value(null),
                pictureMediaId: Value(pictureMediaId),
                notes: Value(animal.notes),
                archiveReason: Value(archiveReason),
                archivedAt: Value(animal.archivedAt),
                archiveNotes: Value(animal.archiveNotes),
                createdAt: Value(animal.createdAt),
                updatedAt: Value(animal.updatedAt),
              ),
            );
      }

      for (final feeding in backup.data.feedingEvents) {
        await database
            .into(database.feedingEvents)
            .insert(
              FeedingEventsCompanion(
                id: Value(feeding.id),
                animalId: Value(feeding.animalId),
                fedAt: Value(feeding.fedAt),
                notes: Value(feeding.notes),
              ),
            );
      }

      final foreignKeyErrors = await database
          .customSelect('PRAGMA foreign_key_check')
          .get();

      if (foreignKeyErrors.isNotEmpty) {
        throw StateError(
          'Foreign key violations '
          'after restore: '
          '${foreignKeyErrors.map((row) => row.data).toList()}',
        );
      }

      return restoredMediaCount;
    });
  }

  static String _fileNameFromPortablePath(String portablePath) {
    final normalized = portablePath.replaceAll('\\', '/');

    final fileName = normalized.split('/').last.trim();

    if (fileName.isEmpty) {
      throw StateError(
        'Invalid media path: '
        '$portablePath',
      );
    }

    return fileName;
  }

  static String _mimeTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    if (lower.endsWith('.bmp')) {
      return 'image/bmp';
    }

    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }

    if (lower.endsWith('.heif')) {
      return 'image/heif';
    }

    return 'application/octet-stream';
  }
}
