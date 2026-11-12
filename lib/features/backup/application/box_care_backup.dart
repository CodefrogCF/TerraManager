import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/box_care_reminder_repository.dart';
import '../../boxes/domain/box_care_reminder.dart';
import '../domain/backup_data.dart';

Future<({List<BackupBoxCareEvent> events, List<BoxCareReminder> reminders})>
readBoxCareBackup(AppDatabase database, int boxId) =>
    database.transaction(() async {
      final events = await (database.select(
        database.boxCareEvents,
      )..where((row) => row.boxId.equals(boxId))).get();
      return (
        events: [
          for (final event in events)
            BackupBoxCareEvent(
              id: event.id,
              type: event.type.name,
              customTypeId: event.customTypeId,
              occurredAt: event.occurredAt,
              notes: event.notes,
              requestId: event.requestId,
              revision: event.revision,
              createdAt: event.createdAt,
              updatedAt: event.updatedAt,
            ),
        ],
        reminders: await BoxCareReminderRepository(database).forBox(boxId),
      );
    });
