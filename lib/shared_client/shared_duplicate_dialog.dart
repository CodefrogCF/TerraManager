import 'package:flutter/material.dart';

import '../l10n/app_localizations_context.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_text.dart';

Future<bool?> showSharedDuplicateDialog(
  BuildContext context, {
  required SharedApiClient api,
  required SharedChange change,
  required Map<String, dynamic> source,
  List<Map<String, dynamic>>? boxes,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _DuplicateDialog(api: api, change: change, source: source, boxes: boxes),
);

class _DuplicateDialog extends StatefulWidget {
  const _DuplicateDialog({
    required this.api,
    required this.change,
    required this.source,
    this.boxes,
  });
  final SharedApiClient api;
  final SharedChange change;
  final Map<String, dynamic> source;
  final List<Map<String, dynamic>>? boxes;
  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text:
        (widget.source[widget.boxes == null ? 'name' : 'commonName']
            as String?) ??
        '',
  );
  late final _boxes =
      widget.boxes?.where((box) => box['status'] == 'active').toList() ?? [];
  late int? _boxId = _boxes.any((box) => box['id'] == widget.source['boxId'])
      ? widget.source['boxId'] as int?
      : _boxes.firstOrNull?['id'] as int?;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    Object? failure;
    final saved = await widget.change(() async {
      try {
        if (widget.boxes == null) {
          await widget.api.duplicateBox(
            recordId(widget.source),
            _name.text.trim(),
          );
        } else {
          await widget.api.duplicateAnimal(
            recordId(widget.source),
            _boxId!,
            _name.text.trim(),
          );
        }
      } catch (error) {
        failure = error;
        rethrow;
      }
    });
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = failure is SharedConnectionException
          ? sharedText(
              context,
              'Connection lost. Reload the collection before trying again; the server may have received the request.',
              'Verbindung verloren. Lade die Sammlung vor einem neuen Versuch neu; der Server könnte die Anfrage erhalten haben.',
            )
          : failure is SharedApiException &&
                (failure as SharedApiException).status == 403
          ? sharedText(
              context,
              'You do not have permission to duplicate this record.',
              'Dir fehlt die Berechtigung zum Duplizieren.',
            )
          : sharedText(
              context,
              'Duplication failed. Check the name, destination Box and server state.',
              'Duplizieren fehlgeschlagen. Prüfe Name, Zielbox und Serverstand.',
            );
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.boxes == null
            ? context.l10n.duplicateBox
            : context.l10n.duplicateAnimal,
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('duplicate-name'),
                controller: _name,
                enabled: !_busy,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: sharedText(context, 'Name', 'Name'),
                ),
                validator: (value) => value?.trim().isEmpty ?? true
                    ? sharedText(
                        context,
                        'Enter a name.',
                        'Gib einen Namen ein.',
                      )
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (widget.boxes != null)
                DropdownButtonFormField<int>(
                  key: const Key('duplicate-destination-box'),
                  initialValue: _boxId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: sharedText(
                      context,
                      'Destination Box',
                      'Zielbox',
                    ),
                  ),
                  items: [
                    for (final box in _boxes)
                      DropdownMenuItem(
                        value: recordId(box),
                        child: Text(
                          boxLabel(box),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _boxId = value),
                  validator: (value) => value == null
                      ? sharedText(
                          context,
                          'Select an active Box.',
                          'Wähle eine aktive Box.',
                        )
                      : null,
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('duplicate-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
        ),
        FilledButton(
          key: const Key('confirm-shared-duplicate'),
          onPressed: _busy ? null : _submit,
          child: Text(sharedText(context, 'Duplicate', 'Duplizieren')),
        ),
      ],
    ),
  );
}
