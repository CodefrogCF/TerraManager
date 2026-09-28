import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/shared_server/backups/application/shared_portable_backups.dart';
import 'package:terramanager/shared_server/media/application/image_upload_validation.dart';
import 'package:terramanager/shared_server/media/infrastructure/media_storage_policy.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

void main() {
  late AppDatabase database;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });
  tearDown(() => database.close());

  test(
    'cleanup only removes media without any gallery or primary reference',
    () async {
      final media = MediaRepository(database);
      final orphan = await media.createMedia(
        fileName: 'orphan.png',
        mimeType: 'image/png',
        data: Uint8List.fromList([1, 2, 3]),
      );
      final boxId = await BoxRepository(database)
          .createBoxWithGeneratedQrId(name: 'Box');
      final referenced = await PictureGalleryRepository(database).addBoxPicture(
        boxId: boxId,
        fileName: 'gallery.png',
        mimeType: 'image/png',
        data: Uint8List.fromList([4, 5, 6]),
      );
      final policy = MediaStoragePolicy(database);
      expect(await policy.unassociatedMedia(), (count: 1, bytes: 3));
      expect(await policy.cleanUnassociatedMedia(), (count: 1, bytes: 3));
      expect(await media.getMediaById(orphan), isNull);
      expect(await media.getMediaById(referenced), isNotNull);
      expect(await policy.unassociatedMedia(), (count: 0, bytes: 0));
    },
  );

  test(
    'quota blocks new copies but permits reducing an oversized collection',
    () async {
      final media = MediaRepository(database);
      final first = await media.createMedia(
        fileName: 'old.png',
        mimeType: 'image/png',
        data: Uint8List(20),
      );
      final policy = MediaStoragePolicy(database);
      await policy.install(maxBytes: 10);
      expect(await media.getMediaById(first), isNotNull);
      await expectLater(
        media.createMedia(
          fileName: 'new.png',
          mimeType: 'image/png',
          data: Uint8List(1),
        ),
        throwsA(predicate(MediaStoragePolicy.isQuotaError)),
      );
      expect(await media.deleteMedia(first), isTrue);
      final newId = await media.createMedia(
        fileName: 'new.png',
        mimeType: 'image/png',
        data: Uint8List(10),
      );
      expect(await media.getMediaById(newId), isNotNull);
    },
  );

  test('a duplicated gallery cannot bypass the storage limit', () async {
    final boxId = await BoxRepository(database)
        .createBoxWithGeneratedQrId(name: 'Original');
    await PictureGalleryRepository(database).addBoxPicture(
      boxId: boxId,
      fileName: 'gallery.png',
      mimeType: 'image/png',
      data: Uint8List(10),
    );
    await MediaStoragePolicy(database).install(maxBytes: 10);
    await expectLater(
      BoxRepository(database).duplicateBox(sourceBoxId: boxId, name: 'Copy'),
      throwsA(predicate(MediaStoragePolicy.isQuotaError)),
    );
    expect(await database.select(database.boxes).get(), hasLength(1));
    expect(await database.select(database.mediaAssets).get(), hasLength(1));
  });

  test(
    'failed restore rolls back and successful restore preserves image bytes',
    () async {
      final sourceBox = await BoxRepository(database)
          .createBoxWithGeneratedQrId(name: 'Source');
      final jpeg = image.encodeJpg(image.Image(width: 2, height: 1));
      final orientedJpeg = Uint8List.fromList([
        ...jpeg.take(2),
        0xff,
        0xe1,
        0x00,
        0x22,
        0x45,
        0x78,
        0x69,
        0x66,
        0x00,
        0x00,
        0x4d,
        0x4d,
        0x00,
        0x2a,
        0x00,
        0x00,
        0x00,
        0x08,
        0x00,
        0x01,
        0x01,
        0x12,
        0x00,
        0x03,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x06,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        ...jpeg.skip(2),
      ]);
      final upload = decodeImageUpload(
        ApiInput({
          'fileName': 'oriented.jpg',
          'mimeType': 'image/jpeg',
          'dataBase64': base64Encode(orientedJpeg),
        }),
      );
      expect(upload.bytes, orientedJpeg);
      await PictureGalleryRepository(database).addBoxPicture(
        boxId: sourceBox,
        fileName: 'oriented.jpg',
        mimeType: 'image/jpeg',
        data: upload.bytes,
      );
      final archive = await SharedPortableBackups(database).export();

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      final destination = database;
      await destination.customSelect('SELECT 1').get();
      final oldBox = await BoxRepository(destination)
          .createBoxWithGeneratedQrId(name: 'Old collection');
      final policy = MediaStoragePolicy(destination);
      await policy.install(maxBytes: orientedJpeg.length - 1);
      final backup = SharedPortableBackups(destination).validate(archive.bytes);
      await expectLater(
        SharedPortableBackups(destination).restore(backup),
        throwsA(predicate(MediaStoragePolicy.isQuotaError)),
      );
      expect(await BoxRepository(destination).getBoxById(oldBox), isNotNull);
      await policy.install(maxBytes: orientedJpeg.length);
      await SharedPortableBackups(destination).restore(backup);
      final restored = await PictureGalleryRepository(destination)
          .getBoxPictures(sourceBox);
      expect(restored.single.media.data, orientedJpeg);
    },
  );
}
