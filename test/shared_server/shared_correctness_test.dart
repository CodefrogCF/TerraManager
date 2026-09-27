import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/shared_server/shared_portable_backups.dart';
import 'package:terramanager/shared_server/account_store.dart';
import 'package:terramanager/shared_server/server_database.dart';
import 'package:terramanager/shared_server/shared_server_api.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late AccountStore accounts;
  late HttpServer server;
  late HttpClient client;
  late CareSession admin;
  late CareSession caregiver;
  Future<(int, Map<String, dynamic>)> call(
    String method,
    String path, {
    Map<String, Object?>? body,
    CareSession? session,
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    final current = session ?? admin;
    request.headers.set(
      'Cookie',
      '__Host-TerraManagerSession=${current.token}',
    );
    request.headers.set('X-CSRF-Token', current.csrfToken);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    return (
      response.statusCode,
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>,
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm-correctness-');
    db = await openServerDatabase(File('${dir.path}/collection.sqlite'));
    accounts = await AccountStore.open(File('${dir.path}/accounts.sqlite'));
    admin = accounts.createSession(
      await accounts.createInitialAdministrator(
        'admin',
        'secure password admin123',
      ),
    );
    caregiver = accounts.createSession(
      await accounts.createAccount(
        'carer',
        'secure password carer123',
        CareRole.caregiver,
      ),
    );
    server = await SharedServerApi(
      database: db,
      accounts: accounts,
      publicUrl: Uri.parse('http://127.0.0.1'),
    ).serve();
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    await db.close();
    accounts.close();
    await dir.delete(recursive: true);
  });

  test(
    'duplicating Boxes and Animals commits through the audited server',
    () async {
      final picture = await MediaRepository(db).createMedia(
        fileName: 'source.png',
        mimeType: 'image/png',
        data: Uint8List.fromList([1, 2, 3]),
      );
      final box = await BoxRepository(db).createBoxWithGeneratedQrId(
        name: 'Original',
        notes: 'Keep original',
        widthCm: 20,
        pictureMediaId: picture,
      );
      final animal = await AnimalRepository(db).createAnimal(
        boxId: box,
        commonName: 'Original animal',
        latinName: 'Species',
        tempMin: 20,
        tempMax: 30,
        humidityMin: 40,
        humidityMax: 60,
        pictureMediaId: picture,
      );
      final originalBox = await BoxRepository(db).getBoxById(box);
      final originalAnimal = await AnimalRepository(db).getAnimalById(animal);
      await FeedingRepository(db)
          .addFeeding(animal, DateTime.utc(2026, 1, 15, 18));
      final duplicate = await call(
        'POST',
        '/api/v1/boxes/$box/duplicate',
        body: {'name': 'Copy'},
        session: caregiver,
      );
      expect(duplicate.$1, 201, reason: duplicate.$2.toString());
      final newBox = duplicate.$2['box'] as Map;
      expect(newBox['id'], isNot(box));
      expect(
        newBox['qrId'],
        isNot((await BoxRepository(db).getBoxById(box))!.qrId),
      );
      expect(newBox['name'], 'Copy');
      expect(newBox['notes'], 'Keep original');
      expect(newBox['pictureMediaId'], isNot(picture));
      expect(
        (await MediaRepository(db)
                .getMediaById(newBox['pictureMediaId'] as int))!
            .data,
        [1, 2, 3],
      );
      final copiedAnimal = await call(
        'POST',
        '/api/v1/animals/$animal/duplicate',
        body: {'boxId': newBox['id'], 'commonName': 'Copy animal'},
        session: caregiver,
      );
      expect(copiedAnimal.$1, 201, reason: copiedAnimal.$2.toString());
      expect(copiedAnimal.$2['animal']['id'], isNot(animal));
      expect(copiedAnimal.$2['animal']['boxId'], newBox['id']);
      expect(copiedAnimal.$2['animal']['pictureMediaId'], isNot(picture));
      expect(
        await FeedingRepository(db)
            .getFeedingsForAnimal(copiedAnimal.$2['animal']['id'] as int),
        isEmpty,
      );
      expect(await BoxRepository(db).getBoxById(box), originalBox);
      expect(await AnimalRepository(db).getAnimalById(animal), originalAnimal);
      final before = await AnimalRepository(db).getAllAnimals();
      expect(
        (await call(
          'POST',
          '/api/v1/animals/$animal/duplicate',
          body: {'boxId': 99999, 'commonName': 'Bad destination'},
          session: caregiver,
        )).$1,
        409,
      );
      expect(await AnimalRepository(db).getAllAnimals(), before);
      expect(
        (await AnimalRepository(db).getAnimalById(animal))!.commonName,
        'Original animal',
      );
    },
  );

  test('caregiver visibility changes persist through other sessions and backup restore without changing history', () async {
    final box = await BoxRepository(db).createBoxWithGeneratedQrId();
    final id = await AnimalRepository(db).createAnimal(
      boxId: box,
      commonName: 'Animal',
      latinName: 'Species',
      tempMin: 20,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 60,
    );
    await AnimalWeightRepository(db).add(
      animalId: id,
      weightGrams: 12.5,
      measuredAt: DateTime.utc(2026, 7, 1, 17),
    );
    await SheddingRepository(db).add(
      animalId: id,
      shedAt: DateTime.utc(2026, 7, 2, 17),
      notes: 'Keep history',
    );
    final beforeWeight = (await call('GET', '/api/v1/animals/$id/weights')).$2;
    final beforeShedding = (await call(
      'GET',
      '/api/v1/animals/$id/shedding',
    )).$2;
    Future<int> setVisibility(Object weight, bool shedding) async {
      final current =
          (await call('GET', '/api/v1/animals/$id')).$2['animal'] as Map;
      return (await call(
        'PUT',
        '/api/v1/animals/$id',
        session: caregiver,
        body: {
          'boxId': box,
          'commonName': 'Animal',
          'latinName': 'Species',
          'category': 'other',
          'tempMin': 20,
          'tempMax': 30,
          'humidityMin': 40,
          'humidityMax': 60,
          'showWeightOnDetail': weight,
          'showSheddingOnDetail': shedding,
          'expectedRevision': current['revision'],
        },
      )).$1;
    }

    expect(await setVisibility(false, false), 200);
    final hidden =
        (await call(
              'GET',
              '/api/v1/animals/$id',
              session: accounts.createSession(admin.account),
            )).$2['animal']
            as Map;
    expect(hidden['showWeightOnDetail'], isFalse);
    expect(hidden['showSheddingOnDetail'], isFalse);
    final backups = SharedPortableBackups(db);
    await backups.restore(backups.validate((await backups.export()).bytes));
    final restored =
        (await call('GET', '/api/v1/animals/$id')).$2['animal'] as Map;
    expect(restored['showWeightOnDetail'], isFalse);
    expect(restored['showSheddingOnDetail'], isFalse);
    expect((await call('GET', '/api/v1/animals/$id/weights')).$2, beforeWeight);
    expect(
      (await call('GET', '/api/v1/animals/$id/shedding')).$2,
      beforeShedding,
    );
    expect(await setVisibility('invalid', true), 400);
    expect(await setVisibility(true, true), 200);
    expect((await call('GET', '/api/v1/animals/$id/weights')).$2, beforeWeight);
    expect(
      (await call('GET', '/api/v1/animals/$id/shedding')).$2,
      beforeShedding,
    );
    final shown =
        (await call('GET', '/api/v1/animals/$id')).$2['animal'] as Map;
    expect(shown['showWeightOnDetail'], isTrue);
    expect(shown['showSheddingOnDetail'], isTrue);
  });

  test('preferences belong to accounts, survive sessions and reject foreign fields', () async {
    expect(
      (await call(
        'GET',
        '/api/v1/auth/preferences',
        session: caregiver,
      )).$2['preferences']['accent'],
      'green',
    );
    expect(
      (await call(
        'PATCH',
        '/api/v1/auth/preferences',
        body: {'accent': 'purple', 'animal_name_order': 'latinNameFirst'},
        session: caregiver,
      )).$1,
      200,
    );
    final fresh = accounts.createSession(caregiver.account);
    expect(
      (await call(
        'GET',
        '/api/v1/auth/session',
        session: fresh,
      )).$2['preferences']['accent'],
      'purple',
    );
    final archive = await SharedPortableBackups(db).export();
    final snapshot = SharedPortableBackups(db).validate(archive.bytes);
    expect(snapshot.settings.scope, 'collectionOnly');
    expect(snapshot.settings.accent, 'green');
    await SharedPortableBackups(db).restore(snapshot);
    expect(accounts.preferences(caregiver.account.id)['accent'], 'purple');
    final reopened = await AccountStore.open(
      File('${dir.path}/accounts.sqlite'),
    );
    expect(reopened.preferences(caregiver.account.id)['accent'], 'purple');
    reopened.close();
    expect(
      (await call(
        'GET',
        '/api/v1/auth/preferences',
      )).$2['preferences']['accent'],
      'green',
    );
    expect(
      (await call(
        'PATCH',
        '/api/v1/auth/preferences',
        body: {'accountId': admin.account.id, 'accent': 'red'},
        session: caregiver,
      )).$1,
      400,
    );
    expect(
      (await call(
        'PATCH',
        '/api/v1/auth/preferences',
        body: {'accent': 'unknown'},
        session: caregiver,
      )).$1,
      400,
    );
    expect(
      (await call(
        'PATCH',
        '/api/v1/auth/preferences',
        body: {'big_picture_mode_enabled': 'true'},
        session: caregiver,
      )).$1,
      400,
    );
    expect(
      (await call(
        'GET',
        '/api/v1/auth/preferences',
        session: caregiver,
      )).$2['preferences']['accent'],
      'purple',
    );
  });

  test(
    'every collection DELETE is forbidden to caregivers before dispatch',
    () async {
      final box = await call(
        'POST',
        '/api/v1/boxes',
        body: {'name': 'Protected'},
        session: caregiver,
      );
      final boxId = box.$2['box']['id'];
      final animal = await call(
        'POST',
        '/api/v1/animals',
        body: {
          'boxId': boxId,
          'commonName': 'Protected',
          'latinName': 'Species',
          'tempMin': 20,
          'tempMax': 30,
          'humidityMin': 40,
          'humidityMax': 60,
        },
        session: caregiver,
      );
      final id = animal.$2['animal']['id'];
      final feedingId = await FeedingRepository(db)
          .addFeeding(id as int, DateTime.utc(2026, 1, 15, 18));
      final animalPicture = await PictureGalleryRepository(db).addAnimalPicture(
        animalId: id,
        fileName: 'a.png',
        mimeType: 'image/png',
        data: Uint8List.fromList([1, 2, 3]),
      );
      final boxPicture = await PictureGalleryRepository(db).addBoxPicture(
        boxId: boxId as int,
        fileName: 'b.png',
        mimeType: 'image/png',
        data: Uint8List.fromList([4, 5, 6]),
      );
      final weight = await call(
        'POST',
        '/api/v1/animals/$id/weights',
        body: {'weightGrams': 12, 'measuredAt': '2026-01-15T18:00:00Z'},
        session: caregiver,
      );
      final shed = await call(
        'POST',
        '/api/v1/animals/$id/shedding',
        body: {'shedAt': '2026-01-15T18:00:00Z'},
        session: caregiver,
      );
      for (final path in [
        '/api/v1/boxes/$boxId',
        '/api/v1/animals/$id',
        '/api/v1/feedings/$feedingId',
        '/api/v1/animals/$id/weights/${weight.$2['weight']['id']}',
        '/api/v1/animals/$id/shedding/${shed.$2['shedding']['id']}',
        '/api/v1/animals/$id/pictures/$animalPicture',
        '/api/v1/boxes/$boxId/pictures/$boxPicture',
        '/api/v1/media/$animalPicture',
      ]) {
        expect(
          (await call('DELETE', path, session: caregiver)).$1,
          403,
          reason: path,
        );
      }
      expect(
        (await call('GET', '/api/v1/animals/$id/weights')).$2['weights'],
        hasLength(1),
      );
      expect(await FeedingRepository(db).getFeedingById(feedingId), isNotNull);
      expect(
        await PictureGalleryRepository(db).getAnimalPictures(id),
        hasLength(1),
      );
      expect(
        await PictureGalleryRepository(db).getBoxPictures(boxId),
        hasLength(1),
      );
      expect((await call('DELETE', '/api/v1/feedings/$feedingId')).$1, 200);
      expect(
        (await call(
          'DELETE',
          '/api/v1/animals/$id/pictures/$animalPicture',
        )).$1,
        200,
      );
      expect(
        (await call('GET', '/api/v1/animals/$id/shedding')).$2['shedding'],
        hasLength(1),
      );
      expect(
        (await call(
          'POST',
          '/api/v1/animals/$id/archive',
          body: {'reason': 'other'},
          session: caregiver,
        )).$1,
        200,
      );
      expect(
        (await call('DELETE', '/api/v1/animals/$id', session: caregiver)).$1,
        403,
      );
      expect((await call('DELETE', '/api/v1/animals/$id')).$1, 200);
    },
  );
}
