import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_restore_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

void main() {
  test(
    'backup preserves Animal and Box gallery order and primary pictures',
    () async {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      SharedPreferences.setMockInitialValues({});
      final source = AppDatabase.test(NativeDatabase.memory());
      final target = AppDatabase.test(NativeDatabase.memory());
      final settings = AppSettingsController();
      await settings.load();
      addTearDown(() async {
        settings.dispose();
        await source.close();
        await target.close();
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      });

      final boxId = await BoxRepository(source)
          .createBox('TM:BOX:11111111-1111-4111-8111-111111111111');
      final animalId = await AnimalRepository(source).createAnimal(
        boxId: boxId,
        commonName: 'Gallery Animal',
        latinName: 'Test species',
        tempMin: 20,
        tempMax: 30,
        humidityMin: 40,
        humidityMax: 60,
      );
      final gallery = PictureGalleryRepository(source);
      final boxFirst = await gallery.addBoxPicture(
        boxId: boxId,
        fileName: 'box-first.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([1]),
        capturedAt: DateTime.utc(2025, 1, 1),
      );
      await gallery.addBoxPicture(
        boxId: boxId,
        fileName: 'box-second.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([2]),
        capturedAt: DateTime.utc(2025, 2, 1),
      );
      await gallery.setBoxPrimaryPicture(boxId: boxId, mediaId: boxFirst);
      final animalFirst = await gallery.addAnimalPicture(
        animalId: animalId,
        fileName: 'animal-first.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([3]),
        capturedAt: DateTime.utc(2025, 3, 1),
      );
      await gallery.addAnimalPicture(
        animalId: animalId,
        fileName: 'animal-second.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([4]),
        capturedAt: DateTime.utc(2025, 4, 1),
      );
      await gallery.setAnimalPrimaryPicture(
        animalId: animalId,
        mediaId: animalFirst,
      );

      final exported = await BackupExportService(source).createBackup(
        appVersion: 'development',
        themeMode: ThemeMode.system,
        accent: AppAccent.green,
      );
      final validated = BackupValidationService().validate(exported.bytes);
      expect(validated.data.boxes.single.pictures, hasLength(2));
      expect(validated.data.animals.single.pictures, hasLength(2));
      expect(
        validated.data.boxes.single.pictureMediaPath,
        validated.data.boxes.single.pictures.first.mediaPath,
      );
      expect(
        validated.data.animals.single.pictureMediaPath,
        validated.data.animals.single.pictures.first.mediaPath,
      );

      await BackupRestoreService(
        database: target,
        settingsController: settings,
        safetyBackupWriter: (_) async {},
      ).restore(
        backup: validated,
        currentAppVersion: null,
        createSafetyBackup: false,
      );

      final restoredGallery = PictureGalleryRepository(target);
      final boxPictures = await restoredGallery.getBoxPictures(boxId);
      final animalPictures = await restoredGallery.getAnimalPictures(animalId);
      expect(boxPictures.map((entry) => entry.media.data.single), [1, 2]);
      expect(boxPictures.map((entry) => entry.isPrimary), [true, false]);
      expect(animalPictures.map((entry) => entry.media.data.single), [3, 4]);
      expect(animalPictures.map((entry) => entry.isPrimary), [true, false]);
    },
  );
}
