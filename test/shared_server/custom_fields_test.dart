import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/feedings/domain/feeding_field_values.dart';
import 'package:terramanager/features/feedings/domain/food_preset.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/app/shared_server_api.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

import 'box_care_events_test.dart' show CookieClient;

void main() {
  test('authenticated fields enforce CSRF, revisions, atomic profile saves and targeted notifications', () async {
    final dir = await Directory.systemTemp.createTemp('tm241-http-');
    AccountStore? accounts;
    AppDatabase? db;
    HttpServer? server;
    SharedApiClient? api;
    final transport = CookieClient();
    final anonymous = http.Client();
    try {
      accounts = await AccountStore.open(File('${dir.path}/accounts.sqlite'));
      db = await openServerDatabase(File('${dir.path}/data.sqlite'));
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
      api = SharedApiClient(origin, transport);
      await api.login('keeper', 'secure keeper password 123');
      final path = origin.resolve('/api/v1/custom-field-templates');
      expect((await anonymous.get(path)).statusCode, 401);
      expect(
        (await transport.post(
          path,
          body: '{}',
          headers: {'Content-Type': 'application/json'},
        )).statusCode,
        403,
      );
      const t = CustomFieldTemplate(
        id: '12345678-1234-4123-8123-123456789abc',
        target: CustomFieldTarget.box,
        type: CustomFieldType.boolean,
        label: 'Private field',
      );
      final cursor = (await api.queryChanges()).cursor;
      await api.saveCustomFieldTemplate(t, creating: true);
      final delta = (await api.queryChanges(since: cursor)).body!;
      expect(jsonEncode(delta), contains('customFieldTemplates'));
      expect(jsonEncode(delta), isNot(contains('Private field')));
      final box = await api.createBox({
        'name': 'Initial',
        'customFields': const CustomFieldPatch(
          expectedRevision: null,
          updates: [
            (
              id: '12345678-1234-4123-8123-123456789abc',
              templateRevision: 1,
              value: false,
            ),
          ],
        ).toJson(),
      });
      final id = box['id'] as int;
      final state = await api.customFields(CustomFieldTarget.box, id);
      expect(state.value(t.id), false);
      final patch = CustomFieldPatch(
        expectedRevision: state.revision,
        updates: [(id: t.id, templateRevision: 1, value: true)],
      );
      await api.saveCustomFieldTemplate(
        const CustomFieldTemplate(
          id: '12345678-1234-4123-8123-123456789abc',
          target: CustomFieldTarget.box,
          type: CustomFieldType.boolean,
          label: 'Renamed',
        ),
        creating: false,
      );
      await expectLater(
        api.updateBox(id, {
          'name': 'Must not commit',
          'customFields': patch.toJson(),
        }, box['revision'] as String),
        throwsA(
          isA<SharedApiException>().having(
            (e) => e.code,
            'code',
            'stale_record',
          ),
        ),
      );
      expect((await api.box(id))['name'], 'Initial');
      expect(
        (await api.customFields(CustomFieldTarget.box, id)).value(t.id),
        false,
      );
      final current = await api.customFields(CustomFieldTarget.box, id);
      final before = (await api.queryChanges()).cursor;
      await api.updateBox(id, {
        'name': 'Updated',
        'customFields': CustomFieldPatch(
          expectedRevision: current.revision,
          updates: [(id: t.id, templateRevision: 2, value: true)],
        ).toJson(),
      }, box['revision'] as String);
      expect(
        (await api.customFields(CustomFieldTarget.box, id)).value(t.id),
        true,
      );
      expect(
        jsonEncode((await api.queryChanges(since: before)).body),
        contains('boxCustomFields'),
      );

      final presetPath = origin.resolve('/api/v1/food-presets');
      expect((await anonymous.get(presetPath)).statusCode, 401);
      expect(
        (await transport.post(
          presetPath,
          body: '{}',
          headers: {'Content-Type': 'application/json'},
        )).statusCode,
        403,
      );
      const food = CustomFieldTemplate(
        id: '22222222-2222-4222-8222-222222222222',
        target: CustomFieldTarget.feeding,
        type: CustomFieldType.integer,
        label: 'Quantity',
      );
      const prey = CustomFieldTemplate(
        id: '55555555-5555-4555-8555-555555555555',
        target: CustomFieldTarget.feeding,
        type: CustomFieldType.choice,
        label: 'Food',
        options: ['Cricket', 'Locust'],
      );
      await api.saveCustomFieldTemplate(food, creating: true);
      await api.saveCustomFieldTemplate(prey, creating: true);
      expect(
        (await api.customFieldTemplates(CustomFieldTarget.feeding))
            .singleWhere((field) => field.id == prey.id)
            .options,
        prey.options,
      );
      final presetCursor = (await api.queryChanges()).cursor;
      await api.saveFoodPreset(
        FoodPreset(
          id: '33333333-3333-4333-8333-333333333333',
          name: 'Crickets',
          defaults: {food.id: 2, prey.id: 'Cricket'},
        ),
        creating: true,
      );
      final preset = (await api.foodPresets()).single;
      expect(preset.defaults[food.id], 2);
      final presetDelta = jsonEncode(
        (await api.queryChanges(since: presetCursor)).body,
      );
      expect(presetDelta, contains('foodPresets'));
      expect(presetDelta, isNot(contains('Crickets')));
      final animalIds = [
        for (final name in ['First', 'Second'])
          await AnimalRepository(db).createAnimal(
            boxId: id,
            commonName: name,
            latinName: 'Species',
            tempMin: 20,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 60,
          ),
      ];
      final fedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      CustomFieldPatch fields(Object value, [String option = 'Cricket']) =>
          CustomFieldPatch(
            expectedRevision: null,
            updates: [
              (id: food.id, templateRevision: 1, value: value),
              (id: prey.id, templateRevision: 1, value: option),
            ],
          );
      for (final invalid in [fields(1.5), fields(3, 'Unavailable')]) {
        await expectLater(
          api.createFeedings(
            animalIds: animalIds,
            fedAt: fedAt,
            notes: null,
            boxId: id,
            customFields: invalid,
          ),
          throwsA(
            isA<SharedApiException>().having((e) => e.status, 'status', 400),
          ),
        );
      }
      expect(await api.feedings(animalIds.first), isEmpty);
      Future<List<Map<String, dynamic>>> create() => api!.createFeedings(
        animalIds: animalIds,
        fedAt: fedAt,
        notes: null,
        boxId: id,
        requestId: '44444444-4444-4444-8444-444444444444',
        customFields: fields(3),
      );
      final saved = await create();
      expect(await create(), saved);
      await api.saveFoodPreset(
        FoodPreset(
          id: preset.id,
          name: 'Archived crickets',
          defaults: {food.id: 8},
          archived: true,
          revision: preset.revision,
        ),
        creating: false,
      );
      expect((await api.foodPresets()).single.archived, isTrue);
      for (final animal in animalIds) {
        final entry = (await api.feedings(animal)).single;
        expect(entry['notes'], isNull);
        final values = readFeedingFieldValues(entry['customFields']);
        expect(values.map((field) => field.value), [3, 'Cricket']);
        expect(values.first.value, isA<int>());
      }
    } finally {
      api?.close();
      transport.close();
      anonymous.close();
      await server?.close(force: true);
      await db?.close();
      accounts?.close();
      await dir.delete(recursive: true);
    }
  });
}
