import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_result.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_restore_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_exception.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/domain/backup_enum_codec.dart';
import 'package:terramanager/features/backup/domain/backup_format.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late AppSettingsController settings;
  final archivedAt = DateTime(2026, 9, 13, 12, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    source = AppDatabase.test(NativeDatabase.memory());
    target = AppDatabase.test(NativeDatabase.memory());
    settings = AppSettingsController();
    await settings.load();
  });

  tearDown(() async {
    settings.dispose();
    await source.close();
    await target.close();
  });

  Future<BackupExportResult> export(AppDatabase database) {
    return BackupExportService(database).createBackup(
      appVersion: '1.1.1',
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
      currentAppVersion: '1.1.1',
      createSafetyBackup: false,
    );
  }

  Future<void> seedActiveBoxAndAnimal() async {
    final boxId = await BoxRepository(source)
        .createBoxWithGeneratedQrId(name: 'Active Box');
    await AnimalRepository(source).createAnimal(
      boxId: boxId,
      commonName: 'Animal',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  test('export, validate and restore preserve active and all archived Boxes with media', () async {
    await seedActiveBoxAndAnimal();
    for (final reason in BoxArchiveReason.values) {
      final mediaId = await source
          .into(source.mediaAssets)
          .insert(
            MediaAssetsCompanion.insert(
              fileName: 'box.webp',
              mimeType: 'image/webp',
              data: Uint8List.fromList([1, 2, 3, reason.index]),
            ),
          );
      final id = await BoxRepository(source).createBoxWithGeneratedQrId(
        name: reason.name,
        widthCm: 60,
        heightCm: 50,
        depthCm: 40,
        notes: 'Original notes',
        pictureMediaId: mediaId,
      );
      await (source.update(
        source.boxes,
      )..where((box) => box.id.equals(id))).write(
        BoxesCompanion(
          status: const Value(BoxStatus.archived),
          archiveReason: Value(reason),
          archivedAt: Value(archivedAt),
          archiveNotes: Value(
            reason == BoxArchiveReason.other
                ? null
                : 'Archive notes\nAdditional context',
          ),
        ),
      );
    }
    final original = await export(source);
    final validated = BackupValidationService().validate(original.bytes);
    expect(validated.manifest.backupFormatVersion, 2);
    expect(validated.manifest.databaseSchemaVersion, 8);
    expect(validated.data.boxes.map((box) => box.status), [
      'active',
      'archived',
      'archived',
      'archived',
      'archived',
    ]);
    expect(validated.data.boxes.skip(1).map((box) => box.archiveReason), [
      'sold',
      'replaced',
      'damaged',
      'other',
    ]);
    expect(
      validated.data.boxes.skip(1).every((box) => box.archivedAt == archivedAt),
      isTrue,
    );
    expect(validated.data.boxes.last.archiveNotes, isNull);
    await restore(original.bytes);
    final restored = await export(target);
    expect(restored.data.toJson(), original.data.toJson());
    expect(
      BackupValidationService().validate(restored.bytes).mediaFiles,
      validated.mediaFiles,
    );
    final restoredBoxes = await target.select(target.boxes).get();
    expect(
      restoredBoxes.skip(1).map((box) => box.archiveReason),
      BoxArchiveReason.values,
    );
    expect(
      (await target.select(target.animals).getSingle()).boxId,
      restoredBoxes.first.id,
    );
  });

  for (final version in [1, 2]) {
    test(
      'legacy format $version without lifecycle restores Boxes active',
      () async {
        await seedActiveBoxAndAnimal();
        final original = await export(source);
        final bytes = rewriteArchive(
          original.bytes,
          (data) {
            for (final box in data['boxes'] as List<dynamic>) {
              for (final key in [
                'status',
                'archiveReason',
                'archivedAt',
                'archiveNotes',
              ]) {
                (box as Map<String, dynamic>).remove(key);
              }
              if (version == 1) {
                (box as Map<String, dynamic>).removeWhere(
                  (key, _) =>
                      !['id', 'qrId', 'createdAt', 'updatedAt'].contains(key),
                );
              }
            }
          },
          backupVersion: version,
          schemaVersion: version == 1 ? 2 : 7,
        );
        await restore(bytes);
        final box = await target.select(target.boxes).getSingle();
        expect(box.status, BoxStatus.active);
        expect(box.archiveReason, isNull);
        expect(box.archivedAt, isNull);
        expect(box.archiveNotes, isNull);
        expect(box.qrId, original.data.boxes.single.qrId);
        expect((await target.select(target.animals).getSingle()).boxId, box.id);
      },
    );
  }

  final invalidCases =
      <String, (Map<String, dynamic>, BackupValidationErrorCode)>{
        'unknown status': (
          {'status': 'deleted'},
          BackupValidationErrorCode.invalidEnum,
        ),
        'localized status': (
          {'status': 'archiviert'},
          BackupValidationErrorCode.invalidEnum,
        ),
        'null status': (
          {'status': null},
          BackupValidationErrorCode.invalidData,
        ),
        'numeric status': (
          {'status': 1},
          BackupValidationErrorCode.invalidData,
        ),
        'unknown reason': (
          {
            'status': 'archived',
            'archiveReason': 'traded',
            'archivedAt': archivedAt.toIso8601String(),
          },
          BackupValidationErrorCode.invalidEnum,
        ),
        'localized reason': (
          {
            'status': 'archived',
            'archiveReason': 'Verkauft',
            'archivedAt': archivedAt.toIso8601String(),
          },
          BackupValidationErrorCode.invalidEnum,
        ),
        'missing reason': (
          {'status': 'archived', 'archivedAt': archivedAt.toIso8601String()},
          BackupValidationErrorCode.invalidLifecycle,
        ),
        'missing timestamp': (
          {'status': 'archived', 'archiveReason': 'sold'},
          BackupValidationErrorCode.invalidLifecycle,
        ),
        'active with reason': (
          {'archiveReason': 'sold'},
          BackupValidationErrorCode.invalidLifecycle,
        ),
        'active with timestamp': (
          {'archivedAt': archivedAt.toIso8601String()},
          BackupValidationErrorCode.invalidLifecycle,
        ),
        'active with note': (
          {'archiveNotes': 'Context'},
          BackupValidationErrorCode.invalidLifecycle,
        ),
        'invalid timestamp': (
          {
            'status': 'archived',
            'archiveReason': 'sold',
            'archivedAt': 'yesterday',
          },
          BackupValidationErrorCode.invalidData,
        ),
        'numeric note': (
          {
            'status': 'archived',
            'archiveReason': 'sold',
            'archivedAt': archivedAt.toIso8601String(),
            'archiveNotes': 42,
          },
          BackupValidationErrorCode.invalidData,
        ),
      };
  for (final entry in invalidCases.entries) {
    test('rejects Box lifecycle: ${entry.key}', () async {
      await seedActiveBoxAndAnimal();
      final original = await export(source);
      final bytes = rewriteArchive(original.bytes, (data) {
        ((data['boxes'] as List<dynamic>).single as Map<String, dynamic>)
            .addAll(entry.value.$1);
      });
      expect(
        () => BackupValidationService().validate(bytes),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.code,
            'code',
            entry.value.$2,
          ),
        ),
      );
    });
  }

  test(
    'rejects active Animals assigned to archived Boxes before restore',
    () async {
      await seedActiveBoxAndAnimal();
      final original = await export(source);
      final bytes = rewriteArchive(original.bytes, (data) {
        ((data['boxes'] as List<dynamic>).single as Map<String, dynamic>)
            .addAll({
              'status': 'archived',
              'archiveReason': 'other',
              'archivedAt': archivedAt.toIso8601String(),
            });
      });
      expect(
        () => BackupValidationService().validate(bytes),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.code,
            'code',
            BackupValidationErrorCode.invalidLifecycle,
          ),
        ),
      );
    },
  );

  test('Box enum codecs use stable portable values', () {
    for (final value in BoxStatus.values) {
      expect(
        BackupEnumCodec.decodeBoxStatus(BackupEnumCodec.encodeBoxStatus(value)),
        value,
      );
    }
    for (final value in BoxArchiveReason.values) {
      expect(
        BackupEnumCodec.decodeBoxArchiveReason(
          BackupEnumCodec.encodeBoxArchiveReason(value),
        ),
        value,
      );
    }
  });
}

Uint8List rewriteArchive(
  Uint8List bytes,
  void Function(Map<String, dynamic>) editData, {
  int? backupVersion,
  int? schemaVersion,
}) {
  final original = ZipDecoder().decodeBytes(bytes);
  final archive = Archive();
  for (final file in original.files) {
    if (file.name == BackupFormat.dataFileName ||
        file.name == BackupFormat.manifestFileName) {
      final json =
          jsonDecode(utf8.decode(file.readBytes()!)) as Map<String, dynamic>;
      if (file.name == BackupFormat.dataFileName) {
        editData(json);
      } else {
        if (backupVersion != null) {
          json['backupFormatVersion'] = backupVersion;
        }
        if (schemaVersion != null) {
          json['databaseSchemaVersion'] = schemaVersion;
        }
      }
      archive.add(ArchiveFile.string(file.name, jsonEncode(json)));
    } else {
      archive.add(ArchiveFile.bytes(file.name, file.readBytes()!));
    }
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
