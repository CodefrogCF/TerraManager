import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/constrained_page_width.dart';
import '../../../../l10n/app_localizations_context.dart';

class FeedingScheduleEntry {
  const FeedingScheduleEntry({
    required this.animalId,
    required this.animalName,
    required this.dueAt,
  });

  final int animalId;
  final String animalName;
  final DateTime dueAt;
}

/// Chronological appointments for all active Animals with a reminder.
class FeedingSchedulePage extends StatelessWidget {
  const FeedingSchedulePage({
    super.key,
    required this.entries,
    this.onSelectAnimal,
  });

  final List<FeedingScheduleEntry> entries;
  final Future<void> Function(int animalId)? onSelectAnimal;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
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
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final entry = sorted[index];
                  return ListTile(
                    key: Key('feeding-schedule-animal-${entry.animalId}'),
                    leading: Icon(
                      entry.dueAt.isAfter(DateTime.now())
                          ? Icons.schedule_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    title: Text(entry.animalName),
                    subtitle: Text(formatter.format(entry.dueAt.toLocal())),
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
