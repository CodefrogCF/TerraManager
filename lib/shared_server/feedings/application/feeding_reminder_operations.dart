import 'dart:async';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/feedings/application/feeding_reminder_service.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

class FeedingReminderOperations {
  const FeedingReminderOperations(this.database);
  final AppDatabase database;
  Future<ApiReply> list() async {
    final states = await FeedingReminderService(database).getReminderStates();
    return ApiReply(200, {
      'reminders': [
        for (final state in states)
          {
            'animalId': state.animalId,
            'dueAt': state.dueAt.toUtc().toIso8601String(),
            'latestFeedingAt': state.latestFeedingAt?.toUtc().toIso8601String(),
          },
      ],
    });
  }
}
