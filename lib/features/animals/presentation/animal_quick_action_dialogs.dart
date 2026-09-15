import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../boxes/presentation/box_selection_label.dart';

class DuplicateAnimalInput {
  final String commonName;
  final int boxId;

  const DuplicateAnimalInput({required this.commonName, required this.boxId});
}

class RenameAnimalDialog extends StatefulWidget {
  final String initialName;

  const RenameAnimalDialog({super.key, required this.initialName});

  @override
  State<RenameAnimalDialog> createState() => _RenameAnimalDialogState();
}

class _RenameAnimalDialogState extends State<RenameAnimalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('rename-animal-dialog'),
      title: Text(context.l10n.renameAnimal),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('rename-animal-name-field'),
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: context.l10n.commonName),
          validator: _validateName,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-rename-animal-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-rename-animal-button'),
          onPressed: _save,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.pleaseEnterCommonName;
    }
    return null;
  }
}

class DuplicateAnimalDialog extends StatefulWidget {
  final String initialName;
  final List<Box> boxes;
  final int? initialBoxId;

  DuplicateAnimalDialog({
    super.key,
    required this.initialName,
    required Iterable<Box> boxes,
    this.initialBoxId,
  }) : boxes = List<Box>.unmodifiable(boxes);

  @override
  State<DuplicateAnimalDialog> createState() => _DuplicateAnimalDialogState();
}

class _DuplicateAnimalDialogState extends State<DuplicateAnimalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  int? _boxId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _boxId = widget.boxes.any((box) => box.id == widget.initialBoxId)
        ? widget.initialBoxId
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      DuplicateAnimalInput(
        commonName: _nameController.text.trim(),
        boxId: _boxId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('duplicate-animal-dialog'),
      title: Text(context.l10n.duplicateAnimal),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('duplicate-animal-name-field'),
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: context.l10n.commonName),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.pleaseEnterCommonName;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('duplicate-animal-box-field'),
                initialValue: _boxId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.associatedBox,
                ),
                items: widget.boxes
                    .map(
                      (box) => DropdownMenuItem<int>(
                        value: box.id,
                        child: Text(
                          boxSelectionLabel(context.l10n, box),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _boxId = value),
                validator: (value) =>
                    value == null ? context.l10n.pleaseSelectBox : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-duplicate-animal-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-duplicate-animal-button'),
          onPressed: _save,
          child: Text(context.l10n.duplicate),
        ),
      ],
    );
  }
}
