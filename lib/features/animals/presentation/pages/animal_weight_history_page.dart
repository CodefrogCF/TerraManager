import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_weight_repository.dart';
import '../../../../l10n/app_localizations_context.dart';

Future<bool?> showWeightEntryDialog({
  required BuildContext context,
  required AppDatabase database,
  required int animalId,
  AnimalWeightEntry? entry,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _WeightEntryDialog(
      database: database,
      animalId: animalId,
      entry: entry,
    ),
  );
}

class AnimalWeightHistoryPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;

  const AnimalWeightHistoryPage({
    super.key,
    required this.database,
    required this.animalId,
  });

  @override
  State<AnimalWeightHistoryPage> createState() =>
      _AnimalWeightHistoryPageState();
}

class _AnimalWeightHistoryPageState extends State<AnimalWeightHistoryPage> {
  late Future<List<AnimalWeightEntry>> _entriesFuture;
  int? _deletingEntryId;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    _entriesFuture = AnimalWeightRepository(widget.database)
        .getHistory(widget.animalId);
  }

  Future<void> _addEntry() async {
    final created = await showWeightEntryDialog(
      context: context,
      database: widget.database,
      animalId: widget.animalId,
    );
    if (!mounted || created != true) {
      return;
    }
    setState(_loadEntries);
  }

  Future<void> _editEntry(AnimalWeightEntry entry) async {
    final changed = await showWeightEntryDialog(
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

  Future<void> _deleteEntry(AnimalWeightEntry entry) async {
    if (_deletingEntryId != null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('delete-weight-dialog'),
        title: Text(context.l10n.deleteWeightMeasurementQuestion),
        content: Text(
          context.l10n.deleteWeightMeasurementWarning(
            context.l10n.weightMeasurement(_formatNumber(entry.weightGrams)),
            _formatDateTime(context, entry.measuredAt),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('cancel-delete-weight-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-weight-button'),
            onPressed: () => Navigator.of(context).pop(true),
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
      final deleted = await AnimalWeightRepository(widget.database)
          .delete(entryId: entry.id, animalId: widget.animalId);
      if (!mounted) {
        return;
      }
      if (!deleted) {
        throw StateError('Weight deletion failed');
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
        SnackBar(content: Text(context.l10n.failedToDeleteWeightMeasurement)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.weightHistory)),
      body: FutureBuilder<List<AnimalWeightEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.failedToLoadWeightHistory));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <AnimalWeightEntry>[];
          if (entries.isEmpty) {
            return Center(
              child: Text(
                context.l10n.noWeightHistory,
                key: const Key('weight-history-empty'),
              ),
            );
          }
          return ListView.separated(
            key: const Key('weight-history-list'),
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final deleting = _deletingEntryId == entry.id;
              return ListTile(
                key: Key('weight-entry-${entry.id}'),
                leading: const Icon(Icons.monitor_weight_outlined),
                title: Text(
                  context.l10n.weightMeasurement(
                    _formatNumber(entry.weightGrams),
                  ),
                ),
                subtitle: Text(_formatDateTime(context, entry.measuredAt)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('edit-weight-button-${entry.id}'),
                      onPressed: _deletingEntryId == null
                          ? () => _editEntry(entry)
                          : null,
                      tooltip: context.l10n.editWeightMeasurement,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: Key('delete-weight-button-${entry.id}'),
                      onPressed: _deletingEntryId == null
                          ? () => _deleteEntry(entry)
                          : null,
                      tooltip: context.l10n.deleteWeightMeasurement,
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
        key: const Key('add-weight-button'),
        onPressed: _addEntry,
        tooltip: context.l10n.addWeightMeasurement,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WeightEntryDialog extends StatefulWidget {
  final AppDatabase database;
  final int animalId;
  final AnimalWeightEntry? entry;

  const _WeightEntryDialog({
    required this.database,
    required this.animalId,
    this.entry,
  });

  bool get isEditing => entry != null;

  @override
  State<_WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<_WeightEntryDialog> {
  final _weightController = TextEditingController();
  late DateTime _measuredAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _measuredAt = widget.entry?.measuredAt ?? DateTime.now();
    final weight = widget.entry?.weightGrams;
    if (weight != null) {
      _weightController.text = _formatNumber(weight);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    if (weight == null || !weight.isFinite || weight <= 0) {
      setState(() => _error = context.l10n.pleaseEnterPositiveNumber);
      return;
    }
    if (_measuredAt.isAfter(DateTime.now())) {
      setState(() => _error = context.l10n.weightDateTimeInFuture);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = AnimalWeightRepository(widget.database);
      if (widget.isEditing) {
        final updated = await repository.update(
          entryId: widget.entry!.id,
          animalId: widget.animalId,
          weightGrams: weight,
          measuredAt: _measuredAt,
        );
        if (!updated) {
          throw StateError('Weight update failed');
        }
      } else {
        await repository.add(
          animalId: widget.animalId,
          weightGrams: weight,
          measuredAt: _measuredAt,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = widget.isEditing
            ? context.l10n.failedToUpdateWeightMeasurement
            : context.l10n.failedToSaveWeightMeasurement;
      });
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initialDate = _measuredAt.isAfter(now) ? now : _measuredAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
    );
    if (time == null || !mounted) {
      return;
    }
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _measuredAt = selected;
      _error = selected.isAfter(DateTime.now())
          ? context.l10n.weightDateTimeInFuture
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('weight-dialog'),
      title: Text(
        widget.isEditing
            ? context.l10n.editWeightMeasurement
            : context.l10n.addWeightMeasurement,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                key: const Key('weight-dialog-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              key: const Key('weight-value-field'),
              controller: _weightController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(labelText: context.l10n.weightGrams),
            ),
            const SizedBox(height: 16),
            ListTile(
              key: const Key('weight-date-time-field'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.dateAndTime),
              subtitle: Text(
                _formatDateTime(context, _measuredAt),
                key: const Key('weight-date-time-value'),
              ),
              trailing: IconButton(
                key: const Key('weight-date-time-button'),
                onPressed: _saving ? null : _selectDateTime,
                icon: const Icon(Icons.calendar_today),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-weight-button'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-weight-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? context.l10n.saving : context.l10n.save),
        ),
      ],
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

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
