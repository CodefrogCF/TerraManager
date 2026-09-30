import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_exception.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/infrastructure/backup_file_source_io.dart';
import 'package:terramanager/features/settings/app_accent.dart';

void main() {
  late AppDatabase database;
  late Directory testDirectory;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    testDirectory = await Directory.systemTemp.createTemp('tm-import-test-');
  });

  tearDown(() async {
    await database.close();
    await testDirectory.delete(recursive: true);
  });

  Future<Uint8List> createArchive() async {
    final boxId = await BoxRepository(database).createBox(
      'TM:BOX:11111111-1111-4111-8111-111111111111',
      name: 'Existing Box',
    );
    await PictureGalleryRepository(database).addBoxPicture(
      boxId: boxId,
      fileName: 'box.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([1, 2, 3, 4]),
      capturedAt: DateTime.utc(2026, 9, 1),
    );
    final result = await BackupExportService(database).createBackup(
      appVersion: 'test',
      themeMode: ThemeMode.system,
      accent: AppAccent.green,
    );
    return result.bytes;
  }

  test(
    'validates native ZIP file and closes it after media extraction',
    () async {
      final file = File('${testDirectory.path}/selected.tmbackup');
      await file.writeAsBytes(await createArchive());

      final backup = validateBackupFilePath(
        file.path,
        BackupValidationService(),
      );
      expect(backup.data.boxes.single.name, 'Existing Box');
      expect(backup.mediaFileCount, 1);
      expect(backup.mediaFiles.values.single, [1, 2, 3, 4]);

      // Windows would reject deletion if the validator retained an open handle.
      await file.delete();
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'spooled byte stream validates and removes its temporary file',
    () async {
      final bytes = await createArchive();
      final chunks = <List<int>>[
        bytes.sublist(0, bytes.length ~/ 2),
        bytes.sublist(bytes.length ~/ 2),
      ];
      final spool = Directory('${testDirectory.path}/spool');

      final backup = await validateBackupByteStream(
        Stream<List<int>>.fromIterable(chunks),
        BackupValidationService(),
        createTemporaryDirectory: spool.create,
      );
      expect(backup.mediaFileCount, 1);
      expect(await spool.exists(), isFalse);
    },
  );

  test('invalid stream leaves no temporary archive', () async {
    final spool = Directory('${testDirectory.path}/spool');

    await expectLater(
      validateBackupByteStream(
        Stream<List<int>>.value([1, 2, 3]),
        BackupValidationService(),
        createTemporaryDirectory: spool.create,
      ),
      throwsA(isA<BackupValidationException>()),
    );
    expect(await spool.exists(), isFalse);
  });

  test('failed input stream removes a partially written archive', () async {
    final spool = Directory('${testDirectory.path}/spool');

    await expectLater(
      validateBackupByteStream(
        Stream<List<int>>.multi((controller) {
          controller.add([1, 2, 3]);
          controller.addError(StateError('picker read failed'));
          controller.close();
        }),
        BackupValidationService(),
        createTemporaryDirectory: spool.create,
      ),
      throwsStateError,
    );
    expect(await spool.exists(), isFalse);
  });
}
