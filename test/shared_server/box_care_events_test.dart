import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import '../drift/app_database/generated/schema_v18.dart' as v18;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/app/shared_server_api.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/audit/application/audit_query.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

class CookieClient extends http.BaseClient {
  final inner = http.Client();
  String? cookie;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (cookie != null) request.headers['Cookie'] = cookie!;
    final response = await inner.send(request);
    final received = response.headers['set-cookie'];
    if (received != null) cookie = received.split(';').first;
    return response;
  }

  @override
  void close() => inner.close();
}

void main() {
  test('real Shared Care client/server enforce auth revisions replay isolation and Box invalidations', () async {
    final directory = await Directory.systemTemp.createTemp('tm238-http-');
    AccountStore? accounts;
    AppDatabase? database;
    HttpServer? server;
    final adminHttp = CookieClient();
    final keeperHttp = CookieClient();
    final anonymous = http.Client();
    SharedApiClient? admin;
    SharedApiClient? keeper;
    try {
      accounts = await AccountStore.open(
        File('${directory.path}/accounts.sqlite'),
      );
      final old = v18.DatabaseAtV18(
        NativeDatabase(File('${directory.path}/collection.sqlite')),
      );
      final existingBox = await old
          .into(old.boxes)
          .insert(
            v18.BoxesCompanion.insert(
              qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
            ),
          );
      await old.close();
      database = await openServerDatabase(
        File('${directory.path}/collection.sqlite'),
      );
      await accounts.createInitialAdministrator(
        'admin',
        'secure admin password 123',
      );
      await accounts.createAccount(
        'keeper',
        'secure keeper password 123',
        CareRole.caregiver,
      );
      final service = SharedServerApi(
        database: database,
        accounts: accounts,
        publicUrl: Uri.parse('http://127.0.0.1'),
      );
      server = await service.serve();
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      admin = SharedApiClient(origin, adminHttp);
      keeper = SharedApiClient(origin, keeperHttp);
      await admin.login('admin', 'secure admin password 123');
      await keeper.login('keeper', 'secure keeper password 123');
      expect(await admin.boxCareEvents(existingBox), isEmpty);
      final before = await adminHttp.get(
        origin.resolve('/api/v1/boxes/$existingBox/care-events'),
      );
      expect(before.statusCode, 200);
      expect(jsonDecode(before.body)['careEvents'], isEmpty);
      final box = (await admin.createBox({'name': 'Care Box'}))['id'] as int;
      final other = (await admin.createBox({'name': 'Other Box'}))['id'] as int;
      final path = origin.resolve('/api/v1/boxes/$box/care-events');
      expect((await anonymous.get(path)).statusCode, 401);
      expect(
        (await adminHttp.post(
          path,
          body: '{}',
          headers: {'Content-Type': 'application/json'},
        )).statusCode,
        403,
      );
      final at = DateTime.utc(2026, 1, 2, 12);
      final cursor = (await admin.queryChanges()).cursor;
      final change = service.changes.revision;
      await keeper.saveBoxCareEvent(
        box,
        type: BoxCareEventType.substrateChange,
        occurredAt: at,
        notes: 'Private care notes',
        requestId: 'retry-238',
      );
      final afterCreate = service.changes.revision;
      final delta = await admin.queryChanges(since: cursor);
      final resources =
          ((delta.body!['changes'] as List).single as Map)['resources'] as Map;
      expect(resources['boxCareHistories'], [box]);
      expect(resources.containsKey('animals'), false);
      expect(resources.containsKey('boxes'), false);
      expect(jsonEncode(delta.body), isNot(contains('Private care notes')));
      expect(afterCreate, greaterThan(change));
      final entry = (await admin.boxCareEvents(box)).single;
      expect(entry.boxId, box);
      expect(entry.type, BoxCareEventType.substrateChange);
      expect(entry.toJson(), isNot(contains('mediaIds')));
      final retiredField = await keeperHttp.post(
        path,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': keeper.session!.csrfToken,
        },
        body: jsonEncode({
          'type': 'cleaning',
          'occurredAt': at.toIso8601String(),
          'requestId': 'retired-picture-field',
          'mediaIds': [1],
        }),
      );
      expect(retiredField.statusCode, 400);

      await keeper.saveBoxCareEvent(
        box,
        type: BoxCareEventType.substrateChange,
        occurredAt: at,
        notes: 'Private care notes',
        requestId: 'retry-238',
      );
      expect(await keeper.boxCareEvents(box), hasLength(1));
      expect(service.changes.revision, afterCreate);
      await keeper.saveBoxCareEvent(
        box,
        existing: entry,
        type: BoxCareEventType.cleaning,
        occurredAt: at,
        notes: 'Updated',
        requestId: 'ignored-for-update',
      );
      await expectLater(
        admin.saveBoxCareEvent(
          box,
          existing: entry,
          type: BoxCareEventType.waterChange,
          occurredAt: at,
          requestId: 'stale',
        ),
        throwsA(
          isA<SharedApiException>().having(
            (e) => e.code,
            'code',
            'stale_record',
          ),
        ),
      );
      final current = (await admin.boxCareEvents(box)).single;
      expect(current.type, BoxCareEventType.cleaning);
      await expectLater(
        admin.saveBoxCareEvent(
          other,
          existing: current,
          type: BoxCareEventType.waterChange,
          occurredAt: at,
          requestId: 'wrong-box',
        ),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 409),
        ),
      );
      await expectLater(
        keeper.deleteBoxCareEvent(current),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 403),
        ),
      );
      await expectLater(
        admin.saveBoxCareEvent(
          box,
          type: BoxCareEventType.waterChange,
          occurredAt: DateTime.now().add(const Duration(days: 1)),
          requestId: 'future',
        ),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 400),
        ),
      );
      await admin.deleteBoxCareEvent(current);
      expect(await admin.boxCareEvents(box), isEmpty);
      await admin.saveBoxCareEvent(
        box,
        type: BoxCareEventType.waterChange,
        occurredAt: at,
        requestId: 'water',
      );
      await BoxRepository(
        database,
      ).archiveBox(boxId: box, reason: BoxArchiveReason.stored, archivedAt: at);
      expect(await keeper.boxCareEvents(box), hasLength(1));
      await expectLater(
        keeper.saveBoxCareEvent(
          box,
          type: BoxCareEventType.cleaning,
          occurredAt: at,
          requestId: 'archived',
        ),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 409),
        ),
      );
      final audit = await CollectionAuditLog(database).read(
        AuditQuery.parse(Uri.parse('http://127.0.0.1/api/v1/audit?limit=100')),
      );
      expect(audit.any((e) => e['action'] == 'boxCareEvent.create'), true);
      expect(jsonEncode(audit), isNot(contains('Private care notes')));
    } finally {
      admin?.close();
      keeper?.close();
      anonymous.close();
      if (admin == null) adminHttp.close();
      if (keeper == null) keeperHttp.close();
      await server?.close(force: true);
      await database?.close();
      accounts?.close();
      await directory.delete(recursive: true);
    }
  });
}
