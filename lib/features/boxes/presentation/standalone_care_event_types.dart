import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/care_event_type_repository.dart';
import 'pages/care_event_types_page.dart';

Future<void> openStandaloneCareEventTypes(
  BuildContext context,
  AppDatabase database,
) async {
  final repository = CareEventTypeRepository(database);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CareEventTypesPage(
        load: repository.all,
        create: (id, label) async {
          await repository.create(id, label);
        },
        update: (type, label, archived) async {
          await repository.update(
            id: type.id,
            expectedRevision: type.revision,
            label: label,
            archived: archived,
          );
        },
        reorder: (types) => repository.reorder(
          types.map((t) => (id: t.id, revision: t.revision)).toList(),
        ),
        updates: database.tableUpdates(
          TableUpdateQuery.onTable(database.careEventTypes),
        ),
      ),
    ),
  );
}
