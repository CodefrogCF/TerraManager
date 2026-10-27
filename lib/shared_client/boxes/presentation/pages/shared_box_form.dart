import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';
import 'package:terramanager/shared_client/custom_fields/presentation/shared_custom_fields.dart';
import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_creation_picture_field.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';
import 'package:uuid/uuid.dart';

class SharedBoxForm extends StatefulWidget {
  const SharedBoxForm({
    super.key,
    required this.api,
    required this.change,
    this.initial,
    this.pictureSelectionFlow,
  });
  final SharedApiClient api;
  final SharedChange change;
  final Map<String, dynamic>? initial;
  final PictureSelectionFlow? pictureSelectionFlow;

  @override
  State<SharedBoxForm> createState() => _SharedBoxFormState();
}

class _SharedBoxFormState extends State<SharedBoxForm> {
  final _form = GlobalKey<FormState>();
  late final _custom = CustomFieldsController(
    sharedCustomFields(
      widget.api,
      CustomFieldTarget.box,
      widget.initial?['id'] as int?,
    ),
  );
  late final Map<String, TextEditingController> _fields;
  Map<String, dynamic>? _initial;
  bool _saving = false;
  bool _stale = false;
  String? _error;
  SelectedPicture? _picture;
  String? _pictureRequestId;
  Map<String, dynamic>? _created;
  bool _processingPicture = false;

  @override
  void initState() {
    super.initState();
    _custom.load();
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
    _custom.dispose();
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
    if (_saving || _processingPicture || !widget.api.connected) return;
    if (_created != null) {
      await _persist(const {});
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final customPatch = _custom.patch;
    final values = <String, dynamic>{
      if (customPatch != null) 'customFields': customPatch.toJson(),
      'name': _text('name'),
      'widthCm': _number('widthCm'),
      'heightCm': _number('heightCm'),
      'depthCm': _number('depthCm'),
      'temperatureZones': _text('temperatureZones'),
      'notes': _text('notes'),
    };
    await _persist(values);
  }

  Future<void> _persist(Map<String, dynamic> values) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.change(() async {
      if (_initial == null) {
        // Preserve a confirmed create across upload failures and retry only the
        // same picture request. Its result may already have committed.
        _created ??= await widget.api.createBox(values);
        final picture = _picture;
        if (picture != null) {
          await widget.api.addPicture(
            'boxes',
            recordId(_created!),
            picture.fileName,
            picture.mimeType,
            picture.bytes,
            requestId: _pictureRequestId!,
          );
        }
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
        _error = _created != null
            ? sharedText(
                context,
                'The Box was created, but its picture could not be confirmed. Retry the picture or finish and check its gallery.',
                'Die Box wurde angelegt, aber das Bild konnte nicht bestätigt werden. Wiederhole die Bildübertragung oder schließe ab und prüfe die Galerie.',
              )
            : _stale
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
      await _custom.load();
      if (!mounted) return;
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
            canPop: !_saving && _created == null,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && !_saving && _created != null) {
                Navigator.of(context).pop(true);
              }
            },
            child: IgnorePointer(
              ignoring: _saving || _processingPicture,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.initial == null)
                    SharedCreationPictureField(
                      picture: _picture,
                      pictureSelectionFlow: widget.pictureSelectionFlow,
                      enabled:
                          widget.api.connected && !_saving && _created == null,
                      onChanged: (picture) => setState(() {
                        _picture = picture;
                        _pictureRequestId = picture == null
                            ? null
                            : const Uuid().v4();
                      }),
                      onProcessingChanged: (processing) =>
                          setState(() => _processingPicture = processing),
                    ),
                  if (_created == null) ...[
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
                  ] else
                    Text(
                      _created!['name']?.toString() ?? _fields['name']!.text,
                    ),
                  if (_created == null)
                    CustomFieldsEditor(
                      controller: _custom,
                      enabled: !_saving && widget.api.connected,
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
                  if (_created != null)
                    TextButton(
                      key: const Key('shared-creation-finish'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(true),
                      child: Text(
                        sharedText(
                          context,
                          'Finish for now',
                          'Vorerst abschließen',
                        ),
                      ),
                    ),
                  if (_saving) const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('shared-save-box'),
                    onPressed:
                        widget.api.connected &&
                            !_saving &&
                            !_processingPicture &&
                            !_stale
                        ? _save
                        : null,
                    child: Text(
                      _created == null
                          ? sharedText(context, 'Save', 'Speichern')
                          : sharedText(
                              context,
                              'Retry picture',
                              'Bild erneut übertragen',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
