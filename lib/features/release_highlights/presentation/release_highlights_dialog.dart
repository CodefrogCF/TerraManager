import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_context.dart';
import '../application/release_highlights_controller.dart';
import 'release_highlights_content.dart';

Future<void> showReleaseHighlights(
  BuildContext context, {
  required InstalledRelease release,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final text = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
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
            for (final highlight in releaseHighlightsContent)
              Padding(
                key: ValueKey('release-highlight-${highlight.number}'),
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        highlight.icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            highlight.localized(languageCode).title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(highlight.localized(languageCode).description),
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
