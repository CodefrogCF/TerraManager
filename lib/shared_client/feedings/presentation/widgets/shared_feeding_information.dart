import 'dart:async';

import 'package:flutter/material.dart';
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
        final next = interval == null || interval <= 0 || baseline == null
            ? null
            : (latest ?? baseline).add(Duration(days: interval));
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
                  sharedDateTimeLabel(context, next),
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
                subtitle: Text(sharedDateTimeLabel(context, next)),
                onTap: () => onHistory(true),
              ),
          ],
        );
      },
    );
  }
}
