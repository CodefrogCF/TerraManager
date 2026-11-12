import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/feedings/domain/animal_rest_period.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/shared_server/backups/application/shared_portable_backups.dart';

void main() {
  for (final shared in [false, true]) {
    test(
      'portable backup preserves dates, zone and rest notes; shared=$shared',
      () async {
        final source = AppDatabase.test(NativeDatabase.memory());
        final target = AppDatabase.test(NativeDatabase.memory());
        addTearDown(source.close);
        addTearDown(target.close);
        final period = AnimalRestPeriod(
          startDate: DateTime(2026, 10, 24),
          endDate: DateTime(2026, 10, 25),
          timeZone: 'Europe/Berlin',
        );
        final id = await AnimalRepository(source).createAnimal(
          boxId: await BoxRepository(source).createBoxWithGeneratedQrId(),
          commonName: 'Animal',
          latinName: 'Species',
          tempMin: 20,
          tempMax: 28,
          humidityMin: 40,
          humidityMax: 60,
          restOrDormancyPeriods: 'Winter notes',
          restPeriod: period,
        );
        if (shared) {
          final result = await SharedPortableBackups(source).export();
          final restore = SharedPortableBackups(target);
          await restore.restore(restore.validate(result.bytes));
        } else {
          final result = await BackupExportService(source).createBackup(
            appVersion: 'test',
            themeMode: ThemeMode.system,
            accent: AppAccent.green,
          );
          await PortableBackupDatabaseRestorer(target)
              .restore(BackupValidationService().validate(result.bytes));
        }
        final restored = (await AnimalRepository(target).getAnimalById(id))!;
        expect(restored.restOrDormancyPeriods, 'Winter notes');
        expect(restored.restPeriod, period);
        expect(
          restored.restPeriod!.window.endsAt,
          DateTime.utc(2026, 10, 25, 23),
        );
      },
    );
  }
}
