import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_context.dart';

class ReminderDueButton extends StatelessWidget {
  const ReminderDueButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.iconOnly = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.onErrorContainer,
          backgroundColor: colors.errorContainer,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        child: iconOnly
            ? const Icon(Icons.notification_important_outlined)
            : Text(
                context.l10n.due,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
