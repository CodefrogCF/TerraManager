import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';

void main() {
  late AppDatabase database;
  late MediaRepository repository;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());

    repository = MediaRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and reads media asset', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final id = await repository.createMedia(
      fileName: 'animal.jpg',
      mimeType: 'image/jpeg',
      data: bytes,
    );

    final media = await repository.getMediaById(id);

    expect(media, isNotNull);

    expect(media!.fileName, 'animal.jpg');

    expect(media.mimeType, 'image/jpeg');

    expect(media.data, bytes);
  });

  test('updates existing media asset', () async {
    final id = await repository.createMedia(
      fileName: 'old.jpg',
      mimeType: 'image/jpeg',
      data: Uint8List.fromList([1, 2]),
    );

    final updated = await repository.updateMedia(
      mediaId: id,
      fileName: 'new.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([3, 4, 5]),
    );

    expect(updated, isTrue);

    final media = await repository.getMediaById(id);

    expect(media!.fileName, 'new.png');

    expect(media.mimeType, 'image/png');

    expect(media.data, Uint8List.fromList([3, 4, 5]));
  });

  test('deletes media asset', () async {
    final id = await repository.createMedia(
      fileName: 'animal.jpg',
      mimeType: 'image/jpeg',
      data: Uint8List.fromList([1, 2, 3]),
    );

    final deleted = await repository.deleteMedia(id);

    expect(deleted, isTrue);

    expect(await repository.getMediaById(id), isNull);
  });

  test('rejects empty media data', () async {
    expect(
      () => repository.createMedia(
        fileName: 'animal.jpg',
        mimeType: 'image/jpeg',
        data: Uint8List(0),
      ),
      throwsArgumentError,
    );
  });

  test('animal can reference persistent media asset', () async {
    final mediaId = await repository.createMedia(
      fileName: 'animal.jpg',
      mimeType: 'image/jpeg',
      data: Uint8List.fromList([1, 2, 3]),
    );

    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
          ),
        );

    final animalId = await database
        .into(database.animals)
        .insert(
          AnimalsCompanion.insert(
            boxId: drift.Value(boxId),
            commonName: 'Test Animal',
            latinName: 'Test species',
            tempMin: 20,
            tempMax: 25,
            humidityMin: 40,
            humidityMax: 60,
            pictureMediaId: drift.Value(mediaId),
          ),
        );

    final animal = await (database.select(
      database.animals,
    )..where((animal) => animal.id.equals(animalId))).getSingle();

    expect(animal.pictureMediaId, mediaId);
  });

  test('createAnimal stores pictureMediaId', () async {
    // Media + Box anlegen
    // createAnimal(... pictureMediaId: mediaId)
    // Animal lesen
    // expect(animal.pictureMediaId, mediaId)
  });

  test('permanent deletion removes owned media asset', () async {
    // Media anlegen
    // Animal mit pictureMediaId anlegen
    // archivieren
    // permanentlyDeleteArchivedAnimal()
    // expect MediaAsset null
  });
}
