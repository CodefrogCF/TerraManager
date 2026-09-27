import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

class SharedBoxForm extends StatefulWidget {
  const SharedBoxForm({
    super.key,
    required this.api,
    required this.change,
    this.initial,
  });
  final SharedApiClient api;
  final SharedChange change;
  final Map<String, dynamic>? initial;

  @override
  State<SharedBoxForm> createState() => _SharedBoxFormState();
}

class _SharedBoxFormState extends State<SharedBoxForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  Map<String, dynamic>? _initial;
  bool _saving = false;
  bool _stale = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initial = widget.initial;
    _fields = {
      for (final key in [
        'name',
        'widthCm',
        'heightCm',
        'depthCm',
        'temperatureZones',
        'notes',
      ])
        key: TextEditingController(
          text: widget.initial?[key]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _text(String key) {
    final value = _fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _number(String key) {
    final value = _text(key);
    return value == null ? null : double.tryParse(value.replaceAll(',', '.'));
  }

  String? _positive(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null || !number.isFinite || number <= 0) {
      return sharedText(
        context,
        'Enter a positive number.',
        'Positive Zahl eingeben.',
      );
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !widget.api.connected || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final values = <String, dynamic>{
      'name': _text('name'),
      'widthCm': _number('widthCm'),
      'heightCm': _number('heightCm'),
      'depthCm': _number('depthCm'),
      'temperatureZones': _text('temperatureZones'),
      'notes': _text('notes'),
    };
    final saved = await widget.change(() async {
      if (_initial == null) {
        await widget.api.createBox(values);
      } else {
        await widget.api.updateBox(
          recordId(_initial!),
          values,
          _initial!['revision'] as String,
        );
      }
    });
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _stale =
            widget.api.lastFailure is SharedApiException &&
            (widget.api.lastFailure as SharedApiException).code ==
                'stale_record';
        _error = _stale
            ? sharedText(
                context,
                'This Box changed on the server. Reload and review the new values before saving.',
                'Diese Box wurde auf dem Server geändert. Lade die neuen Werte und prüfe sie vor dem Speichern.',
              )
            : sharedText(
                context,
                'The result is uncertain. Reload and check the server data.',
                'Das Ergebnis ist unklar. Neu laden und Serverdaten prüfen.',
              );
      });
    }
  }

  Future<void> _reloadLatest() async {
    if (_initial == null || !widget.api.connected) return;
    try {
      final latest = await widget.api.box(recordId(_initial!));
      if (!mounted) return;
      if (latest['status'] != 'active') {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() {
        _initial = latest;
        for (final entry in _fields.entries) {
          entry.value.text = latest[entry.key]?.toString() ?? '';
        }
        _stale = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = sharedText(
            context,
            'Could not reload the Box.',
            'Die Box konnte nicht neu geladen werden.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedPageWidth(
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? sharedText(context, 'New Box', 'Neue Box')
              : sharedText(context, 'Edit Box', 'Box bearbeiten'),
        ),
      ),
      body: ConstrainedPageWidth(
        maxWidth: 760,
        child: ListenableBuilder(
          listenable: widget.api,
          builder: (context, _) => Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _fields['name'],
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: sharedText(context, 'Name', 'Name'),
                  ),
                ),
                for (final entry in [
                  ('widthCm', 'Width (cm)', 'Breite (cm)'),
                  ('heightCm', 'Height (cm)', 'Höhe (cm)'),
                  ('depthCm', 'Depth (cm)', 'Tiefe (cm)'),
                ])
                  TextFormField(
                    controller: _fields[entry.$1],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positive,
                    decoration: InputDecoration(
                      labelText: sharedText(context, entry.$2, entry.$3),
                    ),
                  ),
                TextFormField(
                  controller: _fields['temperatureZones'],
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: sharedText(
                      context,
                      'Temperature zones',
                      'Temperaturzonen',
                    ),
                  ),
                ),
                TextFormField(
                  controller: _fields['notes'],
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: sharedText(context, 'Notes', 'Notizen'),
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_stale)
                  TextButton.icon(
                    onPressed: widget.api.connected ? _reloadLatest : null,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      sharedText(
                        context,
                        'Reload and review',
                        'Neu laden und prüfen',
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('shared-save-box'),
                  onPressed: widget.api.connected && !_saving && !_stale
                      ? _save
                      : null,
                  child: Text(sharedText(context, 'Save', 'Speichern')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
