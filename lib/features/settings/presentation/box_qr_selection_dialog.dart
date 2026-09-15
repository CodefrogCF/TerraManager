import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../boxes/presentation/box_selection_label.dart';

class BoxQrSelectionDialog extends StatefulWidget {
  final List<Box> activeBoxes;
  final List<Box> archivedBoxes;

  BoxQrSelectionDialog({
    super.key,
    required Iterable<Box> activeBoxes,
    required Iterable<Box> archivedBoxes,
  }) : activeBoxes = List<Box>.unmodifiable(activeBoxes),
       archivedBoxes = List<Box>.unmodifiable(archivedBoxes);

  @override
  State<BoxQrSelectionDialog> createState() => _BoxQrSelectionDialogState();
}

class _BoxQrSelectionDialogState extends State<BoxQrSelectionDialog> {
  late final Set<int> _allBoxIds;
  late Set<int> _selectedBoxIds;

  @override
  void initState() {
    super.initState();
    _allBoxIds = {
      for (final box in widget.activeBoxes) box.id,
      for (final box in widget.archivedBoxes) box.id,
    };
    _selectedBoxIds = Set<int>.of(_allBoxIds);
  }

  void _setSelected(int boxId, bool selected) {
    setState(() {
      if (selected) {
        _selectedBoxIds.add(boxId);
      } else {
        _selectedBoxIds.remove(boxId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedBoxIds = Set<int>.of(_allBoxIds);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedBoxIds.clear();
    });
  }

  void _confirm() {
    if (_selectedBoxIds.isEmpty) {
      return;
    }

    Navigator.of(context).pop(Set<int>.unmodifiable(_selectedBoxIds));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('box-qr-selection-dialog'),
      scrollable: true,
      title: Text(context.l10n.saveBoxQrCodes),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.saveBoxQrCodesDescription),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: const Key('select-all-box-qr-codes-button'),
                  onPressed: _selectedBoxIds.length == _allBoxIds.length
                      ? null
                      : _selectAll,
                  icon: const Icon(Icons.select_all),
                  label: Text(context.l10n.selectAll),
                ),
                TextButton.icon(
                  key: const Key('clear-box-qr-selection-button'),
                  onPressed: _selectedBoxIds.isEmpty ? null : _clearSelection,
                  icon: const Icon(Icons.deselect),
                  label: Text(context.l10n.clearSelection),
                ),
              ],
            ),
            if (_selectedBoxIds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  context.l10n.selectAtLeastOneBox,
                  key: const Key('empty-box-qr-selection-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (widget.activeBoxes.isNotEmpty) ...[
              _GroupHeading(
                key: const Key('active-boxes-qr-heading'),
                label: context.l10n.activeBoxes,
              ),
              for (final box in widget.activeBoxes) _boxTile(context, box),
            ],
            if (widget.archivedBoxes.isNotEmpty) ...[
              _GroupHeading(
                key: const Key('archived-boxes-qr-heading'),
                label: context.l10n.archivedBoxes,
              ),
              for (final box in widget.archivedBoxes) _boxTile(context, box),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-box-qr-export-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-box-qr-export-button'),
          onPressed: _selectedBoxIds.isEmpty ? null : _confirm,
          child: Text(context.l10n.saveSelectedQrCodes),
        ),
      ],
    );
  }

  Widget _boxTile(BuildContext context, Box box) {
    return CheckboxListTile(
      key: Key('box-qr-selection-checkbox-${box.id}'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selectedBoxIds.contains(box.id),
      title: Text(boxSelectionLabel(context.l10n, box)),
      onChanged: (selected) => _setSelected(box.id, selected ?? false),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  final String label;

  const _GroupHeading({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
