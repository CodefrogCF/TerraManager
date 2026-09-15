import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/settings/app_accent.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('exports duplicated records and their independent pictures', () async {
    final media = MediaRepository(database);
    final boxes = BoxRepository(database);
    final animals = AnimalRepository(database);
    final boxPictureId = await media.createMedia(
      fileName: 'box.webp',
      mimeType: 'image/webp',
      data: Uint8List.fromList([1, 2, 3]),
    );
    final sourceBoxId = await boxes.createBox(
      'source-box',
      name: 'Source Box',
      pictureMediaId: boxPictureId,
    );
    final duplicatedBoxId = await boxes.duplicateBox(
      sourceBoxId: sourceBoxId,
      name: 'Duplicated Box',
    );
    final animalPictureId = await media.createMedia(
      fileName: 'animal.webp',
      mimeType: 'image/webp',
      data: Uint8List.fromList([4, 5, 6]),
    );
    final sourceAnimalId = await animals.createAnimal(
      boxId: sourceBoxId,
      commonName: 'Source Animal',
      latinName: 'Test species',
      tempMin: 22,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 70,
      originHabitat: 'Forest',
      pictureMediaId: animalPictureId,
    );
    await FeedingRepository(database)
        .addFeeding(sourceAnimalId, DateTime(2026, 9, 14));
    final duplicatedAnimalId = await animals.duplicateAnimal(
      sourceAnimalId: sourceAnimalId,
      boxId: duplicatedBoxId,
      commonName: 'Duplicated Animal',
    );

    final backup = await BackupExportService(database).createBackup(
      appVersion: '1.5.0',
      themeMode: ThemeMode.system,
      accent: AppAccent.green,
      createdAt: DateTime(2026, 9, 14, 12),
    );

    expect(
      backup.data.boxes.map((box) => box.id),
      containsAll([sourceBoxId, duplicatedBoxId]),
    );
    expect(
      backup.data.animals.map((animal) => animal.id),
      containsAll([sourceAnimalId, duplicatedAnimalId]),
    );
    expect(backup.data.feedingEvents, hasLength(1));
    expect(backup.data.feedingEvents.single.animalId, sourceAnimalId);
    expect(backup.mediaFileCount, 4);
    expect(
      backup.data.animals
          .firstWhere((animal) => animal.id == duplicatedAnimalId)
          .originHabitat,
      'Forest',
    );
  });
}
