import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:terramanager/shared_server/media/application/image_upload_validation.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/collection/infrastructure/http/care_api.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/care_authenticator.dart';
import 'package:terramanager/shared_server/media/infrastructure/media_storage_policy.dart';

import '../drift/app_database/generated/schema_v15.dart' as v15;
import '../helpers/test_database_helper.dart';

const _token = 'a-local-test-token-that-is-long-enough';

class _TestBearerAuthenticator implements CareAuthenticator {
  @override
  Future<bool> isAuthenticated(HttpRequest request) async =>
      request.headers.value(HttpHeaders.authorizationHeader) ==
      'Bearer $_token';
}

class _HttpResult {
  final int status;
  final Map<String, dynamic>? json;
  final Uint8List bytes;

  const _HttpResult(this.status, this.json, this.bytes);
}

Future<_HttpResult> _call(
  HttpClient client,
  HttpServer server,
  String method,
  String path, {
  Map<String, dynamic>? body,
  bool authorized = true,
  String? idempotencyKey,
}) async {
  final request = await client.openUrl(
    method,
    Uri.parse('http://127.0.0.1:${server.port}$path'),
  );
  if (authorized) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
  }
  if (idempotencyKey != null ||
      (method == 'POST' && path == '/api/v1/feedings')) {
    request.headers.set(
      'Idempotency-Key',
      idempotencyKey ??
          '00000000-0000-4000-8000-${(_requestNumber++).toString().padLeft(12, '0')}',
    );
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  final builder = BytesBuilder();
  await for (final part in response) {
    builder.add(part);
  }
  final bytes = builder.takeBytes();
  final json = response.headers.contentType?.mimeType == 'application/json'
      ? jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>
      : null;
  return _HttpResult(response.statusCode, json, bytes);
}

int _requestNumber = 1;

Future<int> _createBox(
  HttpClient client,
  HttpServer server,
  String name,
) async {
  final result = await _call(
    client,
    server,
    'POST',
    '/api/v1/boxes',
    body: {'name': name},
  );
  expect(result.status, 201, reason: result.json.toString());
  return (result.json!['box'] as Map<String, dynamic>)['id'] as int;
}

Future<int> _createAnimal(
  HttpClient client,
  HttpServer server,
  int boxId, {
  String name = 'Animal',
}) async {
  final result = await _call(
    client,
    server,
    'POST',
    '/api/v1/animals',
    body: {
      'boxId': boxId,
      'commonName': name,
      'latinName': 'Example species',
      'tempMin': 22,
      'tempMax': 28,
      'humidityMin': 40,
      'humidityMax': 60,
    },
  );
  expect(result.status, 201, reason: result.json.toString());
  return (result.json!['animal'] as Map<String, dynamic>)['id'] as int;
}

void main() {
  late TestDatabaseHelper helper;
  late Directory directory;
  late AppDatabase database;
  late HttpServer server;
  late HttpClient clientA;
  late HttpClient clientB;
  var helperReady = false;
  var serverStarted = false;
  var clientsReady = false;

  Future<void> startServer() async {
    server = await CareApi(
      database: database,
      authenticator: _TestBearerAuthenticator(),
    ).serve();
    serverStarted = true;
  }

  Future<void> stopServer() async {
    if (!serverStarted) return;
    await server.close(force: true);
    serverStarted = false;
  }

  Future<void> restartServerDatabase([File? target]) async {
    await stopServer();
    database = await helper.reopenCollectionDatabase(target);
    await startServer();
  }

  setUp(() async {
    helperReady = false;
    serverStarted = false;
    clientsReady = false;
    clientA = HttpClient();
    clientB = HttpClient();
    clientsReady = true;
    helper = await TestDatabaseHelper.create(
      prefix: 'terramanager-server-',
      openAccountStore: false,
    );
    helperReady = true;
    directory = helper.directory;
    database = helper.database;
    await startServer();
  });

  tearDown(() async {
    await stopServer();
    if (clientsReady) {
      clientA.close(force: true);
      clientB.close(force: true);
      clientsReady = false;
    }
    if (helperReady) {
      await helper.cleanup();
      helperReady = false;
    }
  });

  test(
    'Animal overview returns latest Feeding in one collection response',
    () async {
      final boxId = await _createBox(clientA, server, 'Terrarium');
      final fedAnimal = await _createAnimal(
        clientA,
        server,
        boxId,
        name: 'Fed',
      );
      final unfedAnimal = await _createAnimal(
        clientA,
        server,
        boxId,
        name: 'Never',
      );
      final before = await _call(clientB, server, 'GET', '/api/v1/animals');
      final beforeAnimals = (before.json!['animals'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        beforeAnimals.singleWhere(
          (animal) => animal['id'] == fedAnimal,
        )['latestFeedingAt'],
        isNull,
      );
      expect(
        beforeAnimals.singleWhere(
          (animal) => animal['id'] == unfedAnimal,
        )['latestFeedingAt'],
        isNull,
      );

      final fedAt = DateTime.utc(2026, 9, 25, 10);
      final added = await _call(
        clientA,
        server,
        'POST',
        '/api/v1/feedings',
        body: {
          'animalIds': [fedAnimal],
          'fedAt': fedAt.toIso8601String(),
          'notes': null,
        },
      );
      expect(added.status, 201, reason: added.json.toString());
      final after = await _call(clientB, server, 'GET', '/api/v1/animals');
      final afterAnimals = (after.json!['animals'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        afterAnimals.singleWhere(
          (animal) => animal['id'] == fedAnimal,
        )['latestFeedingAt'],
        fedAt.toIso8601String(),
      );
      expect(
        afterAnimals.singleWhere(
          (animal) => animal['id'] == unfedAnimal,
        )['latestFeedingAt'],
        isNull,
      );
    },
  );

  test('requires authentication and never serves the database file', () async {
    final denied = await _call(
      clientA,
      server,
      'GET',
      '/api/v1/boxes',
      authorized: false,
    );
    expect(denied.status, 401);
    expect((denied.json!['error'] as Map)['code'], 'unauthorized');

    final fileRequest = await _call(
      clientA,
      server,
      'GET',
      '/collection.sqlite',
    );
    expect(fileRequest.status, 404);
  });

  test('two clients share server-owned Box, Animal and QR records', () async {
    final boxId = await _createBox(clientA, server, 'Terrarium 1');
    final fromB = await _call(clientB, server, 'GET', '/api/v1/boxes/$boxId');
    expect(fromB.status, 200);
    final box = fromB.json!['box'] as Map<String, dynamic>;
    expect(box['name'], 'Terrarium 1');
    final qr = box['qrId'] as String;
    final resolved = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/boxes/qr/${Uri.encodeComponent(qr)}',
    );
    expect((resolved.json!['box'] as Map)['id'], boxId);
    final copy = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/boxes/$boxId/duplicate',
      body: {'name': 'Copy'},
    );
    expect(copy.status, 201);
    expect((copy.json!['box'] as Map)['id'], isNot(boxId));
    expect((copy.json!['box'] as Map)['qrId'], isNot(qr));

    final animalId = await _createAnimal(clientA, server, boxId);
    final animal = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId',
    );
    expect(animal.status, 200);
    expect((animal.json!['animal'] as Map)['boxId'], boxId);

    await restartServerDatabase();
    final persisted = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId',
    );
    expect(persisted.status, 200);
    expect((persisted.json!['animal'] as Map)['commonName'], 'Animal');
  });

  test('rejects invalid records and rolls back grouped feeding', () async {
    final boxId = await _createBox(clientA, server, 'Valid Box');
    final animalA = await _createAnimal(clientA, server, boxId, name: 'A');
    final animalB = await _createAnimal(clientA, server, boxId, name: 'B');

    final invalidAnimal = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals',
      body: {
        'boxId': boxId,
        'commonName': 'Invalid',
        'latinName': 'Invalidus',
        'tempMin': 22,
        'tempMax': 28,
        'humidityMin': 101,
        'humidityMax': 101,
      },
    );
    expect(invalidAnimal.status, 400);
    expect((invalidAnimal.json!['error'] as Map)['code'], 'invalid_data');

    final rejected = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/feedings',
      body: {
        'animalIds': [animalA, 999999],
        'fedAt': '2026-09-23T10:00:00Z',
      },
    );
    expect(rejected.status, 409);
    final history = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalA/feedings',
    );
    expect((history.json!['feedings'] as List), isEmpty);

    final created = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/feedings',
      body: {
        'animalIds': [animalA, animalB],
        'fedAt': '2026-09-23T10:00:00Z',
      },
    );
    expect(created.status, 201);
    expect(created.json!['feedings'], hasLength(2));
  });

  test('Box-scoped Feeding rejects changed assignments atomically', () async {
    final firstBox = await _createBox(clientA, server, 'First Box');
    final secondBox = await _createBox(clientA, server, 'Second Box');
    final firstAnimal = await _createAnimal(clientA, server, firstBox);
    final movedAnimal = await _createAnimal(clientA, server, firstBox);

    final moved = await _call(
      clientB,
      server,
      'POST',
      '/api/v1/animals/$movedAnimal/move',
      body: {'boxId': secondBox},
    );
    expect(moved.status, 200);

    final rejected = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/feedings',
      body: {
        'boxId': firstBox,
        'animalIds': [firstAnimal, movedAnimal],
        'fedAt': '2026-09-23T10:00:00Z',
      },
    );
    expect(rejected.status, 409);
    expect(
      (await _call(
        clientA,
        server,
        'GET',
        '/api/v1/animals/$firstAnimal/feedings',
      )).json!['feedings'],
      isEmpty,
    );
    expect(
      (await _call(
        clientA,
        server,
        'GET',
        '/api/v1/animals/$movedAnimal/feedings',
      )).json!['feedings'],
      isEmpty,
    );

    final accepted = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/feedings',
      body: {
        'boxId': firstBox,
        'animalIds': [firstAnimal],
        'fedAt': '2026-09-23T10:00:00Z',
      },
    );
    expect(accepted.status, 201);
    expect(accepted.json!['feedings'], hasLength(1));
  });

  test(
    'shared reminders follow server feeding history and reject stale edits',
    () async {
      final boxId = await _createBox(clientA, server, 'Care Box');
      final animalId = await _createAnimal(clientA, server, boxId);
      final before = await _call(
        clientA,
        server,
        'GET',
        '/api/v1/animals/$animalId',
      );
      final revision = (before.json!['animal'] as Map)['revision'] as String;
      final baseline = DateTime.now().toUtc().subtract(const Duration(days: 5));
      final enabled = await _call(
        clientA,
        server,
        'PUT',
        '/api/v1/animals/$animalId/feeding-reminder',
        body: {
          'expectedRevision': revision,
          'intervalDays': 3,
          'baseline': baseline.toIso8601String(),
        },
      );
      expect(enabled.status, 200, reason: enabled.json.toString());

      final due = await _call(clientB, server, 'GET', '/api/v1/reminders');
      expect(due.status, 200);
      final reminder = (due.json!['reminders'] as List).single as Map;
      expect(reminder['animalId'], animalId);
      expect(reminder['latestFeedingAt'], isNull);
      expect(
        DateTime.parse(reminder['dueAt'] as String).isBefore(DateTime.now()),
        isTrue,
      );

      final fedAt = DateTime.now().toUtc();
      final feeding = await _call(
        clientB,
        server,
        'POST',
        '/api/v1/feedings',
        body: {
          'animalIds': [animalId],
          'fedAt': fedAt.toIso8601String(),
        },
      );
      expect(feeding.status, 201);
      final upcoming = await _call(clientA, server, 'GET', '/api/v1/reminders');
      final next = (upcoming.json!['reminders'] as List).single as Map;
      expect(
        DateTime.parse(next['dueAt'] as String).isAfter(DateTime.now()),
        isTrue,
      );
      expect(next['latestFeedingAt'], isNotNull);

      final stale = await _call(
        clientB,
        server,
        'PUT',
        '/api/v1/animals/$animalId/feeding-reminder',
        body: {
          'expectedRevision': revision,
          'intervalDays': null,
          'baseline': null,
        },
      );
      expect(stale.status, 409);
      expect((stale.json!['error'] as Map)['code'], 'stale_record');

      final disabled = await _call(
        clientB,
        server,
        'PUT',
        '/api/v1/animals/$animalId/feeding-reminder',
        body: {
          'expectedRevision': (enabled.json!['animal'] as Map)['revision'],
          'intervalDays': null,
          'baseline': null,
        },
      );
      expect(disabled.status, 200);
      expect(
        (await _call(
          clientA,
          server,
          'GET',
          '/api/v1/reminders',
        )).json!['reminders'],
        isEmpty,
      );
    },
  );

  test(
    'shared reminder API stores weekday plans and returns their due time',
    () async {
      final boxId = await _createBox(clientA, server, 'Weekday Box');
      final animalId = await _createAnimal(clientA, server, boxId);
      final before = await _call(
        clientA,
        server,
        'GET',
        '/api/v1/animals/$animalId',
      );
      final revision = (before.json!['animal'] as Map)['revision'] as String;
      final enabled = await _call(
        clientA,
        server,
        'PUT',
        '/api/v1/animals/$animalId/feeding-reminder',
        body: {
          'expectedRevision': revision,
          'intervalDays': null,
          'baseline': '2026-10-04T12:00:00Z',
          'weekdays': 1 | 4 | 16,
          'minuteOfDay': 600,
          'timeZone': 'Europe/Berlin',
        },
      );
      expect(enabled.status, 200, reason: enabled.json.toString());
      final saved = enabled.json!['animal'] as Map;
      expect(saved['feedingReminderWeekdays'], 21);
      expect(saved['feedingReminderMinuteOfDay'], 600);
      expect(saved['feedingReminderTimeZone'], 'Europe/Berlin');
      final result = await _call(clientB, server, 'GET', '/api/v1/reminders');
      expect(result.status, 200);
      final reminder = (result.json!['reminders'] as List).single as Map;
      expect(
        DateTime.parse(reminder['dueAt'] as String),
        DateTime.utc(2026, 10, 5, 8),
      );
      final winter = await _call(
        clientA,
        server,
        'PUT',
        '/api/v1/animals/$animalId/feeding-reminder',
        body: {
          'expectedRevision': saved['revision'],
          'intervalDays': null,
          'baseline': '2026-01-04T12:00:00Z',
          'weekdays': 1,
          'minuteOfDay': 18 * 60,
          'timeZone': 'Europe/Berlin',
        },
      );
      expect(winter.status, 200, reason: winter.json.toString());
      final winterResult = await _call(
        clientB,
        server,
        'GET',
        '/api/v1/reminders',
      );
      final winterReminder =
          (winterResult.json!['reminders'] as List).single as Map;
      expect(
        DateTime.parse(winterReminder['dueAt'] as String),
        DateTime.utc(2026, 1, 5, 17),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'QR reassignment rejects an opened Animal revision that became stale',
    () async {
      final firstBox = await _createBox(clientA, server, 'First Box');
      final secondBox = await _createBox(clientA, server, 'Second Box');
      final animalId = await _createAnimal(clientA, server, firstBox);
      final opened = await _call(
        clientA,
        server,
        'GET',
        '/api/v1/animals/$animalId',
      );
      final oldRevision = (opened.json!['animal'] as Map)['revision'];

      final firstMove = await _call(
        clientB,
        server,
        'POST',
        '/api/v1/animals/$animalId/move',
        body: {'boxId': secondBox, 'expectedRevision': oldRevision},
      );
      expect(firstMove.status, 200);

      final staleMove = await _call(
        clientA,
        server,
        'POST',
        '/api/v1/animals/$animalId/move',
        body: {'boxId': firstBox, 'expectedRevision': oldRevision},
      );
      expect(staleMove.status, 409);
      expect((staleMove.json!['error'] as Map)['code'], 'stale_record');

      final current = await _call(
        clientA,
        server,
        'GET',
        '/api/v1/animals/$animalId',
      );
      expect((current.json!['animal'] as Map)['boxId'], secondBox);
    },
  );

  test('lifecycle and reassignment rules are enforced by the server', () async {
    final firstBox = await _createBox(clientA, server, 'First');
    final secondBox = await _createBox(clientA, server, 'Second');
    final animalId = await _createAnimal(clientA, server, firstBox);

    final blocked = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/boxes/$firstBox/archive',
      body: {'reason': 'replaced'},
    );
    expect(blocked.status, 409);

    final archivedAnimal = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/archive',
      body: {'reason': 'rehomed'},
    );
    expect(archivedAnimal.status, 200);
    expect((archivedAnimal.json!['animal'] as Map)['boxId'], isNull);

    final archivedBox = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/boxes/$firstBox/archive',
      body: {'reason': 'replaced'},
    );
    expect(archivedBox.status, 200);

    final invalidRestore = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/restore',
      body: {'boxId': firstBox},
    );
    expect(invalidRestore.status, 409);

    final restored = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/restore',
      body: {'boxId': secondBox},
    );
    expect(restored.status, 200);
    expect((restored.json!['animal'] as Map)['boxId'], secondBox);

    final noOpMove = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/move',
      body: {'boxId': secondBox},
    );
    expect(noOpMove.status, 409);
    final invalidMove = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/move',
      body: {'boxId': firstBox},
    );
    expect(invalidMove.status, 409);
    final stillAssigned = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId',
    );
    expect((stillAssigned.json!['animal'] as Map)['boxId'], secondBox);
  });

  test('weight, shedding and media use the server database', () async {
    final boxId = await _createBox(clientA, server, 'With histories');
    final animalId = await _createAnimal(clientA, server, boxId);
    final weight = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/weights',
      body: {'weightGrams': 12.5},
    );
    expect(weight.status, 201);
    final weightId = (weight.json!['weight'] as Map)['id'];
    final shedding = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/shedding',
      body: {'shedAt': '2026-09-23T09:00:00Z', 'notes': 'Complete'},
    );
    expect(shedding.status, 201);
    final histories = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId/weights',
    );
    expect((histories.json!['weights'] as List).single['id'], weightId);

    final png = base64Encode(image.encodePng(image.Image(width: 1, height: 1)));
    final upload = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/media',
      body: {'fileName': 'one.png', 'mimeType': 'image/png', 'dataBase64': png},
    );
    expect(upload.status, 404);
    expect((await database.select(database.mediaAssets).get()), isEmpty);

    final attached = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/pictures',
      body: {
        'fileName': 'gallery.png',
        'mimeType': 'image/png',
        'dataBase64': png,
      },
    );
    expect(attached.status, 201);
    final galleryMediaId = (attached.json!['picture'] as Map)['mediaId'];
    final download = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/media/$galleryMediaId',
    );
    expect(download.status, 200);
    expect(download.bytes, base64Decode(png));
    final gallery = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId/pictures',
    );
    expect(
      (gallery.json!['pictures'] as List).single['mediaId'],
      galleryMediaId,
    );
    final removed = await _call(
      clientA,
      server,
      'DELETE',
      '/api/v1/animals/$animalId/pictures/$galleryMediaId',
    );
    expect(removed.status, 200);
    final noLongerReferenced = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/media/$galleryMediaId',
    );
    expect(noLongerReferenced.status, 404);
  });

  test(
    'gallery uploads decode images and reject malformed or excessive data',
    () async {
      final boxId = await _createBox(clientA, server, 'Image checks');
      final valid = image.encodePng(image.Image(width: 2, height: 2));
      final oversizedDimensions = Uint8List.fromList(valid);
      // The PNG IHDR width/height precede pixel decompression.
      oversizedDimensions.setRange(16, 24, [0, 0, 0x40, 0, 0, 0, 0x40, 0]);
      final attempts = <(String, Uint8List)>[
        ('image/png', Uint8List.fromList([0x89, 0x50, 0x4e, 0x47])),
        ('image/png', oversizedDimensions),
        ('image/jpeg', valid),
      ];
      for (final (mime, bytes) in attempts) {
        final response = await _call(
          clientA,
          server,
          'POST',
          '/api/v1/boxes/$boxId/pictures',
          body: {
            'fileName': 'bad-picture',
            'mimeType': mime,
            'dataBase64': base64Encode(bytes),
          },
        );
        expect(response.status, 400, reason: response.json.toString());
        expect((response.json!['error'] as Map)['code'], 'invalid_data');
      }
      final tooManyBytes = await _call(
        clientA,
        server,
        'POST',
        '/api/v1/boxes/$boxId/pictures',
        body: {
          'fileName': 'oversized.png',
          'mimeType': 'image/png',
          'dataBase64': base64Encode(Uint8List(maxUploadImageBytes + 1)),
        },
      );
      expect(tooManyBytes.status, 400);
      expect(await database.select(database.mediaAssets).get(), isEmpty);

      for (final (mime, bytes) in <(String, Uint8List)>[
        ('image/png', valid),
        ('image/jpeg', image.encodeJpg(image.Image(width: 2, height: 2))),
        ('image/webp', image.encodeWebP(image.Image(width: 2, height: 2))),
      ]) {
        final added = await _call(
          clientA,
          server,
          'POST',
          '/api/v1/boxes/$boxId/pictures',
          body: {
            'fileName': 'picture',
            'mimeType': mime,
            'dataBase64': base64Encode(bytes),
          },
        );
        expect(added.status, 201, reason: added.json.toString());
        final mediaId = (added.json!['picture'] as Map)['mediaId'];
        final downloaded = await _call(
          clientB,
          server,
          'GET',
          '/api/v1/media/$mediaId',
        );
        expect(downloaded.status, 200);
        expect(downloaded.bytes, bytes);
      }
    },
  );

  test('storage limit rejects a gallery upload without an orphan', () async {
    final boxId = await _createBox(clientA, server, 'Limited gallery');
    final bytes = image.encodePng(image.Image(width: 2, height: 2));
    await MediaStoragePolicy(database).install(maxBytes: bytes.length + 1);

    Future<_HttpResult> upload() => _call(
      clientA,
      server,
      'POST',
      '/api/v1/boxes/$boxId/pictures',
      body: {
        'fileName': 'picture.png',
        'mimeType': 'image/png',
        'dataBase64': base64Encode(bytes),
      },
    );

    final first = await upload();
    expect(first.status, 201, reason: first.json.toString());
    final second = await upload();
    expect(second.status, 413, reason: second.json.toString());
    expect((second.json!['error'] as Map)['code'], 'media_storage_limit');
    final gallery = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/boxes/$boxId/pictures',
    );
    expect((gallery.json!['pictures'] as List), hasLength(1));
    expect(await database.select(database.mediaAssets).get(), hasLength(1));
  });

  for (final kind in ['boxes', 'animals']) {
    test('$kind picture retry replays one durable upload', () async {
      final boxId = await _createBox(clientA, server, 'Retry gallery');
      final recordId = kind == 'boxes'
          ? boxId
          : await _createAnimal(clientA, server, boxId);
      final path = '/api/v1/$kind/$recordId/pictures';
      const key = '12345678-1234-4123-8123-123456789abc';
      final body = {
        'fileName': 'retry.png',
        'mimeType': 'image/png',
        'dataBase64': base64Encode(
          image.encodePng(image.Image(width: 2, height: 2)),
        ),
      };
      final responses = await Future.wait([
        _call(clientA, server, 'POST', path, body: body, idempotencyKey: key),
        _call(clientB, server, 'POST', path, body: body, idempotencyKey: key),
      ]);
      expect(responses.map((reply) => reply.status), everyElement(201));
      final mediaId = (responses.first.json!['picture'] as Map)['mediaId'];
      expect((responses.last.json!['picture'] as Map)['mediaId'], mediaId);
      expect(await database.select(database.mediaAssets).get(), hasLength(1));

      await restartServerDatabase();

      final replay = await _call(
        clientB,
        server,
        'POST',
        path,
        body: body,
        idempotencyKey: key,
      );
      expect(replay.status, 201, reason: replay.json.toString());
      expect((replay.json!['picture'] as Map)['mediaId'], mediaId);
      final gallery = await _call(clientB, server, 'GET', path);
      expect(gallery.status, 200);
      expect((gallery.json!['pictures'] as List), hasLength(1));

      final conflict = await _call(
        clientB,
        server,
        'POST',
        path,
        body: {...body, 'fileName': 'changed.png'},
        idempotencyKey: key,
      );
      expect(conflict.status, 409);
      expect((conflict.json!['error'] as Map)['code'], 'idempotency_conflict');
      expect(await database.select(database.mediaAssets).get(), hasLength(1));

      final removed = await _call(clientA, server, 'DELETE', '$path/$mediaId');
      expect(removed.status, 200);
      final deletedReplay = await _call(
        clientB,
        server,
        'POST',
        path,
        body: body,
        idempotencyKey: key,
      );
      expect(deletedReplay.status, 409);
      expect(await database.select(database.mediaAssets).get(), isEmpty);
    });
  }

  test('a disconnected picture upload leaves no media asset', () async {
    final boxId = await _createBox(clientA, server, 'Interrupted upload');
    final request = await clientA.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}/api/v1/boxes/$boxId/pictures'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    request.headers.contentType = ContentType.json;
    request.contentLength = 100000;
    request.write('{"fileName":"incomplete.png","mimeType":"image/png",');
    await request.flush();
    request.abort();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await database.select(database.mediaAssets).get(), isEmpty);
    final gallery = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/boxes/$boxId/pictures',
    );
    expect((gallery.json!['pictures'] as List), isEmpty);
  });

  test('server validates edits and keeps QR identifiers immutable', () async {
    final boxId = await _createBox(clientA, server, 'Editable');
    final original = await _call(
      clientA,
      server,
      'GET',
      '/api/v1/boxes/$boxId',
    );
    final qrId = (original.json!['box'] as Map)['qrId'];
    final editBox = await _call(
      clientA,
      server,
      'PATCH',
      '/api/v1/boxes/$boxId',
      body: {
        'name': 'Renamed',
        'widthCm': 40,
        'expectedRevision': (original.json!['box'] as Map)['revision'],
      },
    );
    expect(editBox.status, 200);
    expect((editBox.json!['box'] as Map)['qrId'], qrId);
    final forgedQr = await _call(
      clientA,
      server,
      'PATCH',
      '/api/v1/boxes/$boxId',
      body: {'qrId': 'forged'},
    );
    expect(forgedQr.status, 400);

    final animalId = await _createAnimal(clientA, server, boxId);
    final initialAnimal = await _call(
      clientA,
      server,
      'GET',
      '/api/v1/animals/$animalId',
    );
    final invalid = await _call(
      clientA,
      server,
      'PUT',
      '/api/v1/animals/$animalId',
      body: {
        'expectedRevision': (initialAnimal.json!['animal'] as Map)['revision'],
        'boxId': boxId,
        'commonName': 'Changed',
        'latinName': 'Example species',
        'category': 'arachnid',
        'subcategory': 'snake',
        'tempMin': 20,
        'tempMax': 25,
        'humidityMin': 40,
        'humidityMax': 60,
        'showWeightOnDetail': true,
        'showSheddingOnDetail': true,
      },
    );
    expect(invalid.status, 400);
    final unchanged = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId',
    );
    expect((unchanged.json!['animal'] as Map)['commonName'], 'Animal');

    final weight = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/weights',
      body: {'weightGrams': 11},
    );
    final weightId = (weight.json!['weight'] as Map)['id'];
    final changedWeight = await _call(
      clientB,
      server,
      'PUT',
      '/api/v1/animals/$animalId/weights/$weightId',
      body: {'weightGrams': 12.5, 'measuredAt': '2026-09-23T12:00:00Z'},
    );
    expect(changedWeight.status, 200);
    expect((changedWeight.json!['weight'] as Map)['weightGrams'], 12.5);
    final removedWeight = await _call(
      clientA,
      server,
      'DELETE',
      '/api/v1/animals/$animalId/weights/$weightId',
    );
    expect(removedWeight.status, 200);

    final shedding = await _call(
      clientA,
      server,
      'POST',
      '/api/v1/animals/$animalId/shedding',
      body: {'notes': 'First'},
    );
    final eventId = (shedding.json!['shedding'] as Map)['id'];
    final changedShedding = await _call(
      clientB,
      server,
      'PUT',
      '/api/v1/animals/$animalId/shedding/$eventId',
      body: {'shedAt': '2026-09-23T12:00:00Z', 'notes': 'Updated'},
    );
    expect(changedShedding.status, 200);
    expect((changedShedding.json!['shedding'] as Map)['notes'], 'Updated');
    final removedShedding = await _call(
      clientB,
      server,
      'DELETE',
      '/api/v1/animals/$animalId/shedding/$eventId',
    );
    expect(removedShedding.status, 200);
  });

  test('two caregivers cannot overwrite an older Box or Animal form', () async {
    final boxId = await _createBox(clientA, server, 'Original');
    final first = await _call(clientA, server, 'GET', '/api/v1/boxes/$boxId');
    final oldRevision = (first.json!['box'] as Map)['revision'] as String;
    final changed = await _call(
      clientA,
      server,
      'PATCH',
      '/api/v1/boxes/$boxId',
      body: {'name': 'First edit', 'expectedRevision': oldRevision},
    );
    expect(changed.status, 200);
    final stale = await _call(
      clientB,
      server,
      'PATCH',
      '/api/v1/boxes/$boxId',
      body: {'name': 'Second edit', 'expectedRevision': oldRevision},
    );
    expect(stale.status, 409);
    expect((stale.json!['error'] as Map)['code'], 'stale_record');
    final current = await _call(clientB, server, 'GET', '/api/v1/boxes/$boxId');
    expect((current.json!['box'] as Map)['name'], 'First edit');

    final animalId = await _createAnimal(clientA, server, boxId);
    final before = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId',
    );
    final animalRevision =
        (before.json!['animal'] as Map)['revision'] as String;
    final edit = await _call(
      clientA,
      server,
      'PUT',
      '/api/v1/animals/$animalId',
      body: {
        'boxId': boxId,
        'commonName': 'Changed by A',
        'latinName': 'Example species',
        'category': 'other',
        'tempMin': 22,
        'tempMax': 28,
        'humidityMin': 40,
        'humidityMax': 60,
        'showWeightOnDetail': true,
        'showSheddingOnDetail': true,
        'expectedRevision': animalRevision,
      },
    );
    expect(edit.status, 200, reason: edit.json.toString());
    final staleAnimal = await _call(
      clientB,
      server,
      'PUT',
      '/api/v1/animals/$animalId',
      body: {
        'boxId': boxId,
        'commonName': 'Changed by B',
        'latinName': 'Example species',
        'category': 'other',
        'tempMin': 22,
        'tempMax': 28,
        'humidityMin': 40,
        'humidityMax': 60,
        'showWeightOnDetail': true,
        'showSheddingOnDetail': true,
        'expectedRevision': animalRevision,
      },
    );
    expect(staleAnimal.status, 409);
    expect((staleAnimal.json!['error'] as Map)['code'], 'stale_record');
    final latest = await _call(
      clientB,
      server,
      'GET',
      '/api/v1/animals/$animalId',
    );
    expect((latest.json!['animal'] as Map)['commonName'], 'Changed by A');
  });

  test(
    'repeated grouped feeding request returns the first result once',
    () async {
      final boxId = await _createBox(clientA, server, 'Feeding');
      final animalA = await _createAnimal(clientA, server, boxId, name: 'A');
      final animalB = await _createAnimal(clientA, server, boxId, name: 'B');
      const key = 'b73f3a4c-2c33-4786-9db8-39c70650a133';
      final body = {
        'animalIds': [animalA, animalB],
        'fedAt': '2026-09-23T10:00:00Z',
        'notes': 'Shared meal',
      };
      final responses = await Future.wait([
        _call(
          clientA,
          server,
          'POST',
          '/api/v1/feedings',
          body: body,
          idempotencyKey: key,
        ),
        _call(
          clientB,
          server,
          'POST',
          '/api/v1/feedings',
          body: body,
          idempotencyKey: key,
        ),
      ]);
      expect(responses.map((result) => result.status), everyElement(201));
      expect(responses[0].json, responses[1].json);
      final history = await _call(
        clientA,
        server,
        'GET',
        '/api/v1/animals/$animalA/feedings',
      );
      expect(history.json!['feedings'], hasLength(1));
      final reused = await _call(
        clientB,
        server,
        'POST',
        '/api/v1/feedings',
        body: {...body, 'notes': 'Different'},
        idempotencyKey: key,
      );
      expect(reused.status, 409);
      expect((reused.json!['error'] as Map)['code'], 'idempotency_conflict');
    },
  );

  test(
    'opening an existing server file migrates without losing data',
    () async {
      await stopServer();
      await helper.closeCollectionDatabase();
      final olderFile = File(
        '${directory.path}${Platform.pathSeparator}older.sqlite',
      );
      final oldDatabase = v15.DatabaseAtV15(NativeDatabase(olderFile));
      await oldDatabase.customSelect('SELECT 1').get();
      await oldDatabase.customStatement(
        "INSERT INTO boxes (qr_id, name) "
        "VALUES ('TM:BOX:12345678-1234-4123-8123-123456789abc', 'Kept Box')",
      );
      await oldDatabase.customStatement(
        "INSERT INTO animals "
        "(box_id, common_name, latin_name, temp_min, temp_max, "
        "humidity_min, humidity_max) "
        "VALUES (1, 'Kept Animal', 'Example species', 20, 25, 40, 60)",
      );
      await oldDatabase.close();

      database = await helper.reopenCollectionDatabase(olderFile);
      await startServer();
      final rows = await database.select(database.animals).get();
      expect(rows, hasLength(1));
      expect(rows.single.commonName, 'Kept Animal');
      expect(rows.single.showWeightOnDetail, isTrue);
      expect(rows.single.showSheddingOnDetail, isTrue);
      final boxes = await database.select(database.boxes).get();
      expect(boxes.single.name, 'Kept Box');
    },
  );
}
