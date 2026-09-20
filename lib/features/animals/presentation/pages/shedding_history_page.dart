import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/shedding_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../shedding_entry_dialog.dart';

class SheddingHistoryPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;

  const SheddingHistoryPage({
    super.key,
    required this.database,
    required this.animalId,
  });

  @override
  State<SheddingHistoryPage> createState() => _SheddingHistoryPageState();
}

class _SheddingHistoryPageState extends State<SheddingHistoryPage> {
  late Future<List<SheddingEvent>> _entriesFuture;

  int? _deletingEntryId;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    _entriesFuture = SheddingRepository(widget.database)
        .getHistory(widget.animalId);
  }

  Future<void> _addEntry() async {
    final created = await showSheddingEntryDialog(
      context: context,
      database: widget.database,
      animalId: widget.animalId,
    );

    if (!mounted || created != true) {
      return;
    }

    setState(_loadEntries);
  }

  Future<void> _editEntry(SheddingEvent entry) async {
    final changed = await showSheddingEntryDialog(
      context: context,
      database: widget.database,
      animalId: widget.animalId,
      entry: entry,
    );

    if (!mounted || changed != true) {
      return;
    }

    setState(_loadEntries);
  }

  Future<void> _deleteEntry(SheddingEvent entry) async {
    if (_deletingEntryId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('delete-shedding-dialog'),
        title: Text(context.l10n.deleteSheddingEventQuestion),
        content: Text(
          context.l10n.deleteSheddingEventWarning(
            _formatDateTime(context, entry.shedAt),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('cancel-delete-shedding-button'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-shedding-button'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() => _deletingEntryId = entry.id);

    try {
      final deleted = await SheddingRepository(widget.database)
          .delete(eventId: entry.id, animalId: widget.animalId);

      if (!mounted) {
        return;
      }

      if (!deleted) {
        throw StateError('Shedding deletion failed');
      }

      setState(() {
        _deletingEntryId = null;
        _loadEntries();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _deletingEntryId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedToDeleteSheddingEvent)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sheddingHistory)),
      body: FutureBuilder<List<SheddingEvent>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(context.l10n.failedToLoadSheddingHistory),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? const <SheddingEvent>[];

          if (entries.isEmpty) {
            return Center(
              child: Text(
                context.l10n.noSheddingHistory,
                key: const Key('shedding-history-empty'),
              ),
            );
          }

          return ListView.separated(
            key: const Key('shedding-history-list'),
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final entry = entries[index];

              final deleting = _deletingEntryId == entry.id;

              final notes = entry.notes?.trim();

              return ListTile(
                key: Key('shedding-entry-${entry.id}'),
                leading: const Icon(Icons.autorenew),
                title: Text(_formatDateTime(context, entry.shedAt)),
                subtitle: notes == null || notes.isEmpty ? null : Text(notes),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('edit-shedding-button-${entry.id}'),
                      onPressed: _deletingEntryId == null
                          ? () => _editEntry(entry)
                          : null,
                      tooltip: context.l10n.editSheddingEvent,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: Key('delete-shedding-button-${entry.id}'),
                      onPressed: _deletingEntryId == null
                          ? () => _deleteEntry(entry)
                          : null,
                      tooltip: context.l10n.deleteSheddingEvent,
                      icon: deleting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                onTap: _deletingEntryId == null
                    ? () => _editEntry(entry)
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-shedding-button'),
        onPressed: _addEntry,
        tooltip: context.l10n.addSheddingEvent,
        child: const Icon(Icons.add),
      ),
    );
  }
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();

  final material = MaterialLocalizations.of(context);

  return [
    material.formatMediumDate(local),
    material.formatTimeOfDay(TimeOfDay.fromDateTime(local)),
  ].join(', ');
}
