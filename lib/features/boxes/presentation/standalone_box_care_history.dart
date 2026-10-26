import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums/box_status.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/database/repositories/box_care_repository.dart';
import 'pages/box_care_history_page.dart';

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
        load: () async {
          final box = await BoxRepository(database).getBoxById(boxId);
          if (box == null) throw StateError('Box no longer exists');
          return BoxCareHistoryData(
            entries: await repository.history(boxId),
            active: box.status == BoxStatus.active,
          );
        },
        updates: database.tableUpdates().where(
          (updates) => updates.any(
            (update) => {
              database.boxCareEvents.actualTableName,
              database.boxCareEventAttachments.actualTableName,
              database.boxes.actualTableName,
            }.contains(update.table),
          ),
        ),
        save:
            ({
              existing,
              required type,
              required occurredAt,
              notes,
              required mediaIds,
              required requestId,
            }) async {
              if (existing == null) {
                await repository.add(
                  boxId: boxId,
                  type: type,
                  occurredAt: occurredAt,
                  notes: notes,
                  mediaIds: mediaIds,
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
                occurredAt: occurredAt,
                notes: notes,
                mediaIds: mediaIds,
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
