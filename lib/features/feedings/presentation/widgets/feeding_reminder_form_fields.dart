import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations_context.dart';

class FeedingReminderFormFields extends StatelessWidget {
  final bool reminderEnabled;
  final bool controlsEnabled;
  final TextEditingController intervalDaysController;
  final ValueChanged<bool> onReminderEnabledChanged;
  final ValueChanged<String>? onIntervalChanged;

  const FeedingReminderFormFields({
    super.key,
    required this.reminderEnabled,
    required this.controlsEnabled,
    required this.intervalDaysController,
    required this.onReminderEnabledChanged,
    this.onIntervalChanged,
  });

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
          ),
        ],
      ],
    );
  }
}
