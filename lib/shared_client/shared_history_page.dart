import 'package:flutter/material.dart';

import '../core/presentation/widgets/constrained_page_width.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_text.dart';

enum SharedHistoryKind { feedings, weights, shedding }

class SharedHistoryPage extends StatefulWidget {
  const SharedHistoryPage({
    super.key,
    required this.api,
    required this.animalId,
    required this.kind,
    required this.active,
    required this.change,
    this.createOnOpen = false,
  });

  final SharedApiClient api;
  final int animalId;
  final SharedHistoryKind kind;
  final bool active;
  final SharedChange change;
  final bool createOnOpen;

  @override
  State<SharedHistoryPage> createState() => _SharedHistoryPageState();
}

class _SharedHistoryPageState extends State<SharedHistoryPage> {
  late Future<List<Map<String, dynamic>>> _entries;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.createOnOpen && widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.api.connected) _edit();
      });
    }
  }

  void _reload() => setState(() {
    _entries = switch (widget.kind) {
      SharedHistoryKind.feedings => widget.api.feedings(widget.animalId),
      SharedHistoryKind.weights => widget.api.weights(widget.animalId),
      SharedHistoryKind.shedding => widget.api.shedding(widget.animalId),
    };
  });

  String _title(BuildContext context) => switch (widget.kind) {
    SharedHistoryKind.feedings => sharedText(
      context,
      'Feeding history',
      'Fütterungsverlauf',
    ),
    SharedHistoryKind.weights => sharedText(
      context,
      'Weight history',
      'Gewichtsverlauf',
    ),
    SharedHistoryKind.shedding => sharedText(
      context,
      'Shedding history',
      'Häutungsverlauf',
    ),
  };

  String _dateKey() => switch (widget.kind) {
    SharedHistoryKind.feedings => 'fedAt',
    SharedHistoryKind.weights => 'measuredAt',
    SharedHistoryKind.shedding => 'shedAt',
  };

  Future<void> _edit([Map<String, dynamic>? initial]) async {
    final input = await showDialog<_HistoryInput>(
      context: context,
      builder: (context) => _HistoryDialog(kind: widget.kind, initial: initial),
    );
    if (input == null) return;
    final saved = await widget.change(() async {
      final id = initial?['id'] as int?;
      switch (widget.kind) {
        case SharedHistoryKind.feedings:
          if (id == null) {
            await widget.api.createFeeding(
              widget.animalId,
              input.date,
              input.notes,
            );
          } else {
            await widget.api.updateFeeding(id, input.date, input.notes);
          }
        case SharedHistoryKind.weights:
          final grams = input.grams!;
          if (id == null) {
            await widget.api.addWeight(widget.animalId, grams, input.date);
          } else {
            await widget.api.updateWeight(
              widget.animalId,
              id,
              grams,
              input.date,
            );
          }
        case SharedHistoryKind.shedding:
          if (id == null) {
            await widget.api.addShedding(
              widget.animalId,
              input.date,
              input.notes,
            );
          } else {
            await widget.api.updateShedding(
              widget.animalId,
              id,
              input.date,
              input.notes,
            );
          }
      }
    });
    if (!mounted) return;
    if (saved) {
      _reload();
    } else {
      _showFailure();
    }
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sharedText(context, 'Delete entry?', 'Eintrag löschen?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(sharedText(context, 'Delete', 'Löschen')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = entry['id'] as int;
    final saved = await widget.change(() async {
      switch (widget.kind) {
        case SharedHistoryKind.feedings:
          await widget.api.deleteFeeding(id);
        case SharedHistoryKind.weights:
          await widget.api.deleteWeight(widget.animalId, id);
        case SharedHistoryKind.shedding:
          await widget.api.deleteShedding(widget.animalId, id);
      }
    });
    if (!mounted) return;
    if (saved) {
      _reload();
    } else {
      _showFailure();
    }
  }

  void _showFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sharedText(
            context,
            'Could not save. Reload and check the server state.',
            'Speichern fehlgeschlagen. Neu laden und Serverstand prüfen.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ConstrainedPageWidth(
    child: Scaffold(
      appBar: AppBar(title: Text(_title(context))),
      floatingActionButton: widget.active
          ? ListenableBuilder(
              listenable: widget.api,
              builder: (context, _) => FloatingActionButton(
                onPressed: widget.api.connected ? () => _edit() : null,
                child: const Icon(Icons.add),
              ),
            )
          : null,
      body: ConstrainedPageWidth(
        maxWidth: 760,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: _reload,
                  child: Text(sharedText(context, 'Retry', 'Erneut versuchen')),
                ),
              );
            }
            final values = snapshot.data!;
            if (values.isEmpty) {
              return Center(
                child: Text(
                  sharedText(context, 'No entries', 'Keine Einträge'),
                ),
              );
            }
            return ListenableBuilder(
              listenable: widget.api,
              builder: (context, _) => ListView.builder(
                itemCount: values.length,
                itemBuilder: (context, index) {
                  final entry = values[index];
                  final rawDate = entry[_dateKey()] as String?;
                  final date = DateTime.tryParse(rawDate ?? '')?.toLocal();
                  final formatted = date == null
                      ? '–'
                      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                  final amount = entry['weightGrams'];
                  return ListTile(
                    title: Text(
                      amount == null ? formatted : '$formatted · $amount g',
                    ),
                    subtitle: entry['notes'] == null
                        ? null
                        : Text(entry['notes'] as String),
                    trailing: widget.active
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: sharedText(
                                  context,
                                  'Edit',
                                  'Bearbeiten',
                                ),
                                onPressed: widget.api.connected
                                    ? () => _edit(entry)
                                    : null,
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: sharedText(
                                  context,
                                  'Delete',
                                  'Löschen',
                                ),
                                onPressed: widget.api.connected
                                    ? () => _delete(entry)
                                    : null,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          )
                        : null,
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _HistoryInput {
  const _HistoryInput(this.date, this.notes, this.grams);
  final DateTime date;
  final String? notes;
  final double? grams;
}

class _HistoryDialog extends StatefulWidget {
  const _HistoryDialog({required this.kind, required this.initial});
  final SharedHistoryKind kind;
  final Map<String, dynamic>? initial;

  @override
  State<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<_HistoryDialog> {
  late DateTime _date;
  late final TextEditingController _notes;
  late final TextEditingController _grams;
  String? _error;

  @override
  void initState() {
    super.initState();
    final dateKey = switch (widget.kind) {
      SharedHistoryKind.feedings => 'fedAt',
      SharedHistoryKind.weights => 'measuredAt',
      SharedHistoryKind.shedding => 'shedAt',
    };
    _date =
        DateTime.tryParse(widget.initial?[dateKey] as String? ?? '')
            ?.toLocal() ??
        DateTime.now();
    _notes = TextEditingController(
      text: widget.initial?['notes'] as String? ?? '',
    );
    _grams = TextEditingController(
      text: widget.initial?['weightGrams']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    _grams.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(() {
      _date = DateTime(
        selected.year,
        selected.month,
        selected.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
  }

  void _submit() {
    final grams = widget.kind == SharedHistoryKind.weights
        ? double.tryParse(_grams.text.trim().replaceAll(',', '.'))
        : null;
    if (_date.isAfter(DateTime.now()) ||
        (widget.kind == SharedHistoryKind.weights &&
            (grams == null || !grams.isFinite || grams <= 0))) {
      setState(() {
        _error = sharedText(
          context,
          'Enter a valid date and weight.',
          'Gültiges Datum und Gewicht eingeben.',
        );
      });
      return;
    }
    Navigator.of(context).pop(
      _HistoryInput(
        _date,
        _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        grams,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(sharedText(context, 'Care entry', 'Pflegeeintrag')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(_date.toLocal().toString().split('.').first),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _pickDate,
        ),
        if (widget.kind == SharedHistoryKind.weights)
          TextField(
            controller: _grams,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: sharedText(context, 'Weight (g)', 'Gewicht (g)'),
            ),
          ),
        if (widget.kind != SharedHistoryKind.weights)
          TextField(
            controller: _notes,
            decoration: InputDecoration(
              labelText: sharedText(context, 'Notes', 'Notizen'),
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(sharedText(context, 'Save', 'Speichern')),
      ),
    ],
  );
}
