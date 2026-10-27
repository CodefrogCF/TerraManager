import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/presentation/widgets/constrained_page_width.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../domain/care_event_type_definition.dart';

class CareEventTypesPage extends StatefulWidget {
  const CareEventTypesPage({
    super.key,
    required this.load,
    required this.create,
    required this.update,
    required this.reorder,
    this.updates,
  });
  final Future<List<CareEventTypeDefinition>> Function() load;
  final Future<void> Function(String id, String label) create;
  final Future<void> Function(
    CareEventTypeDefinition type,
    String label,
    bool archived,
  )
  update;
  final Future<void> Function(List<CareEventTypeDefinition> order) reorder;
  final Stream<Object?>? updates;
  @override
  State<CareEventTypesPage> createState() => CareEventTypesPageState();
}

class CareEventTypesPageState extends State<CareEventTypesPage> {
  late Future<List<CareEventTypeDefinition>> _future;
  StreamSubscription<Object?>? _updates;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
    _updates = widget.updates?.listen(
      (_) => unawaited(reload().catchError((Object _) {})),
    );
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    super.dispose();
  }

  Future<void> reload() async {
    final future = widget.load();
    if (mounted) {
      setState(() {
        _future = future;
      });
    }
    await future;
  }

  Future<void> _edit(
    List<CareEventTypeDefinition> types, [
    CareEventTypeDefinition? type,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TypeDialog(page: widget, types: types, existing: type),
    );
    if (saved == true && mounted) await reload().catchError((Object _) {});
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      await reload();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.careTypeSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive(CareEventTypeDefinition type) async {
    if (!type.archived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.careTypeArchiveConfirm),
          content: Text(context.l10n.careTypeArchiveHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.archive),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _mutate(() => widget.update(type, type.label, !type.archived));
  }

  void _move(List<CareEventTypeDefinition> types, int from, int to) {
    final order = [...types];
    final item = order.removeAt(from);
    order.insert(to, item);
    unawaited(_mutate(() => widget.reorder(order)));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(kToolbarHeight),
        title: Text(
          context.l10n.careTypes,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ConstrainedPageWidth(
        child: FutureBuilder<List<CareEventTypeDefinition>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.careTypeSaveFailed),
                    TextButton(
                      onPressed: () =>
                          unawaited(reload().catchError((Object _) {})),
                      child: Text(context.l10n.boxCareReload),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final types = snapshot.data!;
            final busy =
                _busy || snapshot.connectionState != ConnectionState.done;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(context.l10n.careTypesDescription),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('add-care-type'),
                    onPressed: busy ? null : () => _edit(types),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.careTypeAdd),
                  ),
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(reload().catchError((Object _) {})),
                    child: Text(context.l10n.boxCareReload),
                  ),
                ],
                if (types.isEmpty) Text(context.l10n.careTypesEmpty),
                for (final (index, type) in types.indexed)
                  Card(
                    key: ValueKey('care-type-${type.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (type.archived) Text(context.l10n.archived),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton.icon(
                                key: ValueKey('rename-care-type-${type.id}'),
                                onPressed: _busy
                                    ? null
                                    : () => _edit(types, type),
                                icon: const Icon(Icons.edit_outlined),
                                label: Text(context.l10n.careTypeRename),
                              ),
                              TextButton.icon(
                                key: ValueKey('archive-care-type-${type.id}'),
                                onPressed: busy ? null : () => _archive(type),
                                icon: Icon(
                                  type.archived
                                      ? Icons.unarchive_outlined
                                      : Icons.archive_outlined,
                                ),
                                label: Text(
                                  type.archived
                                      ? context.l10n.restore
                                      : context.l10n.archive,
                                ),
                              ),
                              IconButton(
                                key: ValueKey('care-type-up-${type.id}'),
                                tooltip: context.l10n.careTypeMoveUp,
                                onPressed: busy || index == 0
                                    ? null
                                    : () => _move(types, index, index - 1),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                key: ValueKey('care-type-down-${type.id}'),
                                tooltip: context.l10n.careTypeMoveDown,
                                onPressed: busy || index == types.length - 1
                                    ? null
                                    : () => _move(types, index, index + 1),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _TypeDialog extends StatefulWidget {
  const _TypeDialog({required this.page, required this.types, this.existing});
  final CareEventTypesPage page;
  final List<CareEventTypeDefinition> types;
  final CareEventTypeDefinition? existing;
  @override
  State<_TypeDialog> createState() => _TypeDialogState();
}

class _TypeDialogState extends State<_TypeDialog> {
  final _form = GlobalKey<FormState>();
  final _id = const Uuid().v4();
  late final _label = TextEditingController(text: widget.existing?.label);
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
      final label = CareEventTypeDefinition.normalizeLabel(_label.text);
      final existing = widget.existing;
      if (existing == null) {
        await widget.page.create(_id, label);
      } else {
        await widget.page.update(existing, label, existing.archived);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.careTypeSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text(
        widget.existing == null
            ? context.l10n.careTypeAdd
            : context.l10n.careTypeRename,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('care-type-label'),
                  controller: _label,
                  enabled: !_saving,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: context.l10n.careTypeLabel,
                    errorMaxLines: 6,
                  ),
                  validator: (value) {
                    try {
                      final key = CareEventTypeDefinition.labelKey(value ?? '');
                      if (widget.types.any(
                        (t) =>
                            t.id != widget.existing?.id &&
                            CareEventTypeDefinition.labelKey(t.label) == key,
                      )) {
                        return context.l10n.careTypeDuplicate;
                      }
                    } on ArgumentError {
                      return context.l10n.careTypeInvalid;
                    }
                    return null;
                  },
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
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('save-care-type'),
          onPressed: _saving ? null : _save,
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}
