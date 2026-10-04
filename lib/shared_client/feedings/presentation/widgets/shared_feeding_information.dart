import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/features/feedings/domain/feeding_weekday_schedule.dart';
import 'package:terramanager/features/feedings/presentation/widgets/feeding_due_date_label.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_date_time_label.dart';

class SharedFeedingInformation extends StatelessWidget {
  const SharedFeedingInformation({
    super.key,
    required this.entries,
    required this.animal,
    required this.due,
    required this.onRetry,
    required this.onHistory,
  });
  final Future<List<Map<String, dynamic>>> entries;
  final Map<String, dynamic> animal;
  final bool due;
  final VoidCallback onRetry;
  final void Function(bool active) onHistory;
  DateTime? _latestFeeding(List<Map<String, dynamic>> entries) {
    DateTime? latest;
    for (final entry in entries) {
      final date = DateTime.tryParse(entry['fedAt'] as String? ?? '');
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: entries,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return due
              ? const SizedBox.shrink()
              : ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(context.l10n.failedToLoadLatestFeeding),
                  trailing: const Icon(Icons.refresh),
                  onTap: onRetry,
                );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        final latest = _latestFeeding(snapshot.data!);
        final interval = animal['feedingReminderIntervalDays'] as int?;
        final baseline = DateTime.tryParse(
          animal['feedingReminderBaseline'] as String? ?? '',
        );
        final weekdays = animal['feedingReminderWeekdays'] as int?;
        final minuteOfDay = animal['feedingReminderMinuteOfDay'] as int?;
        final timeZone = animal['feedingReminderTimeZone'] as String?;
        final next =
            !FeedingWeekdaySchedule.isConfigured(
              intervalDays: interval,
              baseline: baseline,
              weekdays: weekdays,
              minuteOfDay: minuteOfDay,
              timeZone: timeZone,
            )
            ? null
            : weekdays == null
            ? (latest ?? baseline!).add(Duration(days: interval!))
            : FeedingWeekdaySchedule.nextDueAt(
                weekdays: weekdays,
                minuteOfDay: minuteOfDay!,
                timeZone: timeZone!,
                baseline: baseline!,
                latestFeedingAt: latest,
              );
        final overdue = next != null && !next.isAfter(DateTime.now());
        if (due) {
          if (!overdue || animal['status'] != 'active') {
            return const SizedBox.shrink();
          }
          return Card(
            key: const Key('shared-feeding-reminder-status'),
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.notification_important_outlined),
              title: Text(context.l10n.feedingDue),
              subtitle: Text(
                context.l10n.feedingDueSince(
                  feedingDueDateLabel(context, next, timeZone: timeZone),
                ),
              ),
              onTap: () => onHistory(true),
            ),
          );
        }
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: Text(context.l10n.latestFeeding),
              subtitle: Text(
                latest == null
                    ? context.l10n.noFeedingEventsAvailable
                    : sharedDateTimeLabel(context, latest),
              ),
              onTap: () => onHistory(animal['status'] == 'active'),
            ),
            if (next != null && !overdue && animal['status'] == 'active')
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(context.l10n.nextFeeding),
                subtitle: Text(
                  feedingDueDateLabel(context, next, timeZone: timeZone),
                ),
                onTap: () => onHistory(true),
              ),
          ],
        );
      },
    );
  }
}
