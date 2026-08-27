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
        return _AddFeedingDialog(
          database: widget.database,
          animalId: widget.animalId,
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      setState(() {
        _loadFeedings();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeding History'),
      ),
      body: FutureBuilder<List<FeedingEvent>>(
        future: _feedingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load feeding history'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final feedings = snapshot.data ?? [];

          if (feedings.isEmpty) {
            return const Center(
              child: Text('No feeding events available'),
            );
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
                subtitle: feeding.notes != null &&
                        feeding.notes!.trim().isNotEmpty
                    ? Text(feeding.notes!)
                    : null,
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

class _AddFeedingDialog extends StatefulWidget {
  final AppDatabase database;
  final int animalId;

  const _AddFeedingDialog({
    required this.database,
    required this.animalId,
  });

  @override
  State<_AddFeedingDialog> createState() => _AddFeedingDialogState();
}

class _AddFeedingDialogState extends State<_AddFeedingDialog> {
  final _notesController = TextEditingController();

  DateTime _fedAt = DateTime.now();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FeedingRepository(widget.database).addFeeding(
        widget.animalId,
        _fedAt,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

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
        _error = 'Failed to save feeding event';
      });
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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

    setState(() {
      _fedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Feeding'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
            ],
            ListTile(
              key: const Key('feeding-date-time-field'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Date and Time'),
              subtitle: Text(
                _formatDateTime(_fedAt),
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
          child: Text(
            _saving ? 'Saving...' : 'Save',
          ),
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