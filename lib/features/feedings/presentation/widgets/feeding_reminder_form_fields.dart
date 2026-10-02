import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations_context.dart';
import '../../domain/feeding_weekday_schedule.dart';

class FeedingReminderFormFields extends StatelessWidget {
  final bool reminderEnabled;
  final bool controlsEnabled;
  final TextEditingController intervalDaysController;
  final ValueChanged<bool> onReminderEnabledChanged;
  final ValueChanged<String>? onIntervalChanged;
  final bool weekdayMode;
  final ValueChanged<bool>? onWeekdayModeChanged;
  final int selectedWeekdays;
  final ValueChanged<int>? onWeekdaysChanged;
  final int minuteOfDay;
  final ValueChanged<int>? onMinuteOfDayChanged;
  final String timeZone;
  final ValueChanged<String>? onTimeZoneChanged;

  const FeedingReminderFormFields({
    super.key,
    required this.reminderEnabled,
    required this.controlsEnabled,
    required this.intervalDaysController,
    required this.onReminderEnabledChanged,
    this.onIntervalChanged,
    this.weekdayMode = false,
    this.onWeekdayModeChanged,
    this.selectedWeekdays = 0,
    this.onWeekdaysChanged,
    this.minuteOfDay = 12 * 60,
    this.onMinuteOfDayChanged,
    this.timeZone = 'UTC',
    this.onTimeZoneChanged,
  });

  Future<void> _chooseTimeZone(BuildContext context) async {
    var query = '';
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final zones = FeedingWeekdaySchedule.availableTimeZones
              .where((zone) => zone.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return AlertDialog(
            title: Text(context.l10n.feedingReminderTimeZone),
            content: SizedBox(
              width: 420,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) =>
                        setDialogState(() => query = value.trim()),
                    decoration: InputDecoration(
                      labelText: context.l10n.feedingReminderSearchTimeZone,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: zones.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(zones[index]),
                        onTap: () =>
                            Navigator.of(dialogContext).pop(zones[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (chosen != null) onTimeZoneChanged?.call(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('feeding-reminder-enabled-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.feedingReminder),
          subtitle: Text(context.l10n.feedingReminderDescription),
          value: reminderEnabled,
          onChanged: controlsEnabled ? onReminderEnabledChanged : null,
        ),
        if (reminderEnabled) ...[
          const SizedBox(height: 8),
          if (onWeekdayModeChanged != null) ...[
            Text(context.l10n.feedingReminderMode),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: const Key('feeding-reminder-mode-selector'),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(context.l10n.feedingReminderModeInterval),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(context.l10n.feedingReminderModeWeekdays),
                ),
              ],
              selected: {weekdayMode},
              onSelectionChanged: controlsEnabled
                  ? (selection) => onWeekdayModeChanged!(selection.first)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          if (!weekdayMode)
            TextFormField(
              key: const Key('feeding-reminder-interval-days-field'),
              controller: intervalDaysController,
              enabled: controlsEnabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: context.l10n.feedingReminderIntervalDays,
                helperText: context.l10n.feedingReminderIntervalDaysHelper,
              ),
              onChanged: onIntervalChanged,
              validator: (value) {
                final intervalDays = int.tryParse(value?.trim() ?? '');

                if (intervalDays == null || intervalDays <= 0) {
                  return context.l10n.pleaseEnterPositiveReminderInterval;
                }

                return null;
              },
            )
          else ...[
            FormField<int>(
              validator: (_) => selectedWeekdays == 0
                  ? context.l10n.feedingReminderSelectWeekday
                  : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.feedingReminderWeekdays),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (
                        var weekday = DateTime.monday;
                        weekday <= DateTime.sunday;
                        weekday++
                      )
                        Semantics(
                          label: DateFormat.EEEE(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(DateTime(2024, 1, weekday)),
                          child: FilterChip(
                            key: Key('feeding-weekday-$weekday'),
                            label: Text(
                              DateFormat.E(
                                Localizations.localeOf(context).toLanguageTag(),
                              ).format(DateTime(2024, 1, weekday)),
                            ),
                            selected: FeedingWeekdaySchedule.hasWeekday(
                              selectedWeekdays,
                              weekday,
                            ),
                            onSelected: controlsEnabled
                                ? (_) => onWeekdaysChanged?.call(
                                    selectedWeekdays ^
                                        (1 << (weekday - DateTime.monday)),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  if (field.hasError)
                    Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              key: const Key('feeding-reminder-time'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.feedingReminderTime),
              subtitle: Text(
                TimeOfDay(
                  hour: minuteOfDay ~/ 60,
                  minute: minuteOfDay % 60,
                ).format(context),
              ),
              onTap: controlsEnabled
                  ? () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: minuteOfDay ~/ 60,
                          minute: minuteOfDay % 60,
                        ),
                      );
                      if (selected != null) {
                        onMinuteOfDayChanged?.call(
                          selected.hour * 60 + selected.minute,
                        );
                      }
                    }
                  : null,
            ),
            ListTile(
              key: const Key('feeding-reminder-time-zone'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.feedingReminderTimeZone),
              subtitle: Text(timeZone),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: controlsEnabled && onTimeZoneChanged != null
                  ? () => _chooseTimeZone(context)
                  : null,
            ),
          ],
        ],
      ],
    );
  }
}
