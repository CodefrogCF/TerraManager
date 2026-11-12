import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:uuid/uuid.dart';

import '../../domain/food_preset.dart';
import '../widgets/feeding_details_access.dart';

class FoodPresetsPage extends StatefulWidget {
  const FoodPresetsPage({super.key, required this.access});

  final FeedingDetailsAccess access;

  @override
  State<FoodPresetsPage> createState() => _FoodPresetsPageState();
}

typedef _PresetData = ({
  List<FoodPreset> presets,
  List<CustomFieldTemplate> templates,
});

class _FoodPresetsPageState extends State<FoodPresetsPage> {
  late Future<_PresetData> _data = _load();

  Future<_PresetData> _load() async => (
    presets: await widget.access.presets(),
    templates: await widget.access.fields.templates(),
  );

  Future<void> _edit(
    List<CustomFieldTemplate> templates, [
    FoodPreset? preset,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FoodPresetDialog(
        access: widget.access,
        templates: templates,
        initial: preset,
      ),
    );
    if (mounted && saved == true) {
      setState(() {
        _data = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedPageWidth(
    child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.foodPresetsManage)),
      body: FutureBuilder<_PresetData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _data = _load();
                }),
                child: Text(context.l10n.foodPresetsRetry),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final hasFields = data.templates.any(
            (field) => !field.hidden && !field.archived,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasFields)
                ListTile(
                  key: const Key('add-food-preset'),
                  leading: const Icon(Icons.add),
                  title: Text(context.l10n.foodPresetAdd),
                  onTap: () => _edit(data.templates),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.l10n.foodPresetNeedsTemplates),
                ),
              for (final preset in data.presets)
                ListTile(
                  key: ValueKey('food-preset-${preset.id}'),
                  title: Text(preset.name),
                  subtitle: preset.archived
                      ? Text(context.l10n.archived)
                      : null,
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(data.templates, preset),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _FoodPresetDialog extends StatefulWidget {
  const _FoodPresetDialog({
    required this.access,
    required this.templates,
    this.initial,
  });

  final FeedingDetailsAccess access;
  final List<CustomFieldTemplate> templates;
  final FoodPreset? initial;

  @override
  State<_FoodPresetDialog> createState() => _FoodPresetDialogState();
}

class _FoodPresetDialogState extends State<_FoodPresetDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _id = widget.initial?.id ?? const Uuid().v4();
  late bool _archived = widget.initial?.archived ?? false;
  late final CustomFieldsController _fields;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final access = widget.access.fields;
    _fields = CustomFieldsController(
      CustomFieldAccess(
        target: access.target,
        templates: access.templates,
        saveTemplate: access.saveTemplate,
        load: () async => CustomFieldsSnapshot(
          templates: widget.templates,
          values: [
            for (final entry
                in (widget.initial?.defaults ?? const <String, Object?>{})
                    .entries)
              CustomFieldValue(entry.key, entry.value),
          ],
        ),
      ),
    );
    unawaited(_fields.load());
  }

  Future<void> _save() async {
    if (_saving || _fields.loading || !_form.currentState!.validate()) return;
    final editable = _fields.editable.map((template) => template.id).toSet();
    final defaults = {
      for (final entry
          in (widget.initial?.defaults ?? const <String, Object?>{}).entries)
        if (!editable.contains(entry.key)) entry.key: entry.value,
      ..._fields.populatedValues,
    };
    if (defaults.isEmpty) {
      setState(() => _error = context.l10n.foodPresetNeedsValues);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.access.savePreset(
        FoodPreset(
          id: _id,
          name: _name.text,
          defaults: defaults,
          archived: _archived,
          revision: widget.initial?.revision ?? 1,
        ),
        creating: widget.initial == null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.foodPresetSaveFailed;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.initial == null
            ? context.l10n.foodPresetAdd
            : context.l10n.foodPresetEdit,
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('food-preset-name'),
                controller: _name,
                enabled: !_saving,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: context.l10n.foodPresetName,
                ),
                validator: (value) {
                  try {
                    CustomFieldTemplate.normalizeLabel(value ?? '');
                    return null;
                  } on ArgumentError {
                    return context.l10n.foodPresetNameInvalid;
                  }
                },
              ),
              CustomFieldsEditor(
                controller: _fields,
                enabled: !_saving,
                showManagement: false,
              ),
              if (widget.initial != null)
                SwitchListTile(
                  key: const Key('archive-food-preset'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.archived),
                  value: _archived,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _archived = value),
                ),
              if (_error case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-food-preset'),
          onPressed: _saving ? null : _save,
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}
