import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/feedings/domain/food_preset.dart';

import '../app_database.dart';
import 'custom_field_repository.dart';

class FoodPresetRepository {
  const FoodPresetRepository(this.database);
  final AppDatabase database;

  static FoodPreset definition(FoodPresetRow row) => FoodPreset.fromJson({
    'id': row.id,
    'name': row.name,
    'defaults': jsonDecode(row.defaultsJson),
    'archived': row.archived,
    'revision': row.revision,
  });

  Future<List<FoodPreset>> all() async =>
      (await (database.select(
            database.foodPresets,
          )..orderBy([(row) => OrderingTerm.asc(row.nameKey)])).get())
          .map(definition)
          .toList();

  Future<FoodPreset> save(FoodPreset draft, {required bool creating}) =>
      database.transaction(() async {
        final preset = FoodPreset.fromJson(draft.toJson());
        final existing = await (database.select(
          database.foodPresets,
        )..where((row) => row.id.equals(preset.id))).getSingleOrNull();
        final defaults = preset.validatedDefaults(
          await CustomFieldRepository(database)
              .templates(CustomFieldTarget.feeding),
          previous: existing == null ? null : definition(existing),
        );
        if (creating) {
          if (preset.revision != 1) {
            throw ArgumentError('Invalid initial revision.');
          }
          if (existing != null) {
            if (existing.revision == 1 &&
                existing.name == preset.name &&
                existing.archived == preset.archived &&
                existing.defaultsJson == jsonEncode(defaults)) {
              return definition(existing);
            }
            throw StateError('Food preset already exists.');
          }
        } else if (existing?.revision != preset.revision) {
          throw StateError('Food preset changed. Reload before saving.');
        }
        final saved = FoodPreset(
          id: preset.id,
          name: preset.name,
          defaults: defaults,
          archived: preset.archived,
          revision: creating ? 1 : preset.revision + 1,
        );
        await database
            .into(database.foodPresets)
            .insertOnConflictUpdate(
              FoodPresetsCompanion.insert(
                id: saved.id,
                name: saved.name,
                nameKey: saved.name.toLowerCase(),
                defaultsJson: jsonEncode(saved.defaults),
                archived: Value(saved.archived),
                revision: Value(saved.revision),
              ),
            );
        return saved;
      });
}
