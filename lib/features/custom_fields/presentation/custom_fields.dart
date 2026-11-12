import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';

import '../../../core/database/date_only.dart';
import '../domain/custom_field.dart';
export '../domain/custom_field.dart';

class CustomFieldAccess {
  const CustomFieldAccess({
    required this.target,
    required this.load,
    required this.templates,
    required this.saveTemplate,
  });
  final CustomFieldTarget target;
  final Future<CustomFieldsSnapshot> Function() load;
  final Future<List<CustomFieldTemplate>> Function() templates;
  final Future<void> Function(CustomFieldTemplate, {required bool creating})
  saveTemplate;
}

String customFieldTypeLabel(BuildContext c, CustomFieldType type) =>
    switch (type) {
      CustomFieldType.text => c.l10n.customFieldText,
      CustomFieldType.number => c.l10n.customFieldNumber,
      CustomFieldType.date => c.l10n.customFieldDate,
      CustomFieldType.boolean => c.l10n.customFieldBoolean,
      CustomFieldType.integer => c.l10n.customFieldInteger,
      CustomFieldType.choice => c.l10n.customFieldChoice,
    };
String customFieldDisplay(BuildContext c, CustomFieldTemplate t, Object value) {
  if (t.type == CustomFieldType.boolean) {
    return value == true ? c.l10n.customFieldYes : c.l10n.customFieldNo;
  }
  if (t.type == CustomFieldType.date) {
    return MaterialLocalizations.of(c)
        .formatMediumDate(DateTime.parse(value as String));
  }
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// Owns only custom-field drafts; core forms retain their existing save flow.
class CustomFieldsController extends ChangeNotifier {
  CustomFieldsController(this.access);
  final CustomFieldAccess access;
  CustomFieldsSnapshot? snapshot;
  bool loading = false, failed = false, _disposed = false;
  final fields = <String, TextEditingController>{};
  final selections = <String, Object?>{};
  int appliedDefaults = 0;
  Iterable<CustomFieldTemplate> get editable =>
      snapshot?.templates.where((t) => !t.hidden && !t.archived) ?? const [];
  Future<void> load() async {
    if (_disposed) return;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final next = await access.load();
      if (_disposed) return;
      for (final c in fields.values) {
        c.dispose();
      }
      fields.clear();
      selections.clear();
      snapshot = next;
      for (final t in editable) {
        final value = next.value(t.id);
        if (t.type.usesSelection) {
          selections[t.id] = value;
        } else {
          fields[t.id] = TextEditingController(text: value?.toString() ?? '')
            ..addListener(notifyListeners);
        }
      }
    } catch (_) {
      if (!_disposed) failed = true;
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Object? read(CustomFieldTemplate t) {
    if (t.type.usesSelection) return selections[t.id];
    final text = fields[t.id]!.text;
    if (text.trim().isEmpty) return null;
    return t.validate(switch (t.type) {
      CustomFieldType.number =>
        double.tryParse(text.trim().replaceAll(',', '.')) ?? text,
      CustomFieldType.integer => int.tryParse(text.trim(), radix: 10) ?? text,
      CustomFieldType.date => text.trim(),
      _ => text,
    });
  }

  bool get dirty {
    for (final t in editable) {
      try {
        if (!sameFieldValue(read(t), snapshot!.value(t.id))) return true;
      } catch (_) {
        return true;
      }
    }
    return false;
  }

  CustomFieldPatch? get patch {
    if (snapshot == null || !dirty) return null;
    return CustomFieldPatch(
      expectedRevision: snapshot!.revision,
      updates: [
        for (final t in editable)
          if (!sameFieldValue(read(t), snapshot!.value(t.id)))
            (id: t.id, templateRevision: t.revision, value: read(t)),
      ],
    );
  }

  void setSelection(String id, Object? value) {
    selections[id] = value;
    notifyListeners();
  }

  Map<String, Object> get populatedValues => {
    for (final template in editable) template.id: ?read(template),
  };

  void applyDefaults(Map<String, Object?> defaults) {
    appliedDefaults++;
    for (final template in editable) {
      if (!defaults.containsKey(template.id)) continue;
      final value = template.validate(defaults[template.id]);
      if (template.type.usesSelection) {
        selections[template.id] = value;
      } else {
        fields[template.id]!.text = value?.toString() ?? '';
      }
    }
    notifyListeners();
  }

  void conflict() {
    failed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }
}

class CustomFieldsEditor extends StatelessWidget {
  const CustomFieldsEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.showManagement = true,
    this.compact = false,
  });
  final CustomFieldsController controller;
  final bool enabled;
  final bool showManagement;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.customFields,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          if (c.loading) const LinearProgressIndicator(),
          if (c.failed) ...[
            Text(
              context.l10n.customFieldsFailure,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: enabled ? c.load : null,
              child: Text(context.l10n.customFieldsReload),
            ),
          ],
          if (!c.loading && c.snapshot != null) ...[
            if (compact)
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final twoColumns =
                      width >= 304 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final template in c.editable)
                        SizedBox(
                          key: ValueKey((template.id, c.appliedDefaults)),
                          width: twoColumns ? (width - 12) / 2 : width,
                          child: _CustomFieldInput(
                            controller: c,
                            template: template,
                            enabled: enabled,
                            compact: true,
                          ),
                        ),
                    ],
                  );
                },
              )
            else
              for (final template in c.editable)
                Padding(
                  key: ValueKey((template.id, c.appliedDefaults)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _CustomFieldInput(
                    controller: c,
                    template: template,
                    enabled: enabled,
                    compact: false,
                  ),
                ),
            if (showManagement)
              CustomFieldTemplatesButton(controller: c, enabled: enabled),
          ],
        ],
      );
    },
  );
}

class CustomFieldTemplatesButton extends StatelessWidget {
  const CustomFieldTemplatesButton({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final CustomFieldsController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('manage-custom-fields'),
    onPressed: !enabled
        ? null
        : () async {
            if (controller.dirty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.customFieldsDirty)),
              );
              return;
            }
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    CustomFieldTemplatesPage(access: controller.access),
              ),
            );
            await controller.load();
          },
    icon: const Icon(Icons.tune),
    label: Text(context.l10n.customFieldsManage),
  );
}

class _CustomFieldInput extends StatelessWidget {
  const _CustomFieldInput({
    required this.controller,
    required this.template,
    required this.enabled,
    required this.compact,
  });

  final CustomFieldsController controller;
  final CustomFieldTemplate template;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey('custom-field-${template.id}');
    final type = template.type;
    final decoration = InputDecoration(
      labelText: template.label,
      isDense: compact ? true : null,
    );
    if (type.usesSelection) {
      final current = controller.selections[template.id]?.toString() ?? '';
      final labels = {
        '': context.l10n.customFieldUnset,
        if (type == CustomFieldType.boolean) ...{
          'true': context.l10n.customFieldYes,
          'false': context.l10n.customFieldNo,
        } else
          for (final option in template.options) option: option,
      };
      final unavailable = !labels.containsKey(current);
      if (unavailable) {
        labels[current] = context.l10n.customFieldChoiceUnavailable(current);
      }
      return DropdownButtonFormField<String>(
        key: key,
        initialValue: current,
        isExpanded: true,
        itemHeight: null,
        decoration: decoration,
        selectedItemBuilder: (context) => [
          for (final label in labels.values)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        items: [
          for (final entry in labels.entries)
            DropdownMenuItem(
              value: entry.key,
              enabled: !unavailable || entry.key != current,
              child: Text(entry.value),
            ),
        ],
        onChanged: !enabled
            ? null
            : (value) => controller.setSelection(
                template.id,
                value == ''
                    ? null
                    : type == CustomFieldType.boolean
                    ? value == 'true'
                    : value,
              ),
      );
    }
    final text = controller.fields[template.id]!;
    return TextFormField(
      key: key,
      controller: text,
      enabled: enabled,
      minLines: compact ? 1 : null,
      maxLines: type == CustomFieldType.text ? 3 : 1,
      keyboardType: switch (type) {
        CustomFieldType.number => const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        CustomFieldType.integer => const TextInputType.numberWithOptions(
          signed: true,
        ),
        _ => TextInputType.text,
      },
      decoration: type == CustomFieldType.date
          ? decoration.copyWith(
              helperText: 'YYYY-MM-DD',
              suffixIcon: IconButton(
                tooltip: context.l10n.customFieldDate,
                icon: const Icon(Icons.calendar_today),
                onPressed: enabled ? () => _pickDate(context, text) : null,
              ),
            )
          : decoration,
      validator: (_) {
        try {
          controller.read(template);
          return null;
        } on ArgumentError {
          return type == CustomFieldType.integer
              ? context.l10n.customFieldIntegerInvalid
              : context.l10n.customFieldInvalid;
        }
      },
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController text,
  ) async {
    final old = DateTime.tryParse(text.text);
    final date = await showDatePicker(
      context: context,
      initialDate: old != null && old.year >= 1 && old.year <= 9999
          ? old
          : DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (date != null && context.mounted) {
      text.text = dateOnlyString(date)!;
    }
  }
}

class CustomFieldsSection extends StatefulWidget {
  const CustomFieldsSection({super.key, required this.access, this.updates});
  final CustomFieldAccess access;
  final Stream<Object?>? updates;
  @override
  State<CustomFieldsSection> createState() => CustomFieldsSectionState();
}

class CustomFieldsSectionState extends State<CustomFieldsSection> {
  late Future<CustomFieldsSnapshot> _future;
  StreamSubscription<Object?>? _subscription;
  @override
  void initState() {
    super.initState();
    _future = widget.access.load();
    _subscription = widget.updates?.listen((_) {
      unawaited(reload());
    });
  }

  Future<void> reload() async {
    if (!mounted) return;
    final f = widget.access.load();
    setState(() {
      _future = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CustomFieldsSnapshot>(
    future: _future,
    builder: (context, s) {
      if (!s.hasData && !s.hasError) return const SizedBox.shrink();
      final visibleFields =
          s.data?.templates
              .where((t) => !t.hidden && s.data!.value(t.id) != null)
              .toList() ??
          const <CustomFieldTemplate>[];
      if (!s.hasError && visibleFields.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.customFields,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (s.hasError) ...[
              Text(context.l10n.customFieldsFailure),
              TextButton(
                onPressed: reload,
                child: Text(context.l10n.customFieldsReload),
              ),
            ],
            if (s.hasData) ...[
              for (final t in visibleFields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.label}${t.archived ? ' (${context.l10n.archived})' : ''}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SelectableText(
                        customFieldDisplay(context, t, s.data!.value(t.id)!),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class CustomFieldTemplatesPage extends StatefulWidget {
  const CustomFieldTemplatesPage({super.key, required this.access});
  final CustomFieldAccess access;
  @override
  State<CustomFieldTemplatesPage> createState() => _TemplatesState();
}

class _TemplatesState extends State<CustomFieldTemplatesPage> {
  late Future<List<CustomFieldTemplate>> _future = widget.access.templates();
  Future<void> _edit([CustomFieldTemplate? template]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TemplateDialog(access: widget.access, initial: template),
    );
    if (mounted) {
      setState(() {
        _future = widget.access.templates();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.customFieldTemplates)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: FutureBuilder<List<CustomFieldTemplate>>(
          future: _future,
          builder: (context, s) {
            if (s.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _future = widget.access.templates();
                  }),
                  child: Text(context.l10n.customFieldsReload),
                ),
              );
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                Text(context.l10n.customFieldPreserve),
                const SizedBox(height: 12),
                for (final t in s.data!)
                  ListTile(
                    key: ValueKey('field-template-${t.id}'),
                    title: Text(t.label),
                    subtitle: Text(
                      [
                        customFieldTypeLabel(context, t.type),
                        if (t.hidden) context.l10n.customFieldHidden,
                        if (t.archived) context.l10n.archived,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(t),
                  ),
              ],
            );
          },
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      key: const Key('add-field-template'),
      onPressed: _edit,
      tooltip: context.l10n.customFieldAdd,
      child: const Icon(Icons.add),
    ),
  );
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.access, this.initial});
  final CustomFieldAccess access;
  final CustomFieldTemplate? initial;
  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.initial?.label);
  late final _options = TextEditingController(
    text: widget.initial?.options.join('\n'),
  );
  late CustomFieldType _type = widget.initial?.type ?? CustomFieldType.text;
  late bool _hidden = widget.initial?.hidden ?? false,
      _archived = widget.initial?.archived ?? false;
  late final _id = widget.initial?.id ?? const Uuid().v4();
  bool _saving = false;
  String? _error;
  Iterable<String> get _optionLines => _options.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.access.saveTemplate(
        CustomFieldTemplate(
          id: _id,
          target: widget.access.target,
          type: _type,
          label: _label.text,
          options: _type == CustomFieldType.choice
              ? CustomFieldTemplate.normalizeOptions(_optionLines)
              : const [],
          hidden: _hidden,
          archived: _archived,
          revision: widget.initial?.revision ?? 1,
        ),
        creating: widget.initial == null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.customFieldTemplateFailure);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(context.l10n.customFieldTemplates),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('field-template-label'),
                  controller: _label,
                  enabled: !_saving,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: context.l10n.customFieldLabel,
                  ),
                  validator: (v) {
                    try {
                      CustomFieldTemplate.normalizeLabel(v ?? '');
                      return null;
                    } catch (_) {
                      return context.l10n.customFieldLabelInvalid;
                    }
                  },
                ),
                DropdownButtonFormField<CustomFieldType>(
                  key: const Key('field-template-type'),
                  initialValue: _type,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: context.l10n.customFieldType,
                  ),
                  items: [
                    for (final t in CustomFieldType.values)
                      if (t.supports(widget.access.target))
                        DropdownMenuItem(
                          value: t,
                          child: Text(customFieldTypeLabel(context, t)),
                        ),
                  ],
                  onChanged: widget.initial != null || _saving
                      ? null
                      : (v) => setState(() => _type = v!),
                ),
                if (_type == CustomFieldType.choice)
                  TextFormField(
                    key: const Key('field-template-options'),
                    controller: _options,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: context.l10n.customFieldOptions,
                      helperText: context.l10n.customFieldOptionsHelp,
                      helperMaxLines: 2,
                    ),
                    validator: (_) {
                      try {
                        CustomFieldTemplate.normalizeOptions(_optionLines);
                        return null;
                      } on ArgumentError {
                        return context.l10n.customFieldOptionsInvalid;
                      }
                    },
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.customFieldHidden),
                  value: _hidden,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _hidden = v),
                ),
                if (widget.initial != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.customFieldArchived),
                    value: _archived,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _archived = v),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-field-template'),
          onPressed: _saving ? null : _save,
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}
