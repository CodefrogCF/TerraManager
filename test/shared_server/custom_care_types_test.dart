import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/app/shared_server_api.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/audit/application/audit_query.dart';

import 'box_care_events_test.dart' show CookieClient;

void main() {
  test('authenticated custom types synchronize metadata, reject stale changes and preserve archived history', () async {
    final dir = await Directory.systemTemp.createTemp('tm240-http-');
    AccountStore? accounts;
    AppDatabase? db;
    HttpServer? server;
    final adminHttp = CookieClient(),
        keeperHttp = CookieClient(),
        anonymous = http.Client();
    SharedApiClient? admin, keeper;
    try {
      accounts = await AccountStore.open(File('${dir.path}/accounts.sqlite'));
      db = await openServerDatabase(File('${dir.path}/collection.sqlite'));
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
        database: db,
        accounts: accounts,
        publicUrl: Uri.parse('http://127.0.0.1'),
      );
      server = await service.serve();
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      admin = SharedApiClient(origin, adminHttp);
      keeper = SharedApiClient(origin, keeperHttp);
      await admin.login('admin', 'secure admin password 123');
      await keeper.login('keeper', 'secure keeper password 123');
      final path = origin.resolve('/api/v1/care-event-types');
      expect((await anonymous.get(path)).statusCode, 401);
      expect(
        (await keeperHttp.post(
          path,
          body: '{}',
          headers: {'Content-Type': 'application/json'},
        )).statusCode,
        403,
      );
      const first = '12345678-1234-4123-8123-123456789abc',
          second = '22345678-1234-4123-8123-123456789abc';
      final initial = service.changes.revision;
      final script = await keeperHttp.post(
        path,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': keeper.session!.csrfToken,
        },
        body: jsonEncode({
          'id': first,
          'label': 'Ventilation',
          'script': 'anything',
        }),
      );
      expect(script.statusCode, 400);
      expect(service.changes.revision, initial);
      await expectLater(
        keeper.createCareEventType(first, '\nInvalid label'),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 400),
        ),
      );
      final cursor = (await admin.queryChanges()).cursor;
      await keeper.createCareEventType(first, 'Private ventilation label');
      final afterCreate = service.changes.revision;
      final delta = await admin.queryChanges(since: cursor);
      final resources =
          ((delta.body!['changes'] as List).single as Map)['resources'] as Map;
      expect(resources.containsKey('careEventTypes'), true);
      expect(resources['careEventTypes'], isNull);
      expect(resources.containsKey('collection'), false);
      expect(
        jsonEncode(delta.body),
        isNot(contains('Private ventilation label')),
      );
      await keeper.createCareEventType(first, 'Private ventilation label');
      expect(service.changes.revision, afterCreate);
      expect(await admin.careEventTypes(), hasLength(1));
      await expectLater(
        keeper.createCareEventType(second, 'private VENTILATION label'),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 409),
        ),
      );
      final original = (await admin.careEventTypes()).single;
      final box = (await admin.createBox({'name': 'Care Box'}))['id'] as int;
      await keeper.saveBoxCareEvent(
        box,
        type: BoxCareEventType.custom,
        customTypeId: first,
        occurredAt: DateTime.utc(2026),
        requestId: 'custom-history',
      );
      await keeper.updateCareEventType(
        original,
        label: 'Renamed ventilation',
        archived: true,
      );
      await expectLater(
        admin.updateCareEventType(
          original,
          label: 'Stale rename',
          archived: false,
        ),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 409),
        ),
      );
      final event = (await admin.boxCareEvents(box)).single;
      expect(event.customTypeId, first);
      expect(
        (await admin.careEventTypes()).single.label,
        'Renamed ventilation',
      );
      await expectLater(
        keeper.saveBoxCareEvent(
          box,
          type: BoxCareEventType.custom,
          customTypeId: first,
          occurredAt: DateTime.utc(2026),
          requestId: 'archived-new',
        ),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 400),
        ),
      );
      await keeper.saveBoxCareEvent(
        box,
        existing: event,
        type: BoxCareEventType.custom,
        customTypeId: first,
        occurredAt: event.occurredAt,
        notes: 'Updated after archive',
        requestId: 'unused',
      );
      await keeper.createCareEventType(second, 'Lamp check');
      final order = await admin.careEventTypes();
      await keeper.reorderCareEventTypes(order.reversed.toList());
      expect((await admin.careEventTypes()).map((t) => t.id), [second, first]);
      final beforeStale = service.changes.revision;
      await expectLater(
        admin.reorderCareEventTypes(order),
        throwsA(
          isA<SharedApiException>().having((e) => e.status, 'status', 409),
        ),
      );
      expect(service.changes.revision, beforeStale);
      final deletion = await keeperHttp.delete(
        origin.resolve('/api/v1/care-event-types/$first'),
        headers: {'X-CSRF-Token': keeper.session!.csrfToken},
      );
      expect(deletion.statusCode, 403);
      expect(
        (await admin.boxCareEvents(box)).single.notes,
        'Updated after archive',
      );
      final audit = await CollectionAuditLog(db).read(
        AuditQuery.parse(Uri.parse('http://localhost/api/v1/audit?limit=100')),
      );
      expect(audit.any((e) => e['action'] == 'careEventType.create'), true);
      expect(audit.any((e) => e['action'] == 'careEventType.reorder'), true);
      expect(jsonEncode(audit), isNot(contains('Private ventilation label')));
    } finally {
      admin?.close();
      keeper?.close();
      anonymous.close();
      if (admin == null) adminHttp.close();
      if (keeper == null) keeperHttp.close();
      await server?.close(force: true);
      await db?.close();
      accounts?.close();
      await dir.delete(recursive: true);
    }
  });
}
