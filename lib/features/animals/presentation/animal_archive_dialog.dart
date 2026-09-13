import 'package:flutter/material.dart';

import '../../../core/database/enums/animal_archive_reason.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../l10n/app_localizations_labels.dart';

class AnimalArchiveInput {
  final AnimalArchiveReason reason;
  final DateTime archivedAt;
  final String? notes;

  const AnimalArchiveInput({
    required this.reason,
    required this.archivedAt,
    this.notes,
  });
}

class AnimalArchiveDialog extends StatefulWidget {
  final bool hasUnsavedChanges;

  const AnimalArchiveDialog({super.key, required this.hasUnsavedChanges});

  @override
  State<AnimalArchiveDialog> createState() => _AnimalArchiveDialogState();
}

class _AnimalArchiveDialogState extends State<AnimalArchiveDialog> {
  final TextEditingController _notesController = TextEditingController();

  AnimalArchiveReason? _reason;
  late DateTime _archiveDate;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _archiveDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    if (_submitted) {
      return;
    }
    final selected = await showDatePicker(
      context: context,
      initialDate: _archiveDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _archiveDate = selected);
  }

  void _confirm() {
    final reason = _reason;
    if (_submitted || reason == null) {
      return;
    }
    final notes = _notesController.text.trim();
    setState(() => _submitted = true);
    Navigator.of(context).pop(
      AnimalArchiveInput(
        reason: reason,
        archivedAt: _archiveDate,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('archive-animal-dialog'),
      scrollable: true,
      title: Text(context.l10n.archiveAnimal),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.archiveAnimalQuestion),
          if (widget.hasUnsavedChanges) ...[
            const SizedBox(height: 12),
            Text(context.l10n.archiveAnimalUnsavedChanges),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<AnimalArchiveReason>(
            key: const Key('archive-reason-field'),
            initialValue: _reason,
            decoration: InputDecoration(labelText: context.l10n.reason),
            items: AnimalArchiveReason.values
                .map(
                  (reason) => DropdownMenuItem<AnimalArchiveReason>(
                    value: reason,
                    child: Text(context.l10n.animalArchiveReasonLabel(reason)),
                  ),
                )
                .toList(),
            onChanged: _submitted
                ? null
                : (value) => setState(() => _reason = value),
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const Key('archive-date-field'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.archiveDate),
            subtitle: Text(_formatDate(_archiveDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _submitted ? null : _selectDate,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('archive-notes-field'),
            controller: _notesController,
            maxLines: 3,
            enabled: !_submitted,
            decoration: InputDecoration(
              labelText: context.l10n.note,
              hintText: context.l10n.optional,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancel-archive-animal-button'),
          onPressed: _submitted ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-archive-animal-button'),
          onPressed: _submitted || _reason == null ? null : _confirm,
          child: Text(context.l10n.archive),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
