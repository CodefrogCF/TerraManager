import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/widgets/reminder_clock.dart';
import '../../../../core/presentation/widgets/reminder_due_button.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../domain/box_care_reminder.dart';

typedef SaveBoxCareReminder = Future<bool> Function({
  required String typeKey,
  required DateTime? dueOn,
  required int? intervalDays,
  required String? expectedRevision,
});

class BoxCareReminderSection extends StatelessWidget {
  const BoxCareReminderSection({
    super.key,
    required this.reminders,
    required this.choices,
    required this.save,
    required this.onSaved,
    required this.onRecord,
  });

  final List<BoxCareReminder> reminders;
  final Map<String, String> choices;
  final SaveBoxCareReminder save;
  final VoidCallback onSaved;
  final ValueChanged<String> onRecord;

  Future<void> _edit(
    BuildContext context,
    Map<String, String> types, [
    BoxCareReminder? current,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ReminderDialog(choices: types, current: current, save: save),
    );
    if (saved == true && context.mounted) onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final active = reminders
        .where((r) => choices.containsKey(r.typeKey))
        .toList();
    final configured = active.map((r) => r.typeKey).toSet();
    final available = {
      for (final entry in choices.entries)
        if (!configured.contains(entry.key)) entry.key: entry.value,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.l10n.boxCareReminders),
            trailing: IconButton(
              key: const Key('add-box-care-reminder'),
              icon: const Icon(Icons.add),
              tooltip: context.l10n.boxCareReminderAdd,
              onPressed: available.isEmpty
                  ? null
                  : () => _edit(context, available),
            ),
          ),
          ReminderClockView(
            transitions: active.map((r) => BoxCareReminder.dueTime(r.dueOn)),
            builder: (context, now) => Column(
              children: [
                for (final reminder in active)
                  ListTile(
                    key: ValueKey('box-care-reminder-${reminder.typeKey}'),
                    title: Text(choices[reminder.typeKey]!),
                    subtitle: Text(
                      reminder.isDue(now)
                          ? context.l10n.feedingDueSince(
                              _date(context, reminder.dueOn),
                            )
                          : _date(context, reminder.dueOn),
                    ),
                    onTap: () => _edit(context, choices, reminder),
                    trailing: reminder.isDue(now)
                        ? ReminderDueButton(
                            tooltip: context.l10n.boxCareAdd,
                            onPressed: () => onRecord(reminder.typeKey),
                          )
                        : const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _date(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatCompactDate(date);

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({
    required this.choices,
    required this.current,
    required this.save,
  });
  final Map<String, String> choices;
  final BoxCareReminder? current;
  final SaveBoxCareReminder save;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _form = GlobalKey<FormState>();
  late String _type = widget.current?.typeKey ?? widget.choices.keys.first;
  late DateTime _due = BoxCareReminder.dueTime(
    widget.current?.dueOn ?? DateTime.now(),
  );
  late bool _repeat = widget.current?.intervalDays != null;
  late final _interval = TextEditingController(
    text: widget.current?.intervalDays?.toString(),
  );
  bool _enabled = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (mounted && date != null) setState(() => _due = date);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save(
        typeKey: _type,
        dueOn: _enabled ? _due : null,
        intervalDays: _enabled && _repeat ? int.parse(_interval.text) : null,
        expectedRevision: widget.current?.revision,
      );
      if (!saved) throw StateError('Care reminder save failed.');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.boxCareReminderSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      key: const Key('box-care-reminder-dialog'),
      scrollable: true,
      title: Text(
        widget.current == null
            ? context.l10n.boxCareReminderAdd
            : widget.choices[_type]!,
      ),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.current == null)
                DropdownButtonFormField<String>(
                  key: const Key('box-care-reminder-type'),
                  initialValue: _type,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: context.l10n.boxCareType,
                  ),
                  items: [
                    for (final entry in widget.choices.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _type = value!),
                )
              else
                SwitchListTile(
                  key: const Key('box-care-reminder-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.boxCareReminder),
                  value: _enabled,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _enabled = value),
                ),
              if (_enabled) ...[
                ListTile(
                  key: const Key('box-care-reminder-date'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.boxCareReminderDueDate),
                  subtitle: Text(_date(context, _due)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _saving ? null : _pickDate,
                ),
                CheckboxListTile(
                  key: const Key('box-care-reminder-repeat'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.boxCareReminderRepeat),
                  value: _repeat,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _repeat = value!),
                ),
                if (_repeat)
                  TextFormField(
                    key: const Key('box-care-reminder-interval'),
                    controller: _interval,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.l10n.feedingReminderIntervalDays,
                    ),
                    validator: (value) {
                      final days = int.tryParse(value ?? '');
                      return days != null && BoxCareReminder.validInterval(days)
                          ? null
                          : context.l10n.boxCareReminderInvalidInterval;
                    },
                  ),
              ],
              if (_error != null)
                Text(
                  _error!,
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
          key: const Key('save-box-care-reminder'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? context.l10n.saving : context.l10n.save),
        ),
      ],
    ),
  );
}
