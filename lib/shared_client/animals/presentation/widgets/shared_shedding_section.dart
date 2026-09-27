import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_date_time_label.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_detail_row.dart';

class SharedSheddingSection extends StatelessWidget {
  const SharedSheddingSection({
    super.key,
    required this.entries,
    required this.active,
    required this.connected,
    required this.onAdd,
    required this.onHistory,
  });
  final Future<List<Map<String, dynamic>>?> entries;
  final bool active;
  final bool connected;
  final VoidCallback onAdd;
  final VoidCallback onHistory;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>?>(
        future: entries,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          final entries = [...snapshot.data!]
            ..sort(
              (a, b) => (b['shedAt'] as String? ?? '').compareTo(
                a['shedAt'] as String? ?? '',
              ),
            );
          final latest = DateTime.tryParse(
            entries.firstOrNull?['shedAt'] as String? ?? '',
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SharedDetailRow(
                key: const Key('shared-shedding-detail'),
                label: context.l10n.latestShedding,
                value: latest == null
                    ? context.l10n.noSheddingEventsAvailable
                    : sharedDateTimeLabel(context, latest),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: active && connected ? onAdd : null,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addSheddingEvent),
                  ),
                  TextButton.icon(
                    onPressed: onHistory,
                    icon: const Icon(Icons.history),
                    label: Text(context.l10n.sheddingHistory),
                  ),
                ],
              ),
            ],
          );
        },
      );
}
