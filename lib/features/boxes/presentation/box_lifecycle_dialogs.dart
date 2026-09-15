import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums/box_archive_reason.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../l10n/app_localizations_labels.dart';
import '../../animals/presentation/animal_display_names.dart';

class ArchiveBoxInput {
  final BoxArchiveReason reason;
  final String notes;

  const ArchiveBoxInput(this.reason, this.notes);
}

class ArchiveBoxDialog extends StatefulWidget {
  final bool hasUnsavedChanges;

  const ArchiveBoxDialog({super.key, required this.hasUnsavedChanges});

  @override
  State<ArchiveBoxDialog> createState() => _ArchiveBoxDialogState();
}

class _ArchiveBoxDialogState extends State<ArchiveBoxDialog> {
  final _notes = TextEditingController();
  BoxArchiveReason? _reason;
  bool _submitted = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('archive-box-dialog'),
      title: Text(context.l10n.archiveBox),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.archiveBoxQuestion),
            if (widget.hasUnsavedChanges) ...[
              const SizedBox(height: 12),
              Text(context.l10n.archiveBoxUnsavedChanges),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<BoxArchiveReason>(
              key: const Key('box-archive-reason-field'),
              initialValue: _reason,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.l10n.reason),
              items: BoxArchiveReason.values
                  .map(
                    (reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(context.l10n.boxArchiveReasonLabel(reason)),
                    ),
                  )
                  .toList(),
              onChanged: _submitted
                  ? null
                  : (reason) => setState(() => _reason = reason),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('box-archive-notes-field'),
              controller: _notes,
              maxLines: 3,
              enabled: !_submitted,
              decoration: InputDecoration(
                labelText: context.l10n.archiveNote,
                helperText: context.l10n.optional,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-archive-box-button'),
          onPressed: _submitted ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-archive-box-button'),
          onPressed: _submitted || _reason == null
              ? null
              : () {
                  if (_submitted) {
                    return;
                  }
                  setState(() => _submitted = true);
                  Navigator.of(context)
                      .pop(ArchiveBoxInput(_reason!, _notes.text));
                },
          child: Text(context.l10n.archive),
        ),
      ],
    );
  }
}

class CannotArchiveBoxDialog extends StatelessWidget {
  final List<Animal> animals;

  CannotArchiveBoxDialog({super.key, required Iterable<Animal> animals})
    : animals = List<Animal>.unmodifiable(animals);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('cannot-archive-box-dialog'),
      title: Text(context.l10n.cannotArchiveBox),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.assignedAnimalsPreventArchive),
            const SizedBox(height: 12),
            for (final animal in animals)
              Builder(
                builder: (context) {
                  final names = AnimalDisplayNames.fromContext(
                    context,
                    commonName: animal.commonName,
                    latinName: animal.latinName,
                  );
                  return ListTile(
                    key: Key('archive-blocking-animal-${animal.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(names.primary),
                    subtitle: Text(names.secondary),
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('close-cannot-archive-box-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.ok),
        ),
      ],
    );
  }
}

class RestoreBoxDialog extends StatefulWidget {
  const RestoreBoxDialog({super.key});

  @override
  State<RestoreBoxDialog> createState() => _RestoreBoxDialogState();
}

class _RestoreBoxDialogState extends State<RestoreBoxDialog> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('restore-box-dialog'),
      title: Text(context.l10n.restoreBox),
      content: Text(context.l10n.restoreBoxQuestion),
      actions: [
        TextButton(
          key: const Key('cancel-restore-box-button'),
          onPressed: _submitted ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-restore-box-button'),
          onPressed: _submitted
              ? null
              : () {
                  if (_submitted) {
                    return;
                  }
                  setState(() => _submitted = true);
                  Navigator.of(context).pop(true);
                },
          child: Text(context.l10n.restore),
        ),
      ],
    );
  }
}
