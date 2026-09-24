import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/backup_restore_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/shared_server/shared_portable_backups.dart';

void main() {
  test(
    'shared collection restore preserves personal device preferences',
    () async {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      SharedPreferences.setMockInitialValues({});
      final source = AppDatabase.test(NativeDatabase.memory());
      final target = AppDatabase.test(NativeDatabase.memory());
      final settings = AppSettingsController();
      await settings.load();
      try {
        await settings.setThemeMode(ThemeMode.dark);
        await settings.setAccent(AppAccent.blue);
        final exported = await SharedPortableBackups(source).export();
        final validated = BackupValidationService().validate(exported.bytes);
        expect(validated.settings.scope, 'collectionOnly');
        await BackupRestoreService(
          database: target,
          settingsController: settings,
          safetyBackupWriter: (_) async {},
        ).restore(
          backup: validated,
          currentAppVersion: null,
          createSafetyBackup: false,
        );
        expect(settings.themeMode, ThemeMode.dark);
        expect(settings.accent, AppAccent.blue);
      } finally {
        settings.dispose();
        await source.close();
        await target.close();
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      }
    },
  );
}
