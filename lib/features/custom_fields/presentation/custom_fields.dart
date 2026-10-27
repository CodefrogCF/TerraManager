import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';

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
  final booleans = <String, bool?>{};
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
      booleans.clear();
      snapshot = next;
      for (final t in editable) {
        final value = next.value(t.id);
        if (t.type == CustomFieldType.boolean) {
          booleans[t.id] = value as bool?;
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
    if (t.type == CustomFieldType.boolean) return booleans[t.id];
    final text = fields[t.id]!.text;
    if (text.trim().isEmpty) return null;
    return t.validate(
      t.type == CustomFieldType.number
          ? double.tryParse(text.trim().replaceAll(',', '.')) ?? text
          : t.type == CustomFieldType.date
          ? text.trim()
          : text,
    );
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

  void setBoolean(String id, bool? value) {
    booleans[id] = value;
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
  });
  final CustomFieldsController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            context.l10n.customFields,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
            for (final t in c.editable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: t.type == CustomFieldType.boolean
                    ? DropdownButtonFormField<String>(
                        key: ValueKey('custom-field-${t.id}'),
                        initialValue: c.booleans[t.id]?.toString() ?? '',
                        isExpanded: true,
                        itemHeight: null,
                        decoration: InputDecoration(labelText: t.label),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(context.l10n.customFieldUnset),
                          ),
                          DropdownMenuItem(
                            value: 'true',
                            child: Text(context.l10n.customFieldYes),
                          ),
                          DropdownMenuItem(
                            value: 'false',
                            child: Text(context.l10n.customFieldNo),
                          ),
                        ],
                        onChanged: !enabled
                            ? null
                            : (v) {
                                c.setBoolean(
                                  t.id,
                                  v == '' ? null : v == 'true',
                                );
                              },
                      )
                    : TextFormField(
                        key: ValueKey('custom-field-${t.id}'),
                        controller: c.fields[t.id],
                        enabled: enabled,
                        maxLines: t.type == CustomFieldType.text ? 3 : 1,
                        keyboardType: t.type == CustomFieldType.number
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              )
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: t.label,
                          helperText: t.type == CustomFieldType.date
                              ? 'YYYY-MM-DD'
                              : null,
                          suffixIcon: t.type == CustomFieldType.date
                              ? IconButton(
                                  tooltip: context.l10n.customFieldDate,
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: !enabled
                                      ? null
                                      : () async {
                                          final old = DateTime.tryParse(
                                            c.fields[t.id]!.text,
                                          );
                                          final now = DateTime.now();
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                old != null &&
                                                    old.year >= 1 &&
                                                    old.year <= 9999
                                                ? old
                                                : now,
                                            firstDate: DateTime(1),
                                            lastDate: DateTime(9999, 12, 31),
                                          );
                                          if (date != null) {
                                            c.fields[t.id]!.text =
                                                '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                          }
                                        },
                                )
                              : null,
                        ),
                        validator: (_) {
                          try {
                            c.read(t);
                            return null;
                          } catch (_) {
                            return context.l10n.customFieldInvalid;
                          }
                        },
                      ),
              ),
            TextButton.icon(
              key: const Key('manage-custom-fields'),
              onPressed: !enabled
                  ? null
                  : () async {
                      if (c.dirty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.customFieldsDirty),
                          ),
                        );
                        return;
                      }
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomFieldTemplatesPage(access: c.access),
                        ),
                      );
                      await c.load();
                    },
              icon: const Icon(Icons.tune),
              label: Text(context.l10n.customFieldsManage),
            ),
          ],
        ],
      );
    },
  );
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
              for (final t in s.data!.templates.where(
                (t) => !t.hidden && s.data!.value(t.id) != null,
              ))
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
              if (s.data!.values.every(
                (v) =>
                    v.value == null ||
                    !s.data!.templates.any(
                      (t) => t.id == v.templateId && !t.hidden,
                    ),
              ))
                Text(context.l10n.customFieldsEmpty),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomFieldTemplatesPage(access: widget.access),
                    ),
                  );
                  await reload();
                },
                icon: const Icon(Icons.tune),
                label: Text(context.l10n.customFieldsManage),
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
  late CustomFieldType _type = widget.initial?.type ?? CustomFieldType.text;
  late bool _hidden = widget.initial?.hidden ?? false,
      _archived = widget.initial?.archived ?? false;
  late final _id = widget.initial?.id ?? const Uuid().v4();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _label.dispose();
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
                      DropdownMenuItem(
                        value: t,
                        child: Text(customFieldTypeLabel(context, t)),
                      ),
                  ],
                  onChanged: widget.initial != null || _saving
                      ? null
                      : (v) => setState(() => _type = v!),
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
