import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_context.dart';
import '../application/release_highlights_controller.dart';

Future<void> showReleaseHighlights(
  BuildContext context, {
  required InstalledRelease release,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final text = context.l10n;
    final highlights = [
      (
        Icons.notifications_outlined,
        text.releaseHighlightsNotificationsTitle,
        text.releaseHighlightsNotificationsBody,
      ),
      (
        Icons.restaurant_outlined,
        text.releaseHighlightsFeedingTitle,
        text.releaseHighlightsFeedingBody,
      ),
      (
        Icons.inventory_2_outlined,
        text.releaseHighlightsBoxesTitle,
        text.releaseHighlightsBoxesBody,
      ),
      (
        Icons.touch_app_outlined,
        text.releaseHighlightsOverviewTitle,
        text.releaseHighlightsOverviewBody,
      ),
    ];
    return AlertDialog(
      key: const Key('release-highlights-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      scrollable: true,
      title: Text(text.releaseHighlightsTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.releaseHighlightsVersion(
                release.version,
                release.buildNumber,
              ),
              key: const Key('release-highlights-version'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Text(text.releaseHighlightsIntro),
            const SizedBox(height: 24),
            for (final (icon, title, body) in highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(body),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              text.releaseHighlightsSettingsHint,
              key: const Key('release-highlights-settings-hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('release-highlights-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text.releaseHighlightsClose),
        ),
      ],
    );
  },
);
