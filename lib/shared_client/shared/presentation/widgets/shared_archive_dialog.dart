import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

Future<(String, String?)?> showArchiveDialog(
  BuildContext context, {
  required List<String> reasons,
}) => showDialog<(String, String?)>(
  context: context,
  builder: (_) => _ArchiveDialog(reasons: reasons),
);

class _ArchiveDialog extends StatefulWidget {
  const _ArchiveDialog({required this.reasons});
  final List<String> reasons;

  @override
  State<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<_ArchiveDialog> {
  late String _reason = widget.reasons.first;
  final TextEditingController _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(sharedText(context, 'Archive', 'Archivieren')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reason,
          items: [
            for (final value in widget.reasons)
              DropdownMenuItem(
                value: value,
                child: Text(
                  sharedArchiveReasonLabel(
                    context,
                    value,
                    box: widget.reasons.contains('replaced'),
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _reason = value);
          },
        ),
        TextField(
          controller: _notes,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Notes', 'Notizen'),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        onPressed: () {
          final notes = _notes.text.trim();
          Navigator.of(context).pop((_reason, notes.isEmpty ? null : notes));
        },
        child: Text(sharedText(context, 'Archive', 'Archivieren')),
      ),
    ],
  );
}
