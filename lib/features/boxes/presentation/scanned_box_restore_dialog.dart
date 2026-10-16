import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_context.dart';

class ScannedBoxRestoreDialog extends StatefulWidget {
  const ScannedBoxRestoreDialog({super.key, required this.boxLabel});

  final String boxLabel;

  @override
  State<ScannedBoxRestoreDialog> createState() =>
      _ScannedBoxRestoreDialogState();
}

class _ScannedBoxRestoreDialogState extends State<ScannedBoxRestoreDialog> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('scanned-box-restore-dialog'),
    title: Text(context.l10n.restoreBox),
    content: Text('${widget.boxLabel}\n\n${context.l10n.restoreBoxQuestion}'),
    actions: [
      TextButton(
        key: const Key('cancel-scanned-box-restore-button'),
        onPressed: _submitted ? null : () => Navigator.of(context).pop(false),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('confirm-scanned-box-restore-button'),
        onPressed: _submitted
            ? null
            : () {
                if (_submitted) return;
                setState(() => _submitted = true);
                Navigator.of(context).pop(true);
              },
        child: Text(context.l10n.restore),
      ),
    ],
  );
}
