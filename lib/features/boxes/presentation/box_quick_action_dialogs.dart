import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_context.dart';

class BoxNameInput {
  final String? name;

  const BoxNameInput(this.name);
}

class RenameBoxDialog extends StatefulWidget {
  final String? initialName;

  const RenameBoxDialog({super.key, this.initialName});

  @override
  State<RenameBoxDialog> createState() => _RenameBoxDialogState();
}

class _RenameBoxDialogState extends State<RenameBoxDialog> {
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
    final name = _nameController.text.trim();
    Navigator.of(context).pop(BoxNameInput(name.isEmpty ? null : name));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('rename-box-dialog'),
      title: Text(context.l10n.renameBox),
      content: TextField(
        key: const Key('rename-box-name-field'),
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: context.l10n.boxName,
          helperText: context.l10n.optional,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-rename-box-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-rename-box-button'),
          onPressed: _save,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

class DuplicateBoxDialog extends StatefulWidget {
  final String? initialName;

  const DuplicateBoxDialog({super.key, this.initialName});

  @override
  State<DuplicateBoxDialog> createState() => _DuplicateBoxDialogState();
}

class _DuplicateBoxDialogState extends State<DuplicateBoxDialog> {
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
    final name = _nameController.text.trim();
    Navigator.of(context).pop(BoxNameInput(name.isEmpty ? null : name));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('duplicate-box-dialog'),
      title: Text(context.l10n.duplicateBox),
      content: TextField(
        key: const Key('duplicate-box-name-field'),
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: context.l10n.boxName,
          helperText: context.l10n.optional,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-duplicate-box-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-duplicate-box-button'),
          onPressed: _save,
          child: Text(context.l10n.duplicate),
        ),
      ],
    );
  }
}
