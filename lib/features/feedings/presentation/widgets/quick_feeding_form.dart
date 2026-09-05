import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/feeding_repository.dart';

class QuickFeedingForm extends StatefulWidget {
  final AppDatabase database;
  final String boxLabel;
  final List<Animal> animals;
  final DateTime? initialFedAt;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  QuickFeedingForm({
    super.key,
    required this.database,
    required this.boxLabel,
    required Iterable<Animal> animals,
    this.initialFedAt,
    required this.onSaved,
    required this.onCancel,
  }) : animals = List<Animal>.unmodifiable(animals) {
    if (this.animals.isEmpty) {
      throw ArgumentError.value(animals, 'animals', 'must not be empty');
    }
  }

  @override
  State<QuickFeedingForm> createState() => _QuickFeedingFormState();
}

class _QuickFeedingFormState extends State<QuickFeedingForm> {
  final TextEditingController _notesController = TextEditingController();

  late final Set<int> _selectedAnimalIds;
  late DateTime _fedAt;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _selectedAnimalIds = widget.animals.map((animal) => animal.id).toSet();
    _fedAt = widget.initialFedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _setAnimalSelected(int animalId, {required bool selected}) {
    if (_saving) {
      return;
    }

    setState(() {
      if (selected) {
        _selectedAnimalIds.add(animalId);
      } else {
        _selectedAnimalIds.remove(animalId);
      }

      _error = null;
    });
  }

  void _toggleAllAnimals() {
    if (_saving) {
      return;
    }

    final allSelected = _selectedAnimalIds.length == widget.animals.length;

    setState(() {
      if (allSelected) {
        _selectedAnimalIds.clear();
      } else {
        _selectedAnimalIds
          ..clear()
          ..addAll(widget.animals.map((animal) => animal.id));
      }

      _error = null;
    });
  }

  Future<void> _selectDateTime() async {
    if (_saving) {
      return;
    }

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

  Future<void> _save() async {
    if (_saving || _selectedAnimalIds.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notes = _notesController.text.trim();
      final normalizedNotes = notes.isEmpty ? null : notes;

      final orderedAnimalIds = widget.animals
          .where((animal) => _selectedAnimalIds.contains(animal.id))
          .map((animal) => animal.id);

      await FeedingRepository(widget.database).addFeedings(
        animalIds: orderedAnimalIds,
        fedAt: _fedAt,
        notes: normalizedNotes,
      );

      if (!mounted) {
        return;
      }

      widget.onSaved();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = 'Failed to save feeding events';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedAnimalIds.length == widget.animals.length;
    final selectedCount = _selectedAnimalIds.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.animals.length} active '
                '${widget.animals.length == 1 ? 'animal' : 'animals'} '
                'assigned to ${widget.boxLabel}',
                key: const Key('feeding-box-animal-count'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('toggle-all-feeding-animals-button'),
                  onPressed: _saving ? null : _toggleAllAnimals,
                  child: Text(allSelected ? 'Deselect all' : 'Select all'),
                ),
              ),
              ...widget.animals.map((animal) {
                return CheckboxListTile(
                  key: Key('feeding-mode-animal-${animal.id}'),
                  value: _selectedAnimalIds.contains(animal.id),
                  onChanged: _saving
                      ? null
                      : (selected) {
                          _setAnimalSelected(
                            animal.id,
                            selected: selected ?? false,
                          );
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(animal.commonName),
                  subtitle: Text(animal.latinName),
                );
              }),
              const Divider(height: 32),
              if (_error != null) ...[
                Text(
                  _error!,
                  key: const Key('quick-feeding-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              ListTile(
                key: const Key('quick-feeding-date-time-field'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Date and Time'),
                subtitle: Text(
                  _formatDateTime(_fedAt),
                  key: const Key('quick-feeding-date-time-value'),
                ),
                trailing: IconButton(
                  key: const Key('quick-feeding-date-time-button'),
                  onPressed: _saving ? null : _selectDateTime,
                  icon: const Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('quick-feeding-notes-field'),
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: const Key('save-quick-feeding-button'),
                  onPressed: _saving || selectedCount == 0 ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restaurant),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : selectedCount == 0
                        ? 'Select an Animal'
                        : selectedCount == 1
                        ? 'Save Feeding'
                        : 'Save $selectedCount Feedings',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('scan-another-box-button'),
                  onPressed: _saving ? null : widget.onCancel,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan another Box'),
                ),
              ],
            ),
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
