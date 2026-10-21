import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations_context.dart';

enum FeedingAlertAction { addFeeding, suppressFor24Hours }

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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.feedingAlertActions,
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
