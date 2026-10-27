import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/presentation/widgets/constrained_page_width.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/box_care_entry.dart';
import '../../domain/care_event_type_definition.dart';

String boxCareTypeLabel(
  AppLocalizations text,
  BoxCareEventType type, [
  String? customLabel,
]) => switch (type) {
  BoxCareEventType.substrateChange => text.boxCareSubstrate,
  BoxCareEventType.cleaning => text.boxCareCleaning,
  BoxCareEventType.waterChange => text.boxCareWater,
  BoxCareEventType.custom => customLabel ?? text.careTypeUnavailable,
};

class BoxCareHistoryData {
  const BoxCareHistoryData({
    required this.entries,
    required this.active,
    this.canDelete = true,
    this.types = const [],
  });
  final List<BoxCareEntry> entries;
  final bool active;
  final bool canDelete;
  final List<CareEventTypeDefinition> types;
}

typedef SaveBoxCare = Future<bool> Function({
  BoxCareEntry? existing,
  required BoxCareEventType type,
  String? customTypeId,
  required DateTime occurredAt,
  String? notes,
  required String requestId,
});

/// Shared presentation for Standalone and Shared Care; persistence is injected.
class BoxCareHistoryPage extends StatefulWidget {
  const BoxCareHistoryPage({
    super.key,
    required this.boxLabel,
    required this.load,
    required this.save,
    required this.delete,
    this.manageTypes,
    this.updates,
  });
  final String boxLabel;
  final Future<BoxCareHistoryData> Function() load;
  final SaveBoxCare save;
  final Future<bool> Function(BoxCareEntry entry) delete;
  final Stream<Object?>? updates;
  final Future<void> Function()? manageTypes;
  @override
  State<BoxCareHistoryPage> createState() => BoxCareHistoryPageState();
}

class BoxCareHistoryPageState extends State<BoxCareHistoryPage> {
  late Future<BoxCareHistoryData> _future;
  StreamSubscription<Object?>? _updates;
  bool _deleting = false;
  bool _managingTypes = false;
  bool get _busy => _deleting || _managingTypes;
  String _filterId = '';
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

  Future<void> _manageTypes() async {
    final manage = widget.manageTypes;
    if (manage == null || _busy) return;
    setState(() {
      _managingTypes = true;
      _error = null;
    });
    try {
      await manage();
      if (mounted) await reload();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.careTypeSaveFailed);
    } finally {
      if (mounted) setState(() => _managingTypes = false);
    }
  }

  Future<void> _edit(BoxCareHistoryData data, [BoxCareEntry? entry]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _CareDialog(page: widget, entry: entry, types: data.types),
    );
    if (saved == true && mounted) await reload().catchError((Object _) {});
  }

  Future<void> _delete(BoxCareEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.boxCareDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      if (!await widget.delete(entry)) throw StateError('Care deletion failed');
      await reload();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.boxCareFailed);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.boxCareHistory)),
      body: ConstrainedPageWidth(
        maxWidth: 760,
        child: FutureBuilder<BoxCareHistoryData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.boxCareFailed),
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
            final data = snapshot.data!;
            final choices = <String, String>{
              '': context.l10n.careTypeAll,
              for (final type in BoxCareEventType.builtIn)
                type.name: boxCareTypeLabel(context.l10n, type),
              for (final type in data.types)
                type.id:
                    '${type.label}${type.archived ? ' (${context.l10n.archived})' : ''}',
            };
            final filter = choices.containsKey(_filterId) ? _filterId : '';
            final entries =
                data.entries
                    .where((e) => filter.isEmpty || e.choiceId == filter)
                    .toList()
                  ..sort((a, b) {
                    final time = b.occurredAt.compareTo(a.occurredAt);
                    return time == 0 ? b.id.compareTo(a.id) : time;
                  });
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    Text(
                      widget.boxLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(context.l10n.boxCareScope),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.l10n.careTypeFilter,
                        border: const OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('box-care-filter'),
                          value: filter,
                          isExpanded: true,
                          itemHeight: null,
                          items: [
                            for (final choice in choices.entries)
                              DropdownMenuItem(
                                value: choice.key,
                                child: Text(choice.value),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _filterId = value ?? ''),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.manageTypes != null)
                          TextButton.icon(
                            key: const Key('manage-care-types'),
                            onPressed: _busy ? null : _manageTypes,
                            icon: const Icon(Icons.category_outlined),
                            label: Text(context.l10n.careTypes),
                          ),
                      ],
                    ),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(context.l10n.boxCareEmpty),
                      ),
                    for (var index = 0; index < entries.length; index++) ...[
                      if (index > 0) const Divider(),
                      _historyTile(context, data, entries[index]),
                    ],
                  ],
                ),
                if (data.active)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      key: const Key('add-box-care-event'),
                      onPressed: _busy ? null : () => _edit(data),
                      tooltip: context.l10n.boxCareAdd,
                      child: const Icon(Icons.add),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _historyTile(
    BuildContext context,
    BoxCareHistoryData data,
    BoxCareEntry entry,
  ) {
    final label = boxCareTypeLabel(
      context.l10n,
      entry.type,
      data.types.where((t) => t.id == entry.customTypeId).firstOrNull?.label,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('edit-box-care-${entry.id}'),
          onPressed: _busy ? null : () => _edit(data, entry),
          icon: const Icon(Icons.edit_outlined),
          tooltip: context.l10n.boxCareEdit,
        ),
        if (data.canDelete)
          IconButton(
            key: ValueKey('delete-box-care-${entry.id}'),
            onPressed: _busy ? null : () => _delete(entry),
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.delete,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        return ListTile(
          key: ValueKey('box-care-event-${entry.id}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(switch (entry.type) {
            BoxCareEventType.substrateChange => Icons.grass,
            BoxCareEventType.cleaning => Icons.cleaning_services_outlined,
            BoxCareEventType.waterChange => Icons.water_drop_outlined,
            BoxCareEventType.custom => Icons.build_outlined,
          }),
          title: Text(_when(context, entry.occurredAt)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (entry.notes != null) Text(entry.notes!),
              if (data.active && compact) actions,
            ],
          ),
          trailing: data.active && !compact ? actions : null,
          onTap: data.active && !_busy ? () => _edit(data, entry) : null,
        );
      },
    );
  }
}

String _when(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final text = MaterialLocalizations.of(context);
  return '${text.formatMediumDate(local)} · ${text.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class _CareDialog extends StatefulWidget {
  const _CareDialog({required this.page, required this.types, this.entry});
  final BoxCareHistoryPage page;
  final List<CareEventTypeDefinition> types;
  final BoxCareEntry? entry;
  @override
  State<_CareDialog> createState() => _CareDialogState();
}

class _CareDialogState extends State<_CareDialog> {
  late BoxCareEventType _type =
      widget.entry?.type ?? BoxCareEventType.substrateChange;
  late String? _customTypeId = widget.entry?.customTypeId;
  late DateTime _at = widget.entry?.occurredAt.toLocal() ?? DateTime.now();
  late final TextEditingController _notes = TextEditingController(
    text: widget.entry?.notes,
  );
  final _requestId = const Uuid().v4();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _at.isAfter(now) ? now : _at,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time != null && mounted) {
      setState(
        () => _at = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_at.isAfter(DateTime.now())) {
      setState(() => _error = context.l10n.boxCareFuture);
      return;
    }
    if (_notes.text.trim().length > 10000) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.page.save(
        existing: widget.entry,
        type: _type,
        customTypeId: _customTypeId,
        occurredAt: _at,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        requestId: _requestId,
      );
      if (!saved) throw StateError('Care save failed');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.boxCareFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('box-care-dialog'),
        title: Text(
          widget.entry == null
              ? context.l10n.boxCareAdd
              : context.l10n.boxCareEdit,
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('box-care-type'),
                  initialValue: _customTypeId ?? _type.name,
                  itemHeight: null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.boxCareType,
                  ),
                  items: [
                    for (final type in BoxCareEventType.builtIn)
                      DropdownMenuItem(
                        value: type.name,
                        child: Text(boxCareTypeLabel(context.l10n, type)),
                      ),
                    for (final type in widget.types.where(
                      (t) => !t.archived || t.id == widget.entry?.customTypeId,
                    ))
                      DropdownMenuItem(
                        value: type.id,
                        child: Text(
                          '${type.label}${type.archived ? ' (${context.l10n.archived})' : ''}',
                        ),
                      ),
                    if (_customTypeId != null &&
                        !widget.types.any((t) => t.id == _customTypeId))
                      DropdownMenuItem(
                        value: _customTypeId,
                        enabled: false,
                        child: Text(context.l10n.careTypeUnavailable),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (id) => setState(() {
                          final standard = BoxCareEventType.builtIn
                              .where((t) => t.name == id)
                              .firstOrNull;
                          _type = standard ?? BoxCareEventType.custom;
                          _customTypeId = standard == null ? id : null;
                        }),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.dateAndTime),
                  subtitle: Text(_when(context, _at)),
                  trailing: IconButton(
                    key: const Key('box-care-time'),
                    onPressed: busy ? null : _pickTime,
                    icon: const Icon(Icons.calendar_today),
                    tooltip: context.l10n.dateAndTime,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('box-care-notes'),
                  controller: _notes,
                  enabled: !busy,
                  maxLines: 3,
                  maxLength: 10000,
                  decoration: InputDecoration(
                    labelText: context.l10n.notes,
                    alignLabelWithHint: true,
                  ),
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
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('save-box-care-event'),
            onPressed: busy ? null : _save,
            child: Text(busy ? context.l10n.saving : context.l10n.save),
          ),
        ],
      ),
    );
  }
}
