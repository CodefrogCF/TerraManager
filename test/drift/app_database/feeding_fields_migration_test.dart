import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/food_preset_repository.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';

import 'generated/schema_v22.dart' as v22;

void main() {
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
