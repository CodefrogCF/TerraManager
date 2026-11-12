import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/reminder_due_button.dart';
import '../../../../l10n/app_localizations_context.dart';

enum FeedingAlertAction { viewAnimal, addFeeding, suppressFor24Hours }

Future<FeedingAlertAction?> showFeedingAlertActions(
  BuildContext context, {
  required String animalName,
  bool enabled = true,
}) => showDialog<FeedingAlertAction>(
  context: context,
  builder: (context) => AlertDialog(
    key: const Key('feeding-alert-actions'),
    scrollable: true,
    title: Text(animalName),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              key: const Key('feeding-alert-view-animal'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pets_outlined),
              title: Text(context.l10n.viewAnimal),
              onTap: () =>
                  Navigator.pop(context, FeedingAlertAction.viewAnimal),
            ),
            ListTile(
              key: const Key('feeding-alert-add-feeding'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_outlined),
              title: Text(context.l10n.addFeeding),
              enabled: enabled,
              onTap: () =>
                  Navigator.pop(context, FeedingAlertAction.addFeeding),
            ),
            ListTile(
              key: const Key('feeding-alert-suppress'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_paused_outlined),
              title: Text(context.l10n.suppressFeedingAlert24Hours),
              enabled: enabled,
              onTap: () =>
                  Navigator.pop(context, FeedingAlertAction.suppressFor24Hours),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.feedingAlertSuppressionExplanation),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
    ],
  ),
);

/// A separate button keeps the surrounding Animal row's navigation available.
class FeedingAlertButton extends StatelessWidget {
  const FeedingAlertButton({
    super.key,
    required this.onPressed,
    this.iconOnly = false,
  });
  final VoidCallback onPressed;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) => ReminderDueButton(
    tooltip: context.l10n.feedingAlertActions,
    onPressed: onPressed,
    iconOnly: iconOnly,
  );
}
