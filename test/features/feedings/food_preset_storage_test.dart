import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/food_preset_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/feedings/domain/feeding_field_values.dart';
import 'package:terramanager/features/feedings/domain/food_preset.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/shared_server/backups/application/shared_portable_backups.dart';

void main() {
  for (final shared in [false, true]) {
    test(
      'typed values and archived presets round-trip; shared=$shared',
      () async {
        final source = AppDatabase.test(NativeDatabase.memory());
        final target = AppDatabase.test(NativeDatabase.memory());
        addTearDown(source.close);
        addTearDown(target.close);
        final box = await BoxRepository(source).createBoxWithGeneratedQrId();
        final animals = [
          for (final name in ['First', 'Second'])
            await AnimalRepository(source).createAnimal(
              boxId: box,
              commonName: name,
              latinName: 'Species',
              tempMin: 20,
              tempMax: 28,
              humidityMin: 40,
              humidityMax: 60,
            ),
        ];
        const type = CustomFieldTemplate(
          id: '11111111-1111-4111-8111-111111111111',
          target: CustomFieldTarget.feeding,
          type: CustomFieldType.text,
          label: 'Food',
        );
        const quantity = CustomFieldTemplate(
          id: '22222222-2222-4222-8222-222222222222',
          target: CustomFieldTarget.feeding,
          type: CustomFieldType.number,
          label: 'Quantity',
        );
        final templates = CustomFieldRepository(source);
        await templates.create(type);
        await templates.create(quantity);
        final presets = FoodPresetRepository(source);
        final preset = await presets.save(
          FoodPreset(
            id: '33333333-3333-4333-8333-333333333333',
            name: '  Crickets  ',
            defaults: {type.id: 'Cricket', quantity.id: 2},
          ),
          creating: true,
        );
        expect(preset.name, 'Crickets');
        expect(preset.defaults[quantity.id], 2.0);
        final feedings = FeedingRepository(source);
        final fedAt = DateTime.utc(2026, 11, 12);
        final ids = await feedings.addFeedings(
          animalIds: animals,
          fedAt: fedAt,
          customFields: CustomFieldPatch(
            expectedRevision: null,
            updates: [
              (
                id: type.id,
                templateRevision: 1,
                value: preset.defaults[type.id],
              ),
              (id: quantity.id, templateRevision: 1, value: 3),
            ],
          ),
        );
        final old = await feedings.addFeeding(
          animals.first,
          fedAt,
          notes: 'Original note',
        );
        final archived = await presets.save(
          FoodPreset(
            id: preset.id,
            name: 'Large crickets',
            archived: true,
            revision: preset.revision,
            defaults: {type.id: 'Cricket', quantity.id: 8},
          ),
          creating: false,
        );
        await expectLater(
          presets.save(preset, creating: false),
          throwsStateError,
        );
        final saved = (await feedings.getFeedingById(ids.first))!;
        final snapshots = decodeFeedingFieldValues(saved.customFieldsJson);
        expect(snapshots.map((value) => value.value), ['Cricket', 3]);
        final edit = CustomFieldPatch(
          expectedRevision: feedingFieldRevision(snapshots),
          updates: [(id: quantity.id, templateRevision: 1, value: 4)],
        );
        expect(
          await feedings.updateFeeding(
            feedingId: saved.id,
            fedAt: fedAt,
            customFields: edit,
          ),
          isTrue,
        );
        await expectLater(
          feedings.updateFeeding(
            feedingId: saved.id,
            fedAt: fedAt,
            customFields: edit,
          ),
          throwsA(isA<CustomFieldConflict>()),
        );
        expect(
          await feedings.updateFeeding(
            feedingId: saved.id,
            fedAt: fedAt,
            notes: 'Edited note',
          ),
          isTrue,
        );

        if (shared) {
          final result = await SharedPortableBackups(source).export();
          final restore = SharedPortableBackups(target);
          await restore.restore(restore.validate(result.bytes));
        } else {
          final result = await BackupExportService(source).createBackup(
            appVersion: 'test',
            themeMode: ThemeMode.system,
            accent: AppAccent.green,
          );
          await PortableBackupDatabaseRestorer(target)
              .restore(BackupValidationService().validate(result.bytes));
        }
        expect(
          (await FoodPresetRepository(target).all()).single.toJson(),
          archived.toJson(),
        );
        expect(
          await CustomFieldRepository(target)
              .templates(CustomFieldTarget.feeding),
          hasLength(2),
        );
        final restored = FeedingRepository(target);
        final first = (await restored.getFeedingById(ids.first))!;
        expect(first.notes, 'Edited note');
        expect(decodeFeedingFieldValues(first.customFieldsJson).last.value, 4);
        final second = (await restored.getFeedingById(ids.last))!;
        expect(second.notes, isNull);
        expect(decodeFeedingFieldValues(second.customFieldsJson).last.value, 3);
        final legacy = (await restored.getFeedingById(old))!;
        expect(legacy.notes, 'Original note');
        expect(legacy.customFieldsJson, isNull);
      },
    );
  }
}
