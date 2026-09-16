import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';

void main() {
  late AppDatabase database;
  late PictureGalleryRepository repository;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    repository = PictureGalleryRepository(database);
  });

  tearDown(() => database.close());

  test(
    'keeps stable order and lets a historical Box picture become primary',
    () async {
      final boxId = await BoxRepository(database).createBox('gallery-box');
      final firstTime = DateTime.utc(2025, 1, 2, 10);
      final secondTime = DateTime.utc(2025, 2, 3, 11);
      final firstId = await repository.addBoxPicture(
        boxId: boxId,
        fileName: 'first.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([1]),
        capturedAt: firstTime,
      );
      final secondId = await repository.addBoxPicture(
        boxId: boxId,
        fileName: 'second.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([2]),
        capturedAt: secondTime,
      );

      var pictures = await repository.getBoxPictures(boxId);
      expect(pictures.map((entry) => entry.media.id), [firstId, secondId]);
      expect(pictures.map((entry) => entry.capturedAt.toUtc()), [
        firstTime,
        secondTime,
      ]);
      expect(pictures.last.isPrimary, isTrue);

      expect(
        await repository.setBoxPrimaryPicture(boxId: boxId, mediaId: firstId),
        isTrue,
      );
      pictures = await repository.getBoxPictures(boxId);
      expect(pictures.first.isPrimary, isTrue);
      expect(pictures.last.isPrimary, isFalse);
    },
  );

  test(
    'deleting one Box picture leaves all unrelated media untouched',
    () async {
      final firstBoxId = await BoxRepository(database).createBox('first-box');
      final secondBoxId = await BoxRepository(database).createBox('second-box');
      final deletedId = await repository.addBoxPicture(
        boxId: firstBoxId,
        fileName: 'delete.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([1]),
      );
      final retainedId = await repository.addBoxPicture(
        boxId: firstBoxId,
        fileName: 'retain.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([2]),
      );
      final unrelatedId = await repository.addBoxPicture(
        boxId: secondBoxId,
        fileName: 'unrelated.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([3]),
      );

      expect(
        await repository.deleteBoxPicture(
          boxId: firstBoxId,
          mediaId: deletedId,
        ),
        isTrue,
      );
      expect(await MediaRepository(database).getMediaById(deletedId), isNull);
      expect(
        await MediaRepository(database).getMediaById(retainedId),
        isNotNull,
      );
      expect(
        await MediaRepository(database).getMediaById(unrelatedId),
        isNotNull,
      );
      expect(
        (await repository.getBoxPictures(firstBoxId)).single.media.id,
        retainedId,
      );
      expect(
        (await repository.getBoxPictures(secondBoxId)).single.media.id,
        unrelatedId,
      );
    },
  );

  test(
    'deleting the primary picture promotes the newest remaining picture',
    () async {
      final boxId = await BoxRepository(database).createBox('promotion-box');
      final firstId = await repository.addBoxPicture(
        boxId: boxId,
        fileName: 'first.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([1]),
      );
      final secondId = await repository.addBoxPicture(
        boxId: boxId,
        fileName: 'second.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([2]),
      );

      expect(
        await repository.deleteBoxPicture(boxId: boxId, mediaId: secondId),
        isTrue,
      );
      final box = await BoxRepository(database).getBoxById(boxId);
      expect(box!.pictureMediaId, firstId);
      expect((await repository.getBoxPictures(boxId)).single.isPrimary, isTrue);
    },
  );
}
