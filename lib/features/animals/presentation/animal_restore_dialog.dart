import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations_context.dart';

class RestoreAnimalDialog extends StatefulWidget {
  final List<Box> boxes;

  const RestoreAnimalDialog({super.key, required this.boxes});

  @override
  State<RestoreAnimalDialog> createState() => _RestoreAnimalDialogState();
}

class _RestoreAnimalDialogState extends State<RestoreAnimalDialog> {
  int? _boxId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('restore-animal-dialog'),
      title: Text(context.l10n.restoreAnimal),
      content: DropdownButtonFormField<int>(
        key: const Key('restore-box-field'),
        initialValue: _boxId,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.l10n.assignToBox),
        items: widget.boxes
            .map(
              (box) => DropdownMenuItem<int>(
                value: box.id,
                child: Text(
                  context.l10n.boxLabel(box.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _boxId = value;
          });
        },
      ),
      actions: [
        TextButton(
          key: const Key('cancel-restore-animal-button'),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-restore-animal-button'),
          onPressed: _boxId == null
              ? null
              : () {
                  Navigator.of(context).pop(_boxId);
                },
          child: Text(context.l10n.restore),
        ),
      ],
    );
  }
}
