import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/reminder_clock.dart';
import '../../../../core/presentation/widgets/reminder_due_button.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../domain/box_care_reminder.dart';

class BoxCareDueButton extends StatelessWidget {
  const BoxCareDueButton({
    super.key,
    required this.dueOn,
    required this.onPressed,
    this.iconOnly = false,
  });

  final DateTime dueOn;
  final VoidCallback onPressed;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return ReminderClockView(
      transitions: [dueOn].map(BoxCareReminder.dueTime),
      builder: (context, now) => BoxCareReminder.dueTime(dueOn).isAfter(now)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: ReminderDueButton(
                tooltip: context.l10n.boxCareDue,
                onPressed: onPressed,
                iconOnly: iconOnly,
              ),
            ),
    );
  }
}
