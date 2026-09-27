import 'package:flutter/material.dart';
import 'package:terramanager/core/sorting/archive_sorting.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

typedef SharedArchiveSnapshot = ({
  List<Map<String, dynamic>> boxes,
  List<Map<String, dynamic>> animals,
  bool connected,
});

List<Map<String, dynamic>> sortSharedArchiveRecords(
  Iterable<Map<String, dynamic>> records, {
  required ArchiveSortOrder order,
  required String Function(Map<String, dynamic>) displayName,
}) => sortArchivedRecords(
  records.where((record) => record['status'] == 'archived'),
  sortOrder: order,
  archivedAt: (record) =>
      DateTime.tryParse(record['archivedAt'] as String? ?? ''),
  displayName: displayName,
  id: recordId,
);

String sharedArchiveSummary(
  BuildContext context,
  Map<String, dynamic> record, {
  required bool box,
}) {
  final reason = record['archiveReason'] as String?;
  final date = DateTime.tryParse(record['archivedAt'] as String? ?? '')
      ?.toLocal();
  final parts = [
    if (reason != null) sharedArchiveReasonLabel(context, reason, box: box),
    if (date != null) MaterialLocalizations.of(context).formatShortDate(date),
  ];
  return parts.isEmpty ? context.l10n.archived : parts.join(' • ');
}
