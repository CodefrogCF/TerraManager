import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/constrained_page_width.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../domain/animal_rest_period.dart';
import '../widgets/feeding_due_date_label.dart';
import '../widgets/feeding_reminder_clock.dart';

class FeedingScheduleEntry {
  const FeedingScheduleEntry({
    required this.animalId,
    required this.animalName,
    required this.dueAt,
    this.timeZone,
    this.pause,
  });

  final int animalId;
  final String animalName;
  final DateTime dueAt;
  final String? timeZone;
  final FeedingPauseWindow? pause;
}

/// Chronological appointments for all active Animals with a reminder.
class FeedingSchedulePage extends StatelessWidget {
  const FeedingSchedulePage({
    super.key,
    required this.entries,
    this.onSelectAnimal,
    this.now,
  });

  final List<FeedingScheduleEntry> entries;
  final Future<void> Function(int animalId)? onSelectAnimal;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => FeedingReminderClockView(
    transitions: entries.expand(
      (entry) => [entry.dueAt, ?entry.pause?.startsAt, ?entry.pause?.endsAt],
    ),
    now: now,
    builder: _buildAt,
  );

  Widget _buildAt(BuildContext context, DateTime now) {
    final sorted =
        entries
            .where((entry) => !(entry.pause?.contains(now) ?? false))
            .toList()
          ..sort((a, b) {
            final byDate = a.dueAt.compareTo(b.dueAt);
            return byDate != 0 ? byDate : a.animalId.compareTo(b.animalId);
          });
    final formatter = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_jm();
    return ConstrainedPageWidth(
      child: Scaffold(
        key: const Key('feeding-schedule-page'),
        appBar: AppBar(title: Text(context.l10n.feedingScheduleTitle)),
        body: sorted.isEmpty
            ? Center(child: Text(context.l10n.feedingScheduleEmpty))
            : ListView.builder(
                key: const PageStorageKey<String>('feeding-schedule-list'),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final entry = sorted[index];
                  return ListTile(
                    key: Key('feeding-schedule-animal-${entry.animalId}'),
                    leading: Icon(
                      entry.dueAt.isAfter(now)
                          ? Icons.schedule_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    title: Text(entry.animalName),
                    subtitle: Text(
                      entry.timeZone == null
                          ? formatter.format(entry.dueAt.toLocal())
                          : feedingDueDateLabel(
                              context,
                              entry.dueAt,
                              timeZone: entry.timeZone,
                            ),
                    ),
                    trailing: onSelectAnimal == null
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: onSelectAnimal == null
                        ? null
                        : () => onSelectAnimal!(entry.animalId),
                  );
                },
              ),
      ),
    );
  }
}
