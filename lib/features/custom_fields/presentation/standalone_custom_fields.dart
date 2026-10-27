import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';

import 'custom_fields.dart';

CustomFieldAccess standaloneCustomFields(
  AppDatabase db,
  CustomFieldTarget target, [
  int? id,
]) {
  final repo = CustomFieldRepository(db);
  return CustomFieldAccess(
    target: target,
    load: () => repo.snapshot(target, id),
    templates: () => repo.templates(target),
    saveTemplate: (t, {required creating}) async {
      if (creating) {
        await repo.create(t);
      } else {
        await repo.update(t);
      }
    },
  );
}

class StandaloneCustomFieldsSection extends StatelessWidget {
  const StandaloneCustomFieldsSection({
    super.key,
    required this.database,
    required this.target,
    required this.id,
  });
  final AppDatabase database;
  final CustomFieldTarget target;
  final int id;
  @override
  Widget build(BuildContext context) => CustomFieldsSection(
    key: ValueKey('${target.name}:$id'),
    access: standaloneCustomFields(database, target, id),
    updates: database.tableUpdates(
      TableUpdateQuery.onAllTables([
        database.customFieldTemplates,
        database.customFieldValues,
        database.animals,
        database.boxes,
      ]),
    ),
  );
}
