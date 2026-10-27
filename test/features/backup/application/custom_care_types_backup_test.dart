import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/care_event_type_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/portable_backup_exporter.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/backup/domain/backup_settings.dart';

Uint8List rewrite(Uint8List bytes, void Function(Map<String, dynamic>) change) {
  final archive = Archive();
  for (final file in ZipDecoder().decodeBytes(bytes).files) {
    if (file.name == 'data.json') {
      final data =
          jsonDecode(utf8.decode(file.content)) as Map<String, dynamic>;
      change(data);
      archive.add(ArchiveFile.string(file.name, jsonEncode(data)));
    } else {
      archive.add(file);
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  const used = '12345678-1234-4123-8123-123456789abc';
  const unused = '22345678-1234-4123-8123-123456789abc';
  late AppDatabase source;
  late AppDatabase target;
  Future<Uint8List> export({String scope = 'personal'}) async =>
      (await PortableBackupExporter(
            source,
            mediaReader: (_) async => throw StateError('No media'),
          ).createBackup(
            appVersion: '1.17.0',
            settings: BackupSettings(
              scope: scope,
              themeMode: 'system',
              accent: 'green',
            ),
          ))
          .bytes;
  setUp(() {
    source = AppDatabase.test(NativeDatabase.memory());
    target = AppDatabase.test(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });
  for (final scope in ['personal', 'collectionOnly']) {
    test(
      '$scope preserves stable IDs, archived and unused definitions, ordering and custom history',
      () async {
        final types = CareEventTypeRepository(source);
        final a = await types.create(used, 'Lüftung prüfen');
        final b = await types.create(unused, 'Lamp check');
        final box = await BoxRepository(source).createBoxWithGeneratedQrId();
        await BoxCareRepository(source).add(
          boxId: box,
          type: BoxCareEventType.custom,
          customTypeId: used,
          occurredAt: DateTime.utc(2026),
          notes: 'Historical note',
          requestId: 'backup-id',
        );
        await types.reorder([
          (id: b.id, revision: b.revision),
          (id: a.id, revision: a.revision),
        ]);
        final current = (await types.byId(used))!;
        await types.update(
          id: used,
          expectedRevision: current.revision,
          label: 'Lüftung kontrollieren',
          archived: true,
        );
        final before = (await types.all()).map((t) => t.toJson()).toList();
        final bytes = await export(scope: scope);
        final validated = BackupValidationService().validate(bytes);
        expect(
          BackupValidationService()
              .validatePreview(bytes)
              .manifest
              .databaseSchemaVersion,
          21,
        );
        await PortableBackupDatabaseRestorer(target).restore(validated);
        expect(
          (await CareEventTypeRepository(target).all()).map((t) => t.toJson()),
          before,
        );
        final event = (await BoxCareRepository(target).history(box)).single;
        expect(event.customTypeId, used);
        expect(event.requestId, 'backup-id');
        expect(event.notes, 'Historical note');
        expect(
          await target.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        // Replacement must also clear definitions that are absent from the backup.
        await PortableBackupDatabaseRestorer(source).restore(validated);
        expect((await types.all()).map((t) => t.toJson()), before);
      },
    );
  }
  test('legacy backups without definitions retain standard history', () async {
    final box = await BoxRepository(source).createBoxWithGeneratedQrId();
    await BoxCareRepository(source).add(
      boxId: box,
      type: BoxCareEventType.cleaning,
      occurredAt: DateTime.utc(2026),
    );
    await CareEventTypeRepository(target).create(used, 'Will be replaced');
    final bytes = rewrite(await export(), (data) {
      data.remove('careEventTypes');
    });
    await PortableBackupDatabaseRestorer(target)
        .restore(BackupValidationService().validate(bytes));
    expect(await CareEventTypeRepository(target).all(), isEmpty);
    expect(
      (await BoxCareRepository(target).history(box)).single.type,
      BoxCareEventType.cleaning,
    );
  });
  test('invalid definitions and dangling or mixed custom references are rejected before restore', () async {
    await CareEventTypeRepository(source).create(used, 'Ventilation');
    final box = await BoxRepository(source).createBoxWithGeneratedQrId();
    await BoxCareRepository(source).add(
      boxId: box,
      type: BoxCareEventType.custom,
      customTypeId: used,
      occurredAt: DateTime.utc(2026),
    );
    final bytes = await export();
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (d) {
        (d['careEventTypes'] as List).add((d['careEventTypes'] as List).first);
      },
      (d) {
        (d['careEventTypes'] as List).first['label'] = 'Cleaning';
      },
      (d) {
        (d['careEventTypes'] as List).first['label'] = 'bad\nlabel';
      },
      (d) {
        (d['careEventTypes'] as List).first['id'] = 'invalid';
      },
      (d) {
        (d['careEventTypes'] as List).first['revision'] = 0;
      },
      (d) {
        (d['careEventTypes'] as List).first['sortOrder'] = -1;
      },
      (d) {
        (d['boxes'] as List).first['careEvents'][0]['customTypeId'] = unused;
      },
      (d) {
        (d['boxes'] as List).first['careEvents'][0]['type'] = 'cleaning';
      },
    ]) {
      expect(
        () => BackupValidationService().validate(rewrite(bytes, mutate)),
        throwsA(anything),
      );
    }
    expect(await CareEventTypeRepository(target).all(), isEmpty);
  });
}
