import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums/box_status.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/database/repositories/box_care_repository.dart';
import '../../../core/database/repositories/care_event_type_repository.dart';
import 'pages/box_care_history_page.dart';
import 'standalone_care_event_types.dart';

Future<void> openStandaloneBoxCareHistory(
  BuildContext context, {
  required AppDatabase database,
  required int boxId,
  required String label,
}) async {
  final repository = BoxCareRepository(database);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => BoxCareHistoryPage(
        boxLabel: label,
        manageTypes: () => openStandaloneCareEventTypes(context, database),
        load: () async {
          final box = await BoxRepository(database).getBoxById(boxId);
          if (box == null) throw StateError('Box no longer exists');
          return BoxCareHistoryData(
            entries: await repository.history(boxId),
            active: box.status == BoxStatus.active,
            types: await CareEventTypeRepository(database).all(),
          );
        },
        updates: database.tableUpdates().where(
          (updates) => updates.any(
            (update) => {
              database.boxCareEvents.actualTableName,
              database.boxes.actualTableName,
              database.careEventTypes.actualTableName,
            }.contains(update.table),
          ),
        ),
        save:
            ({
              existing,
              required type,
              customTypeId,
              required occurredAt,
              notes,
              required requestId,
            }) async {
              if (existing == null) {
                await repository.add(
                  boxId: boxId,
                  type: type,
                  customTypeId: customTypeId,
                  occurredAt: occurredAt,
                  notes: notes,
                  requestId: requestId,
                );
                return true;
              }
              return repository.update(
                boxId: boxId,
                id: existing.id,
                expectedRevision: existing.revision,
                expectedRequestId: existing.requestId,
                type: type,
                customTypeId: customTypeId,
                occurredAt: occurredAt,
                notes: notes,
              );
            },
        delete: (entry) => repository.delete(
          boxId: boxId,
          id: entry.id,
          expectedRevision: entry.revision,
          expectedRequestId: entry.requestId,
        ),
      ),
    ),
  );
}
