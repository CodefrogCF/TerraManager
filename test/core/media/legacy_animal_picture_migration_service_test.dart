import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/media/legacy_animal_picture_migration_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createLegacyAnimal() async {
    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
          ),
        );

    return database
        .into(database.animals)
        .insert(
          AnimalsCompanion.insert(
            boxId: drift.Value(boxId),
            commonName: 'Legacy Animal',
            latinName: 'Test species',
            tempMin: 20,
            tempMax: 25,
            humidityMin: 40,
            humidityMax: 60,
            picturePath: const drift.Value('legacy/image.jpg'),
          ),
        );
  }

  test('migrates readable legacy picture to MediaAssets', () async {
    final animalId = await createLegacyAnimal();

    final service = LegacyAnimalPictureMigrationService(
      database,
      pictureReader: (path) async {
        expect(path, 'legacy/image.jpg');

        return LegacyPictureData(
          fileName: 'image.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        );
      },
    );

    final result = await service.migrate();

    expect(result.migrated, 1);

    expect(result.skipped, 0);

    final animal = await (database.select(
      database.animals,
    )..where((row) => row.id.equals(animalId))).getSingle();

    expect(animal.picturePath, isNull);

    expect(animal.pictureMediaId, isNotNull);

    final media = await (database.select(
      database.mediaAssets,
    )..where((row) => row.id.equals(animal.pictureMediaId!))).getSingle();

    expect(media.fileName, 'image.jpg');

    expect(media.mimeType, 'image/jpeg');

    expect(media.data, Uint8List.fromList([1, 2, 3, 4]));
  });

  test('preserves legacy path when picture cannot be read', () async {
    final animalId = await createLegacyAnimal();

    final service = LegacyAnimalPictureMigrationService(
      database,
      pictureReader: (_) async {
        throw Exception('File unavailable');
      },
    );

    final result = await service.migrate();

    expect(result.migrated, 0);

    expect(result.skipped, 1);

    final animal = await (database.select(
      database.animals,
    )..where((row) => row.id.equals(animalId))).getSingle();

    expect(animal.picturePath, 'legacy/image.jpg');

    expect(animal.pictureMediaId, isNull);

    expect(await database.select(database.mediaAssets).get(), isEmpty);
  });

  test('does not migrate animal that already has persistent media', () async {
    final mediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'existing.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([9, 8, 7]),
          ),
        );

    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:22222222-2222-4222-8222-222222222222',
          ),
        );

    await database
        .into(database.animals)
        .insert(
          AnimalsCompanion.insert(
            boxId: drift.Value(boxId),
            commonName: 'Animal',
            latinName: 'Species',
            tempMin: 20,
            tempMax: 25,
            humidityMin: 40,
            humidityMax: 60,
            picturePath: const drift.Value('legacy/image.jpg'),
            pictureMediaId: drift.Value(mediaId),
          ),
        );

    var readerCalled = false;

    final service = LegacyAnimalPictureMigrationService(
      database,
      pictureReader: (_) async {
        readerCalled = true;

        throw StateError('Should not be called');
      },
    );

    final result = await service.migrate();

    expect(result.migrated, 0);

    expect(result.skipped, 0);

    expect(readerCalled, isFalse);
  });
}
