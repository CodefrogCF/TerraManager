import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/shared_server/backups/application/shared_portable_backups.dart';

void main() {
  test('server export spool is encrypted and validates media lazily', () async {
    final directory = await Directory.systemTemp.createTemp('tm-spool-test-');
    final database = AppDatabase.test(NativeDatabase.memory());
    try {
      final boxId = await BoxRepository(database).createBox(
        'TM:BOX:11111111-1111-4111-8111-111111111111',
        name: 'Test Box',
      );
      await PictureGalleryRepository(database).addBoxPicture(
        boxId: boxId,
        fileName: 'test.png',
        mimeType: 'image/png',
        data: Uint8List.fromList([1, 2, 3]),
        capturedAt: DateTime.utc(2026, 1, 1),
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}export.spool',
      );
      final backups = SharedPortableBackups(database);
      await backups.exportToEncryptedFile(
        file.path,
        password: 'temporary server secret',
      );
      final header = await file.openRead(0, 8).first;
      expect(header, EncryptedBackupContainer.magic);

      final validated = await backups.validateEncryptedFile(
        file.path,
        password: 'temporary server secret',
      );
      try {
        expect(validated.boxCount, 1);
        expect(validated.data.boxes.single.name, 'Test Box');
        expect(validated.mediaFileCount, 1);
        expect(validated.mediaFiles, isEmpty);
        expect(validated.readMedia(validated.mediaPaths.single), [1, 2, 3]);
      } finally {
        validated.dispose();
      }
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
