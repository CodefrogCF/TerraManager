import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/food_preset_repository.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/feedings/domain/feeding_field_values.dart';

import 'generated/schema_v22.dart' as v22;
import 'generated/schema_v24.dart' as v24;

void main() {
  test('v24 feeding templates, recorded values and presets survive v25', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tm-feeding-options-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/collection.sqlite');
    const field = '11111111-1111-4111-8111-111111111111';
    const preset = '22222222-2222-4222-8222-222222222222';
    final old = v24.DatabaseAtV24(NativeDatabase(file));
    try {
      await old.customStatement(
        "INSERT INTO animals(id, common_name, latin_name, temp_min, temp_max, humidity_min, humidity_max) VALUES (1, 'Existing', 'Species', 20, 28, 40, 60)",
      );
      await old.customStatement(
        "INSERT INTO custom_field_templates(id, target, type, label, label_key) VALUES (?, 'feeding', 'number', 'Weight', 'weight')",
        [field],
      );
      await old.customStatement(
        "INSERT INTO feeding_events(id, animal_id, fed_at, custom_fields_json) VALUES (1, 1, 1700000000, ?)",
        ['[{"templateId":"$field","label":"Weight","type":"number","value":2.5}]'],
      );
      await old.customStatement(
        "INSERT INTO food_presets(id, name, name_key, defaults_json) VALUES (?, 'Existing', 'existing', ?)",
        [preset, '{"$field":2.5}'],
      );
    } finally {
      await old.close();
    }

    final database = AppDatabase.test(NativeDatabase(file));
    addTearDown(database.close);
    final fields = CustomFieldRepository(database);
    final original = (await fields.templates(CustomFieldTarget.feeding)).single;
    expect(original.type, CustomFieldType.number);
    expect(original.options, isEmpty);
    final event = (await FeedingRepository(database).getFeedingById(1))!;
    expect(decodeFeedingFieldValues(event.customFieldsJson).single.value, 2.5);
    expect(
      (await FoodPresetRepository(database).all()).single.defaults[field],
      2.5,
    );
    final added = await fields.create(
      const CustomFieldTemplate(
        id: '33333333-3333-4333-8333-333333333333',
        target: CustomFieldTarget.feeding,
        type: CustomFieldType.choice,
        label: 'Size',
        options: ['micro', 'XL'],
      ),
    );
    expect(added.options, ['micro', 'XL']);
  });

  test(
    'v22 retains Feedings and existing custom-field relationships',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tm-feeding-fields-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/collection.sqlite');
      final old = v22.DatabaseAtV22(NativeDatabase(file));
      try {
        await old.customStatement(
          "INSERT INTO boxes(id, qr_id) VALUES (1, 'legacy-box')",
        );
        await old.customStatement(
          "INSERT INTO animals(id, box_id, common_name, latin_name, temp_min, temp_max, humidity_min, humidity_max) VALUES (1, 1, 'Existing', 'Species', 20, 28, 40, 60)",
        );
        await old.customStatement(
          "INSERT INTO feeding_events(id, animal_id, fed_at, notes) VALUES (1, 1, 1700000000, 'Mouse')",
        );
        await old.customStatement(
          "INSERT INTO custom_field_templates(id, target, type, label, label_key) VALUES ('11111111-1111-4111-8111-111111111111', 'animal', 'text', 'Existing', 'existing')",
        );
        await old.customStatement(
          "INSERT INTO custom_field_values(template_id, animal_id, value_json) VALUES ('11111111-1111-4111-8111-111111111111', 1, '\"Value\"')",
        );
      } finally {
        await old.close();
      }
      final database = AppDatabase.test(NativeDatabase(file));
      addTearDown(database.close);
      final legacy = (await FeedingRepository(database).getFeedingById(1))!;
      expect(legacy.notes, 'Mouse');
      expect(legacy.customFieldsJson, isNull);
      expect(await FoodPresetRepository(database).all(), isEmpty);
      final fields = CustomFieldRepository(database);
      final existing = await fields.snapshot(CustomFieldTarget.animal, 1);
      expect(existing.values.single.value, 'Value');
      await fields.create(
        const CustomFieldTemplate(
          id: '22222222-2222-4222-8222-222222222222',
          target: CustomFieldTarget.feeding,
          type: CustomFieldType.text,
          label: 'Food',
        ),
      );
      expect(await fields.templates(CustomFieldTarget.feeding), hasLength(1));
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
