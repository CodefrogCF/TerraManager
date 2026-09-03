import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/feeding_repository.dart';

class FeedingHistoryPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;

  const FeedingHistoryPage({
    super.key,
    required this.database,
    required this.animalId,
  });

  @override
  State<FeedingHistoryPage> createState() => _FeedingHistoryPageState();
}

class _FeedingHistoryPageState extends State<FeedingHistoryPage> {
  late Future<List<FeedingEvent>> _feedingsFuture;

  @override
  void initState() {
    super.initState();
    _loadFeedings();
  }

  void _loadFeedings() {
    _feedingsFuture = FeedingRepository(widget.database)
        .getFeedingsForAnimal(widget.animalId);
  }

  Future<void> _addFeeding() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _FeedingDialog(
          database: widget.database,
          animalId: widget.animalId,
        );
      },
    );

    if (!mounted || created != true) {
      return;
    }

    setState(() {
      _loadFeedings();
    });
  }

  Future<void> _editFeeding(FeedingEvent feeding) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _FeedingDialog(
          database: widget.database,
          animalId: widget.animalId,
          feeding: feeding,
        );
      },
    );

    if (!mounted || changed != true) {
      return;
    }

    setState(() {
      _loadFeedings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feeding History')),
      body: FutureBuilder<List<FeedingEvent>>(
        future: _feedingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load feeding history'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedings = snapshot.data ?? [];

          if (feedings.isEmpty) {
            return const Center(child: Text('No feeding events available'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: feedings.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final feeding = feedings[index];

              return ListTile(
                key: Key('feeding-item-${feeding.id}'),
                leading: const Icon(Icons.restaurant),
                title: Text(_formatDateTime(feeding.fedAt)),
                subtitle:
                    feeding.notes != null && feeding.notes!.trim().isNotEmpty
                    ? Text(feeding.notes!)
                    : null,
                trailing: const Icon(Icons.edit_outlined),
                onTap: () {
                  _editFeeding(feeding);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-feeding-button'),
        onPressed: _addFeeding,
        tooltip: 'Add Feeding',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FeedingDialog extends StatefulWidget {
  final AppDatabase database;
  final int animalId;
  final FeedingEvent? feeding;

  const _FeedingDialog({
    required this.database,
    required this.animalId,
    this.feeding,
  });

  bool get isEditing => feeding != null;

  @override
  State<_FeedingDialog> createState() => _FeedingDialogState();
}

class _FeedingDialogState extends State<_FeedingDialog> {
  final _notesController = TextEditingController();

  late DateTime _fedAt;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final feeding = widget.feeding;

    _fedAt = feeding?.fedAt ?? DateTime.now();

    _notesController.text = feeding?.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notes = _notesController.text.trim();
      final normalizedNotes = notes.isEmpty ? null : notes;

      if (widget.isEditing) {
        final updated = await FeedingRepository(widget.database).updateFeeding(
          feedingId: widget.feeding!.id,
          fedAt: _fedAt,
          notes: normalizedNotes,
        );

        if (!updated) {
          throw StateError('Feeding update failed');
        }
      } else {
        await FeedingRepository(widget.database)
            .addFeeding(widget.animalId, _fedAt, notes: normalizedNotes);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = widget.isEditing
            ? 'Failed to update feeding event'
            : 'Failed to save feeding event';
      });
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();

    final initialDate = _fedAt.isAfter(now) ? now : _fedAt;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fedAt),
    );

    if (time == null || !mounted) {
      return;
    }

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (selected.isAfter(DateTime.now())) {
      setState(() {
        _error = 'Feeding date and time cannot be in the future';
      });

      return;
    }

    setState(() {
      _fedAt = selected;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('feeding-dialog'),
      title: Text(widget.isEditing ? 'Edit Feeding' : 'Add Feeding'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                key: const Key('feeding-dialog-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],

            ListTile(
              key: const Key('feeding-date-time-field'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Date and Time'),
              subtitle: Text(
                _formatDateTime(_fedAt),
                key: const Key('feeding-date-time-value'),
              ),
              trailing: IconButton(
                key: const Key('feeding-date-time-button'),
                onPressed: _saving ? null : _selectDateTime,
                icon: const Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              key: const Key('feeding-notes-field'),
              controller: _notesController,
              enabled: !_saving,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-feeding-button'),
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-feeding-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');

  final month = dateTime.month.toString().padLeft(2, '0');

  final year = dateTime.year.toString();

  final hour = dateTime.hour.toString().padLeft(2, '0');

  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}
