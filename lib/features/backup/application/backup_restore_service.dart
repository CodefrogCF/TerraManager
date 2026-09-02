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

typedef BackupRestoreMediaWriter = Future<String> Function(
  String portablePath,
  Uint8List bytes,
);

typedef BackupRestoreMediaCleanup = Future<void> Function(String localPath);

class BackupRestoreService {
  final AppDatabase database;
  final AppSettingsController settingsController;

  final BackupSafetyBackupWriter safetyBackupWriter;
  final BackupRestoreMediaWriter mediaWriter;
  final BackupRestoreMediaCleanup mediaCleanup;

  final BackupExportService _exportService;

  BackupRestoreService({
    required this.database,
    required this.settingsController,
    required this.safetyBackupWriter,
    required this.mediaWriter,
    required this.mediaCleanup,
    BackupExportService? exportService,
  }) : _exportService = exportService ?? BackupExportService(database);

  Future<BackupRestoreResult> restore({
    required ValidatedBackup backup,
    required String currentAppVersion,
  }) async {
    final previousThemeMode = settingsController.themeMode;

    final previousAccent = settingsController.accent;

    final restoredThemeMode = BackupSettingsCodec.decodeThemeMode(
      backup.settings.themeMode,
    );

    final restoredAccent = BackupSettingsCodec.decodeAccent(
      backup.settings.accent,
    );

    final BackupExportResult safetyBackup;

    try {
      safetyBackup = await _exportService.createBackup(
        appVersion: currentAppVersion,
        themeMode: previousThemeMode,
        accent: previousAccent,
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

    final restoredMediaPaths = <String, String>{};

    final writtenLocalPaths = <String>[];

    try {
      for (final animal in backup.data.animals) {
        final portablePath = animal.pictureMediaPath;

        if (portablePath == null) {
          continue;
        }

        if (restoredMediaPaths.containsKey(portablePath)) {
          continue;
        }

        final bytes = backup.mediaFiles[portablePath];

        if (bytes == null) {
          throw StateError(
            'Validated backup is missing media: '
            '$portablePath',
          );
        }

        final localPath = await mediaWriter(portablePath, bytes);

        if (localPath.trim().isEmpty) {
          throw StateError(
            'Media writer returned an empty path '
            'for $portablePath',
          );
        }

        restoredMediaPaths[portablePath] = localPath;

        writtenLocalPaths.add(localPath);
      }
    } catch (error) {
      await _cleanupMediaBestEffort(writtenLocalPaths);

      throw BackupRestoreException(
        stage: BackupRestoreStage.media,
        message: 'Failed to prepare backup media.',
        cause: error,
      );
    }

    try {
      await settingsController.replaceSettings(
        themeMode: restoredThemeMode,
        accent: restoredAccent,
      );
    } catch (error) {
      await _cleanupMediaBestEffort(writtenLocalPaths);

      throw BackupRestoreException(
        stage: BackupRestoreStage.settings,
        message: 'Failed to restore application settings.',
        cause: error,
      );
    }

    try {
      await _replaceDatabase(
        backup: backup,
        restoredMediaPaths: restoredMediaPaths,
      );
    } catch (error) {
      Object? rollbackError;

      try {
        await settingsController.replaceSettings(
          themeMode: previousThemeMode,
          accent: previousAccent,
        );
      } catch (settingsRollbackError) {
        rollbackError = settingsRollbackError;
      }

      try {
        await _cleanupMedia(writtenLocalPaths);
      } catch (mediaRollbackError) {
        rollbackError ??= mediaRollbackError;
      }

      if (rollbackError != null) {
        throw BackupRestoreException(
          stage: BackupRestoreStage.rollback,
          message:
              'Database restore failed and rollback '
              'could not be completed cleanly.',
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
      mediaFileCount: restoredMediaPaths.length,
    );
  }

  Future<void> _replaceDatabase({
    required ValidatedBackup backup,
    required Map<String, String> restoredMediaPaths,
  }) {
    return database.transaction(() async {
      await database.delete(database.feedingEvents).go();

      await database.delete(database.animals).go();

      await database.delete(database.boxes).go();

      await database.customStatement(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ("
        "'boxes', "
        "'animals', "
        "'feeding_events'"
        ")",
      );

      for (final box in backup.data.boxes) {
        await database
            .into(database.boxes)
            .insert(
              BoxesCompanion(
                id: Value(box.id),
                qrId: Value(box.qrId),
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

        final picturePath = animal.pictureMediaPath == null
            ? null
            : restoredMediaPaths[animal.pictureMediaPath!];

        if (animal.pictureMediaPath != null && picturePath == null) {
          throw StateError(
            'Missing restored media path for '
            '${animal.pictureMediaPath}',
          );
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
                picturePath: Value(picturePath),
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
          'Foreign key violations after restore: '
          '${foreignKeyErrors.map((row) => row.data).toList()}',
        );
      }
    });
  }

  Future<void> _cleanupMedia(List<String> localPaths) async {
    Object? firstError;

    for (final path in localPaths.reversed) {
      try {
        await mediaCleanup(path);
      } catch (error) {
        firstError ??= error;
      }
    }

    if (firstError != null) {
      throw firstError;
    }
  }

  Future<void> _cleanupMediaBestEffort(List<String> localPaths) async {
    try {
      await _cleanupMedia(localPaths);
    } catch (_) {
      // Existing application data has not yet been
      // modified at this stage. Cleanup is best-effort.
    }
  }
}
