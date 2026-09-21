import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_result.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_restore_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/domain/backup_format.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late AppSettingsController settings;

  setUp(() async {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    SharedPreferences.setMockInitialValues({});

    source = AppDatabase.test(NativeDatabase.memory());

    target = AppDatabase.test(NativeDatabase.memory());

    settings = AppSettingsController();
    await settings.load();
  });

  tearDown(() async {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;

    settings.dispose();

    await source.close();
    await target.close();
  });

  Future<BackupExportResult> export(AppDatabase database) {
    return BackupExportService(database).createBackup(
      appVersion: '1.9.2',
      themeMode: ThemeMode.system,
      accent: AppAccent.green,
    );
  }

  Future<void> restore(Uint8List bytes) async {
    await BackupRestoreService(
      database: target,
      settingsController: settings,
      safetyBackupWriter: (_) async {},
    ).restore(
      backup: BackupValidationService().validate(bytes),
      currentAppVersion: '1.9.2',
      createSafetyBackup: false,
    );
  }

  Future<int> createAnimal({String commonName = 'Test Snake'}) async {
    final boxId = await BoxRepository(source)
        .createBoxWithGeneratedQrId(name: 'Test Box');

    return AnimalRepository(source).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  test('export includes complete shedding history', () async {
    final animalId = await createAnimal();

    final olderShedAt = DateTime(2026, 7, 10, 14, 30);

    final newerShedAt = DateTime(2026, 9, 15, 18, 45);

    final olderCreatedAt = DateTime(2026, 7, 10, 15);

    final newerCreatedAt = DateTime(2026, 9, 15, 19);

    await SheddingRepository(source).add(
      animalId: animalId,
      shedAt: olderShedAt,
      notes: null,
      createdAt: olderCreatedAt,
      updatedAt: olderCreatedAt,
    );

    await SheddingRepository(source).add(
      animalId: animalId,
      shedAt: newerShedAt,
      notes: 'Complete shed',
      createdAt: newerCreatedAt,
      updatedAt: newerCreatedAt,
    );

    final backup = await export(source);

    expect(backup.data.animals, hasLength(1));

    final backupAnimal = backup.data.animals.single;

    expect(backupAnimal.sheddingHistory, hasLength(2));

    expect(backupAnimal.sheddingHistory[0].shedAt, newerShedAt);

    expect(backupAnimal.sheddingHistory[0].notes, 'Complete shed');

    expect(backupAnimal.sheddingHistory[0].createdAt, newerCreatedAt);

    expect(backupAnimal.sheddingHistory[0].updatedAt, newerCreatedAt);

    expect(backupAnimal.sheddingHistory[1].shedAt, olderShedAt);

    expect(backupAnimal.sheddingHistory[1].notes, isNull);

    final validated = BackupValidationService().validate(backup.bytes);

    expect(validated.data.animals.single.sheddingHistory, hasLength(2));
  });

  test('restore preserves shedding history', () async {
    final animalId = await createAnimal();

    final firstShedAt = DateTime(2026, 8, 1, 12);

    final secondShedAt = DateTime(2026, 9, 1, 13);

    final firstCreatedAt = DateTime(2026, 8, 1, 12, 5);

    final secondCreatedAt = DateTime(2026, 9, 1, 13, 5);

    await SheddingRepository(source).add(
      animalId: animalId,
      shedAt: firstShedAt,
      notes: 'First shed',
      createdAt: firstCreatedAt,
      updatedAt: firstCreatedAt,
    );

    await SheddingRepository(source).add(
      animalId: animalId,
      shedAt: secondShedAt,
      notes: 'Second shed',
      createdAt: secondCreatedAt,
      updatedAt: secondCreatedAt,
    );

    final original = await export(source);

    await restore(original.bytes);

    final restoredAnimal = await target.select(target.animals).getSingle();

    final restored = await SheddingRepository(target)
        .getHistory(restoredAnimal.id);

    expect(restored, hasLength(2));

    expect(restored[0].shedAt, secondShedAt);

    expect(restored[0].notes, 'Second shed');

    expect(restored[0].createdAt, secondCreatedAt);

    expect(restored[0].updatedAt, secondCreatedAt);

    expect(restored[1].shedAt, firstShedAt);

    expect(restored[1].notes, 'First shed');

    expect(restoredAnimal.sheddingNotes, isNull);
  });

  test(
    'archived Animals retain shedding history through backup restore',
    () async {
      final animalId = await createAnimal(commonName: 'Archived Snake');

      final shedAt = DateTime(2026, 9, 5, 17);

      await SheddingRepository(source)
          .add(animalId: animalId, shedAt: shedAt, notes: 'Before archive');

      await AnimalRepository(source).archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.other,
        archivedAt: DateTime(2026, 9, 10),
        archiveNotes: 'Archived for test',
      );

      final original = await export(source);

      await restore(original.bytes);

      final restoredAnimal = await target.select(target.animals).getSingle();

      expect(restoredAnimal.status.name, 'archived');

      final history = await SheddingRepository(target)
          .getHistory(restoredAnimal.id);

      expect(history, hasLength(1));

      expect(history.single.shedAt, shedAt);

      expect(history.single.notes, 'Before archive');
    },
  );

  test(
    'legacy backup without sheddingHistory migrates sheddingNotes',
    () async {
      final animalId = await createAnimal();

      final legacyUpdatedAt = DateTime(2026, 8, 20, 16, 30);

      await (source.update(
        source.animals,
      )..where((animal) => animal.id.equals(animalId))).write(
        AnimalsCompanion(
          sheddingNotes: const drift.Value('  Legacy shedding note  '),
          updatedAt: drift.Value(legacyUpdatedAt),
        ),
      );

      final original = await export(source);

      final legacyBytes = rewriteArchive(original.bytes, (data) {
        final animal =
            (data['animals'] as List<dynamic>).single as Map<String, dynamic>;

        animal.remove('sheddingHistory');

        animal['sheddingNotes'] = '  Legacy shedding note  ';
      });

      await restore(legacyBytes);

      final restoredAnimal = await target.select(target.animals).getSingle();

      final history = await SheddingRepository(target)
          .getHistory(restoredAnimal.id);

      expect(history, hasLength(1));

      expect(history.single.notes, 'Legacy shedding note');

      expect(history.single.shedAt, legacyUpdatedAt);

      expect(history.single.createdAt, legacyUpdatedAt);

      expect(history.single.updatedAt, legacyUpdatedAt);

      expect(restoredAnimal.sheddingNotes, isNull);
    },
  );

  test(
    'legacy backup without shedding history or notes restores no events',
    () async {
      await createAnimal();

      final original = await export(source);

      final legacyBytes = rewriteArchive(original.bytes, (data) {
        final animal =
            (data['animals'] as List<dynamic>).single as Map<String, dynamic>;

        animal.remove('sheddingHistory');

        animal.remove('sheddingNotes');
      });

      await restore(legacyBytes);

      final restoredAnimal = await target.select(target.animals).getSingle();

      expect(
        await SheddingRepository(target).getHistory(restoredAnimal.id),
        isEmpty,
      );

      expect(restoredAnimal.sheddingNotes, isNull);
    },
  );
}

Uint8List rewriteArchive(
  Uint8List bytes,
  void Function(Map<String, dynamic> data) editData,
) {
  final original = ZipDecoder().decodeBytes(bytes);

  final archive = Archive();

  for (final file in original.files) {
    if (file.name == BackupFormat.dataFileName) {
      final json =
          jsonDecode(utf8.decode(file.readBytes()!)) as Map<String, dynamic>;

      editData(json);

      archive.add(ArchiveFile.string(file.name, jsonEncode(json)));
    } else {
      archive.add(ArchiveFile.bytes(file.name, file.readBytes()!));
    }
  }

  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
