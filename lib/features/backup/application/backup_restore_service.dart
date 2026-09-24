import '../../../core/database/app_database.dart';
import '../../settings/app_settings_controller.dart';
import 'backup_export_result.dart';
import 'backup_export_service.dart';
import 'backup_restore_exception.dart';
import 'backup_restore_result.dart';
import 'backup_settings_codec.dart';
import 'validated_backup.dart';
import 'portable_backup_database_restorer.dart';

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
    required String? currentAppVersion,
    bool createSafetyBackup = true,
  }) async {
    final previousThemeMode = settingsController.themeMode;

    final previousAccent = settingsController.accent;

    final previousLanguage = settingsController.language;

    final previousAnimalNameOrder = settingsController.animalNameOrder;

    final previousAnimalSortOrder = settingsController.animalSortOrder;

    final previousAnimalCategoryViewEnabled =
        settingsController.animalCategoryViewEnabled;

    final previousNextFeedingSummaryEnabled =
        settingsController.nextFeedingSummaryEnabled;

    final previousBigPictureModeEnabled =
        settingsController.bigPictureModeEnabled;

    final previousBoxSortOrder = settingsController.boxSortOrder;

    final restoredThemeMode = BackupSettingsCodec.decodeThemeMode(
      backup.settings.themeMode,
    );

    final restoredAccent = BackupSettingsCodec.decodeAccent(
      backup.settings.accent,
    );

    final restoredLanguage = BackupSettingsCodec.decodeLanguage(
      backup.settings.language,
    );

    final restoredAnimalNameOrder = BackupSettingsCodec.decodeAnimalNameOrder(
      backup.settings.animalNameOrder,
    );

    final restoredAnimalSortOrder = BackupSettingsCodec.decodeAnimalSortOrder(
      backup.settings.animalSortOrder,
    );

    final restoredAnimalCategoryViewEnabled =
        backup.settings.animalCategoryViewEnabled;

    final restoredNextFeedingSummaryEnabled =
        backup.settings.nextFeedingSummaryEnabled;

    final restoredBigPictureModeEnabled = backup.settings.bigPictureModeEnabled;

    final restoredBoxSortOrder = BackupSettingsCodec.decodeBoxSortOrder(
      backup.settings.boxSortOrder,
    );

    BackupExportResult? safetyBackup;

    if (createSafetyBackup) {
      late final BackupExportResult createdSafetyBackup;

      try {
        final appVersion = currentAppVersion;

        if (appVersion == null || appVersion.trim().isEmpty) {
          throw StateError(
            'The current application version is required '
            'for a safety backup.',
          );
        }

        createdSafetyBackup = await _exportService.createBackup(
          appVersion: appVersion,
          themeMode: previousThemeMode,
          accent: previousAccent,
          language: previousLanguage,
          animalNameOrder: previousAnimalNameOrder,
          animalSortOrder: previousAnimalSortOrder,
          animalCategoryViewEnabled: previousAnimalCategoryViewEnabled,
          nextFeedingSummaryEnabled: previousNextFeedingSummaryEnabled,
          bigPictureModeEnabled: previousBigPictureModeEnabled,
          boxSortOrder: previousBoxSortOrder,
        );
      } catch (error) {
        throw BackupRestoreException(
          stage: BackupRestoreStage.safetyBackup,
          message: 'Failed to create safety backup.',
          cause: error,
        );
      }

      safetyBackup = createdSafetyBackup;

      try {
        await safetyBackupWriter(createdSafetyBackup);
      } catch (error) {
        throw BackupRestoreException(
          stage: BackupRestoreStage.safetyBackup,
          message: 'Failed to persist safety backup.',
          cause: error,
        );
      }
    }

    // A shared collection backup contains neutral settings for format
    // compatibility, not preferences to apply to another person's device.
    if (backup.settings.scope == 'personal') {
      try {
        await settingsController.replaceSettings(
          themeMode: restoredThemeMode,
          accent: restoredAccent,
          language: restoredLanguage,
          animalNameOrder: restoredAnimalNameOrder,
          animalSortOrder: restoredAnimalSortOrder,
          animalCategoryViewEnabled: restoredAnimalCategoryViewEnabled,
          nextFeedingSummaryEnabled: restoredNextFeedingSummaryEnabled,
          bigPictureModeEnabled: restoredBigPictureModeEnabled,
          boxSortOrder: restoredBoxSortOrder,
        );
      } catch (error) {
        throw BackupRestoreException(
          stage: BackupRestoreStage.settings,
          message: 'Failed to restore application settings.',
          cause: error,
        );
      }
    }

    late final int restoredMediaCount;

    try {
      restoredMediaCount = await PortableBackupDatabaseRestorer(database)
          .restore(backup);
    } catch (error) {
      if (backup.settings.scope == 'personal') {
        try {
          await settingsController.replaceSettings(
            themeMode: previousThemeMode,
            accent: previousAccent,
            language: previousLanguage,
            animalNameOrder: previousAnimalNameOrder,
            animalSortOrder: previousAnimalSortOrder,
            animalCategoryViewEnabled: previousAnimalCategoryViewEnabled,
            nextFeedingSummaryEnabled: previousNextFeedingSummaryEnabled,
            bigPictureModeEnabled: previousBigPictureModeEnabled,
            boxSortOrder: previousBoxSortOrder,
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
}
