import '../tables/custom_fields.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../features/custom_fields/domain/custom_field.dart';
import '../app_database.dart';
import '../enums/animal_status.dart';
import '../enums/box_status.dart';

class CustomFieldRepository {
  const CustomFieldRepository(this.database);
  final AppDatabase database;
  static CustomFieldTemplate definition(CustomFieldTemplateRow t) =>
      CustomFieldTemplate(
        id: t.id,
        target: CustomFieldTarget.values.byName(t.target),
        type: CustomFieldType.values.byName(t.type),
        label: t.label,
        hidden: t.hidden,
        archived: t.archived,
        revision: t.revision,
      );
  Future<List<CustomFieldTemplate>> templates([
    CustomFieldTarget? target,
  ]) async {
    final query = database.select(database.customFieldTemplates)
      ..orderBy([
        (t) => OrderingTerm.asc(t.labelKey),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (target != null) query.where((t) => t.target.equals(target.name));
    return (await query.get()).map(definition).toList();
  }

  Future<void> _unique(CustomFieldTemplate t) async {
    final rows =
        await (database.select(database.customFieldTemplates)..where(
              (r) =>
                  r.target.equals(t.target.name) &
                  r.labelKey.equals(t.label.toLowerCase()),
            ))
            .get();
    if (rows.any((r) => r.id != t.id)) {
      throw ArgumentError('Duplicate field label.');
    }
  }

  Future<CustomFieldTemplate> create(CustomFieldTemplate template) =>
      database.transaction(() async {
        final t = CustomFieldTemplate.fromJson(template.toJson());
        final existing = await (database.select(
          database.customFieldTemplates,
        )..where((r) => r.id.equals(t.id))).getSingleOrNull();
        if (existing != null) {
          if (!sameFieldValue(definition(existing).toJson(), t.toJson())) {
            throw CustomFieldConflict();
          }
          return definition(existing);
        }
        if (t.revision != 1) throw ArgumentError('Invalid initial revision.');
        await _unique(t);
        await database
            .into(database.customFieldTemplates)
            .insert(
              CustomFieldTemplatesCompanion.insert(
                id: t.id,
                target: t.target.name,
                type: t.type.name,
                label: t.label,
                labelKey: t.label.toLowerCase(),
                hidden: Value(t.hidden),
                archived: Value(t.archived),
              ),
            );
        return t;
      });
  Future<CustomFieldTemplate> update(CustomFieldTemplate template) =>
      database.transaction(() async {
        final t = CustomFieldTemplate.fromJson(template.toJson());
        final row = await (database.select(
          database.customFieldTemplates,
        )..where((r) => r.id.equals(t.id))).getSingleOrNull();
        if (row == null ||
            row.revision != t.revision ||
            row.target != t.target.name ||
            row.type != t.type.name) {
          throw CustomFieldConflict();
        }
        await _unique(t);
        await (database.update(
          database.customFieldTemplates,
        )..where((r) => r.id.equals(t.id))).write(
          CustomFieldTemplatesCompanion(
            label: Value(t.label),
            labelKey: Value(t.label.toLowerCase()),
            hidden: Value(t.hidden),
            archived: Value(t.archived),
            revision: Value(t.revision + 1),
          ),
        );
        return (await templates(t.target)).firstWhere((r) => r.id == t.id);
      });
  Expression<bool> _owner(
    CustomFieldValues t,
    CustomFieldTarget target,
    int id,
  ) => target == CustomFieldTarget.animal
      ? t.animalId.equals(id)
      : t.boxId.equals(id);
  Future<List<CustomFieldValueRow>> rows(CustomFieldTarget target, int id) =>
      (database.select(database.customFieldValues)
            ..where((r) => _owner(r, target, id))
            ..orderBy([(r) => OrderingTerm.asc(r.templateId)]))
          .get();
  Future<CustomFieldsSnapshot> snapshot(CustomFieldTarget target, [int? id]) =>
      database.transaction(() async {
        final definitions = await templates(target);
        if (id == null) {
          return CustomFieldsSnapshot(templates: definitions, values: const []);
        }
        bool active;
        String identity;
        if (target == CustomFieldTarget.animal) {
          final r = await (database.select(
            database.animals,
          )..where((r) => r.id.equals(id))).getSingleOrNull();
          if (r == null) throw StateError('Animal missing.');
          active = r.status == AnimalStatus.active;
          identity = '${r.id}:${r.createdAt.toIso8601String()}';
        } else {
          final r = await (database.select(
            database.boxes,
          )..where((r) => r.id.equals(id))).getSingleOrNull();
          if (r == null) throw StateError('Box missing.');
          active = r.status == BoxStatus.active;
          identity = '${r.id}:${r.createdAt.toIso8601String()}:${r.qrId}';
        }
        final values = (await rows(target, id))
            .map(
              (r) => CustomFieldValue(
                r.templateId,
                jsonDecode(r.valueJson),
                revision: r.revision,
              ),
            )
            .toList();
        final revision = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  target.name,
                  identity,
                  active,
                  definitions.map((r) => r.toJson()).toList(),
                  values.map((r) => r.toJson()).toList(),
                ]),
              ),
            )
            .toString();
        return CustomFieldsSnapshot(
          templates: definitions,
          values: values,
          revision: revision,
          active: active,
        );
      });
  Future<void> save(
    CustomFieldTarget target,
    int id,
    CustomFieldPatch patch, {
    bool creating = false,
  }) => database.transaction(() async {
    final state = await snapshot(target, id);
    if (!state.active ||
        (creating
            ? patch.expectedRevision != null
            : patch.expectedRevision != state.revision)) {
      throw CustomFieldConflict();
    }
    final updates = CustomFieldPatch.fromJson(patch.toJson()).updates;
    for (final u in updates) {
      final t = state.templates.where((t) => t.id == u.id).firstOrNull;
      if (t == null ||
          t.hidden ||
          t.archived ||
          t.revision != u.templateRevision) {
        throw CustomFieldConflict();
      }
      final value = t.validate(u.value);
      final old = (await rows(
        target,
        id,
      )).where((v) => v.templateId == t.id).firstOrNull;
      if (old != null && sameFieldValue(jsonDecode(old.valueJson), value)) {
        continue;
      }
      if (old == null) {
        if (value == null) continue;
        await database
            .into(database.customFieldValues)
            .insert(
              CustomFieldValuesCompanion.insert(
                templateId: t.id,
                animalId: Value(target == CustomFieldTarget.animal ? id : null),
                boxId: Value(target == CustomFieldTarget.box ? id : null),
                valueJson: jsonEncode(value),
              ),
            );
      } else {
        await (database.update(
          database.customFieldValues,
        )..where((r) => r.id.equals(old.id))).write(
          CustomFieldValuesCompanion(
            valueJson: Value(jsonEncode(value)),
            revision: Value(old.revision + 1),
          ),
        );
      }
    }
  });
  Future<void> copy(
    CustomFieldTarget target,
    int source,
    int destination,
  ) async {
    for (final r in await rows(target, source)) {
      await database
          .into(database.customFieldValues)
          .insert(
            CustomFieldValuesCompanion.insert(
              templateId: r.templateId,
              animalId: Value(
                target == CustomFieldTarget.animal ? destination : null,
              ),
              boxId: Value(
                target == CustomFieldTarget.box ? destination : null,
              ),
              valueJson: r.valueJson,
            ),
          );
    }
  }
}
