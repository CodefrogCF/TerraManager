import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';

import 'generated/schema_v11.dart' as v11;

void main() {
  test(
    'v11 upgrade turns existing Animal and Box pictures into galleries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'picture-gallery-v11-current-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = v11.DatabaseAtV11(NativeDatabase(file));
      late final int boxId;
      late final int animalId;
      late final int boxMediaId;
      late final int animalMediaId;

      try {
        boxMediaId = await old
            .into(old.mediaAssets)
            .insert(
              v11.MediaAssetsCompanion.insert(
                fileName: 'box.webp',
                mimeType: 'image/webp',
                data: Uint8List.fromList([1]),
              ),
            );
        animalMediaId = await old
            .into(old.mediaAssets)
            .insert(
              v11.MediaAssetsCompanion.insert(
                fileName: 'animal.webp',
                mimeType: 'image/webp',
                data: Uint8List.fromList([2]),
              ),
            );
        boxId = await old
            .into(old.boxes)
            .insert(
              v11.BoxesCompanion.insert(
                qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
                pictureMediaId: Value(boxMediaId),
              ),
            );
        animalId = await old
            .into(old.animals)
            .insert(
              v11.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Migration Animal',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
                pictureMediaId: Value(animalMediaId),
              ),
            );
      } finally {
        await old.close();
      }

      final migrated = AppDatabase.test(NativeDatabase(file));
      addTearDown(migrated.close);
      final animalPictures = await migrated
          .select(migrated.animalPictureAssociations)
          .get();
      final boxPictures = await migrated
          .select(migrated.boxPictureAssociations)
          .get();

      expect(animalPictures, hasLength(1));
      expect(animalPictures.single.animalId, animalId);
      expect(animalPictures.single.mediaAssetId, animalMediaId);
      expect(animalPictures.single.sortOrder, 0);
      expect(boxPictures, hasLength(1));
      expect(boxPictures.single.boxId, boxId);
      expect(boxPictures.single.mediaAssetId, boxMediaId);
      expect(boxPictures.single.sortOrder, 0);
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
