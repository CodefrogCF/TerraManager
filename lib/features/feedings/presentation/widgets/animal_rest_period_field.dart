import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations_context.dart';
import '../../domain/animal_rest_period.dart';
import '../../infrastructure/feeding_device_time_zone.dart';

String animalRestPeriodLabel(BuildContext context, AnimalRestPeriod period) {
  final format = DateFormat.yMd(
    Localizations.localeOf(context).toLanguageTag(),
  );
  final start = format.format(period.startDate);
  final end = format.format(period.endDate);
  return '${start == end ? start : '$start – $end'} (${period.timeZone})';
}

class AnimalRestPeriodField extends StatelessWidget {
  const AnimalRestPeriodField({
    super.key,
    required this.period,
    required this.enabled,
    required this.onChanged,
    this.reminderTimeZone,
  });

  final AnimalRestPeriod? period;
  final bool enabled;
  final ValueChanged<AnimalRestPeriod?> onChanged;
  final String? reminderTimeZone;

  Future<void> _pick(BuildContext context) async {
    final current = period;
    final start = current?.startDate;
    final end = current?.endDate;
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100, 12, 31);
    final selected = await showDateRangePicker(
      context: context,
      helpText: context.l10n.animalRestPeriod,
      firstDate: start != null && start.year < firstDate.year
          ? start
          : firstDate,
      lastDate: end != null && end.year > lastDate.year ? end : lastDate,
      initialDateRange: start == null || end == null
          ? null
          : DateTimeRange(start: start, end: end),
    );
    if (!context.mounted || selected == null) return;
    final zone =
        current?.timeZone ??
        reminderTimeZone ??
        await currentFeedingTimeZone() ??
        'UTC';
    if (!context.mounted) return;
    try {
      onChanged(
        AnimalRestPeriod(
          startDate: selected.start,
          endDate: selected.end,
          timeZone: zone,
        ),
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.animalRestPeriodInvalid)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = period;
    return ListTile(
      key: const Key('animal-rest-period-field'),
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: const Icon(Icons.pause_circle_outline),
      title: Text(context.l10n.animalRestPeriod),
      subtitle: Text(
        current == null
            ? context.l10n.animalRestPeriodHint
            : animalRestPeriodLabel(context, current),
      ),
      onTap: enabled ? () => _pick(context) : null,
      trailing: current == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              key: const Key('clear-animal-rest-period'),
              tooltip: context.l10n.animalRestPeriodClear,
              onPressed: enabled ? () => onChanged(null) : null,
              icon: const Icon(Icons.clear),
            ),
    );
  }
}
