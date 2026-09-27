import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_detail_row.dart';

class SharedWeightSection extends StatelessWidget {
  const SharedWeightSection({
    super.key,
    required this.entries,
    required this.active,
    required this.connected,
    required this.onAdd,
    required this.onHistory,
    required this.animal,
  });
  final Future<List<Map<String, dynamic>>?> entries;
  final bool active;
  final bool connected;
  final VoidCallback onAdd;
  final VoidCallback onHistory;
  final Map<String, dynamic> animal;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>?>(
        future: entries,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          final weights = [...snapshot.data!]
            ..sort(
              (a, b) => (b['measuredAt'] as String? ?? '').compareTo(
                a['measuredAt'] as String? ?? '',
              ),
            );
          final latest = weights.firstOrNull;
          final grams = latest?['weightGrams'] as num?;
          final legacy = (animal['weight'] as String?)?.trim();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (grams != null)
                SharedDetailRow(
                  key: const Key('shared-weight-detail'),
                  label: context.l10n.weight,
                  value: context.l10n.weightMeasurement(
                    NumberFormat(
                      '0.##',
                      Localizations.localeOf(context).toLanguageTag(),
                    ).format(grams),
                  ),
                )
              else if (legacy != null && legacy.isNotEmpty)
                SharedDetailRow(label: context.l10n.weight, value: legacy),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: active && connected ? onAdd : null,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addWeightMeasurement),
                  ),
                  TextButton.icon(
                    onPressed: onHistory,
                    icon: const Icon(Icons.history),
                    label: Text(context.l10n.weightHistory),
                  ),
                ],
              ),
            ],
          );
        },
      );
}
