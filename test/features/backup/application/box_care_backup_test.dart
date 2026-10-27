import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/features/backup/application/portable_backup_exporter.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/domain/backup_settings.dart';

Uint8List changeData(
  Uint8List bytes,
  void Function(Map<String, dynamic>) change,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final result = Archive();
  for (final file in archive.files) {
    if (file.name == 'data.json') {
      final data =
          jsonDecode(utf8.decode(file.content)) as Map<String, dynamic>;
      change(data);
      result.add(ArchiveFile.string('data.json', jsonEncode(data)));
    } else {
      result.add(file);
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(result));
}

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late int box;
  Future<Uint8List> export(AppDatabase db, {bool server = false}) async =>
      (await PortableBackupExporter(
            db,
            mediaReader: (_) async => throw StateError('No file pictures'),
          ).createBackup(
            appVersion: '1.17.0',
            settings: BackupSettings(
              scope: server ? 'collectionOnly' : 'personal',
              themeMode: 'system',
              accent: 'green',
            ),
          ))
          .bytes;
  setUp(() async {
    source = AppDatabase.test(NativeDatabase.memory());
    target = AppDatabase.test(NativeDatabase.memory());
    box = await BoxRepository(source).createBoxWithGeneratedQrId();
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });
  test('all care types and ordinary galleries survive Standalone/server round trips', () async {
    final gallery = PictureGalleryRepository(source);
    await gallery.addBoxPicture(
      boxId: box,
      fileName: 'care.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([1, 2, 3]),
    );
    for (final type in BoxCareEventType.builtIn) {
      await BoxCareRepository(source).add(
        boxId: box,
        type: type,
        occurredAt: DateTime.utc(2026, 1, type.index + 1),
        notes: type == BoxCareEventType.cleaning ? 'Cleaned' : null,
      );
    }
    final validated = BackupValidationService().validate(await export(source));
    expect(validated.manifest.databaseSchemaVersion, 21);
    expect(validated.mediaFiles, hasLength(1));
    expect(
      BackupValidationService()
          .validatePreview(await export(source))
          .mediaPaths,
      hasLength(1),
    );
    final directory = await Directory.systemTemp.createTemp('tm238-lazy-');
    final file = File('${directory.path}/backup.tmbackup');
    await file.writeAsBytes(await export(source));
    final input = InputFileStream(file.path);
    try {
      final lazy = BackupValidationService().validateLazyStream(input);
      await PortableBackupDatabaseRestorer(target).restore(lazy);
    } finally {
      input.closeSync();
      await directory.delete(recursive: true);
    }
    expect(await target.select(target.mediaAssets).get(), hasLength(1));
    final entries = await BoxCareRepository(target).history(box);
    expect(entries.map((e) => e.type), BoxCareEventType.builtIn.reversed);
    final kept = (await PictureGalleryRepository(
      target,
    ).getBoxGalleryMediaIds(box)).single;
    await PictureGalleryRepository(target)
        .deleteBoxPicture(boxId: box, mediaId: kept);
    final serverBackup = BackupValidationService().validate(
      await export(target, server: true),
    );
    await PortableBackupDatabaseRestorer(source).restore(serverBackup);
    expect(
      await PictureGalleryRepository(source).getBoxGalleryMediaIds(box),
      isEmpty,
    );
    expect(await BoxCareRepository(source).history(box), hasLength(3));
    expect(await source.select(source.mediaAssets).get(), isEmpty);
    expect(
      await source.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });
  test(
    'older archives without careEvents restore with an empty Box care history',
    () async {
      await BoxCareRepository(source).add(
        boxId: box,
        type: BoxCareEventType.cleaning,
        occurredAt: DateTime.utc(2026),
      );
      final bytes = changeData(await export(source), (data) {
        for (final box in data['boxes'] as List) {
          (box as Map).remove('careEvents');
        }
      });
      await PortableBackupDatabaseRestorer(source)
          .restore(BackupValidationService().validate(bytes));
      expect(await BoxCareRepository(source).history(box), isEmpty);
      expect(await source.select(source.boxes).get(), hasLength(1));
    },
  );
  test('retired care picture metadata in old archives is ignored and not re-exported', () async {
    await BoxCareRepository(source).add(
      boxId: box,
      type: BoxCareEventType.cleaning,
      occurredAt: DateTime.utc(2026),
      notes: 'Keep note',
    );
    final legacy = changeData(await export(source), (data) {
      final event =
          ((data['boxes'] as List).single['careEvents'] as List).single as Map;
      event['attachments'] = [
        {
          'mediaPath': 'media/boxes/retired.png',
          'capturedAt': '2026-01-01T00:00:00Z',
        },
      ];
    });
    final validated = BackupValidationService().validate(legacy);
    expect(validated.mediaFiles, isEmpty);
    await PortableBackupDatabaseRestorer(target).restore(validated);
    expect(
      (await BoxCareRepository(target).history(box)).single.notes,
      'Keep note',
    );
    expect(await target.select(target.mediaAssets).get(), isEmpty);
    final again = ZipDecoder().decodeBytes(await export(target));
    final data = jsonDecode(utf8.decode(again.findFile('data.json')!.content));
    expect(
      ((data['boxes'] as List).single['careEvents'] as List).single,
      isNot(contains('attachments')),
    );
  });

  test('invalid care kinds IDs revisions and notes are rejected before replacement', () async {
    await BoxCareRepository(source).add(
      boxId: box,
      type: BoxCareEventType.cleaning,
      occurredAt: DateTime.utc(2026),
    );
    final bytes = await export(source);
    for (final change in <void Function(Map<String, dynamic>)>[
      (e) => e['type'] = 'invented',
      (e) => e['id'] = 0,
      (e) => e['revision'] = 0,
      (e) => e['notes'] = 'x' * 10001,
    ]) {
      final invalid = changeData(
        bytes,
        (data) => change(
          ((data['boxes'] as List).single['careEvents'] as List).single
              as Map<String, dynamic>,
        ),
      );
      expect(
        () => BackupValidationService().validate(invalid),
        throwsA(isA<Exception>()),
      );
    }
    expect(await BoxCareRepository(source).history(box), hasLength(1));
  });
}
