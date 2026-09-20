import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/shedding_repository.dart';
import '../../../l10n/app_localizations_context.dart';

Future<bool?> showSheddingEntryDialog({
  required BuildContext context,
  required AppDatabase database,
  required int animalId,
  SheddingEvent? entry,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SheddingEntryDialog(
      database: database,
      animalId: animalId,
      entry: entry,
    ),
  );
}

class _SheddingEntryDialog extends StatefulWidget {
  final AppDatabase database;
  final int animalId;
  final SheddingEvent? entry;

  const _SheddingEntryDialog({
    required this.database,
    required this.animalId,
    this.entry,
  });

  bool get isEditing => entry != null;

  @override
  State<_SheddingEntryDialog> createState() => _SheddingEntryDialogState();
}

class _SheddingEntryDialogState extends State<_SheddingEntryDialog> {
  final _notesController = TextEditingController();

  late DateTime _shedAt;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _shedAt = widget.entry?.shedAt ?? DateTime.now();

    _notesController.text = widget.entry?.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (_shedAt.isAfter(DateTime.now())) {
      setState(() => _error = context.l10n.sheddingDateTimeInFuture);
      return;
    }

    final normalizedNotes = _notesController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repository = SheddingRepository(widget.database);

      if (widget.isEditing) {
        final updated = await repository.update(
          eventId: widget.entry!.id,
          animalId: widget.animalId,
          shedAt: _shedAt,
          notes: normalizedNotes.isEmpty ? null : normalizedNotes,
        );

        if (!updated) {
          throw StateError('Shedding update failed');
        }
      } else {
        await repository.add(
          animalId: widget.animalId,
          shedAt: _shedAt,
          notes: normalizedNotes.isEmpty ? null : normalizedNotes,
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
            ? context.l10n.failedToUpdateSheddingEvent
            : context.l10n.failedToSaveSheddingEvent;
      });
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();

    final initialDate = _shedAt.isAfter(now) ? now : _shedAt;

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
      initialTime: TimeOfDay.fromDateTime(_shedAt),
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
      _shedAt = selected;

      _error = selected.isAfter(DateTime.now())
          ? context.l10n.sheddingDateTimeInFuture
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('shedding-dialog'),
      title: Text(
        widget.isEditing
            ? context.l10n.editSheddingEvent
            : context.l10n.addSheddingEvent,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                key: const Key('shedding-dialog-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            ListTile(
              key: const Key('shedding-date-time-field'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.dateAndTime),
              subtitle: Text(
                _formatDateTime(context, _shedAt),
                key: const Key('shedding-date-time-value'),
              ),
              trailing: IconButton(
                key: const Key('shedding-date-time-button'),
                onPressed: _saving ? null : _selectDateTime,
                icon: const Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('shedding-notes-field'),
              controller: _notesController,
              enabled: !_saving,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.sheddingNotes,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-shedding-button'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-shedding-button'),
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
