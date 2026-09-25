import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/sorting/natural_string_comparator.dart';
import '../features/animals/presentation/animal_display_names.dart';
import '../l10n/app_localizations_context.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_text.dart';

/// Records one Feeding for each selected Animal in an active server-owned Box.
class SharedFeedingBoxPage extends StatefulWidget {
  const SharedFeedingBoxPage({
    super.key,
    required this.api,
    required this.box,
    required this.change,
    required this.onReload,
  });

  final SharedApiClient api;
  final Map<String, dynamic> box;
  final SharedChange change;
  final Future<void> Function() onReload;

  @override
  State<SharedFeedingBoxPage> createState() => _SharedFeedingBoxPageState();
}

class _SharedFeedingBoxPageState extends State<SharedFeedingBoxPage> {
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>> _animals = const [];
  Set<int> _selectedIds = {};
  DateTime _fedAt = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _pendingFingerprint;
  String? _pendingRequestId;

  int get _boxId => widget.box['id'] as int;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimals() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final box = await widget.api.box(_boxId);
      if (box['status'] != 'active') {
        throw const SharedApiException(409, 'conflict', 'Box is not active.');
      }
      final animals = (await widget.api.animals())
          .where(
            (animal) =>
                animal['status'] == 'active' &&
                animal['boxId'] == _boxId &&
                animal['id'] is int,
          )
          .toList();
      animals.sort(
        (a, b) => compareNaturalStrings(animalLabel(a), animalLabel(b)),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _animals = animals;
        _selectedIds = animals.map((animal) => animal['id'] as int).toSet();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _animals = const [];
        _selectedIds = {};
        _loading = false;
        _error = sharedText(
          context,
          'Could not load this active Box. Check the server and try again.',
          'Diese aktive Box konnte nicht geladen werden. Prüfe den Server und versuche es erneut.',
        );
      });
    }
  }

  Future<void> _selectDateTime() async {
    if (_saving) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _fedAt.isAfter(now) ? now : _fedAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fedAt),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(DateTime.now())) {
      setState(() => _error = context.l10n.feedingDateTimeInFuture);
      return;
    }
    setState(() {
      _fedAt = selected;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _selectedIds.isEmpty || _loading) return;
    if (_fedAt.isAfter(DateTime.now())) {
      setState(() => _error = context.l10n.feedingDateTimeInFuture);
      return;
    }
    final ids = _animals
        .where((animal) => _selectedIds.contains(animal['id']))
        .map((animal) => animal['id'] as int)
        .toList();
    final text = _notesController.text.trim();
    final notes = text.isEmpty ? null : text;
    final fingerprint = jsonEncode({
      'boxId': _boxId,
      'animalIds': ids,
      'fedAt': _fedAt.toUtc().toIso8601String(),
      'notes': notes,
    });
    if (_pendingFingerprint != fingerprint) {
      _pendingFingerprint = fingerprint;
      _pendingRequestId = const Uuid().v4();
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!widget.api.connected) await widget.onReload();
      final saved = await widget.change(() async {
        await widget.api.createFeedings(
          animalIds: ids,
          fedAt: _fedAt,
          notes: notes,
          boxId: _boxId,
          requestId: _pendingRequestId,
        );
      });
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = sharedText(
            context,
            'Save could not be confirmed. Check Feeding history before retrying.',
            'Speichern konnte nicht bestätigt werden. Prüfe vor einem neuen Versuch den Fütterungsverlauf.',
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = sharedText(
          context,
          'Save could not be confirmed. Check Feeding history before retrying.',
          'Speichern konnte nicht bestätigt werden. Prüfe vor einem neuen Versuch den Fütterungsverlauf.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _animals.isNotEmpty && _selectedIds.length == _animals.length;
    final label = boxLabel(widget.box);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.feedingBoxTitle(label))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            key: const Key('shared-feeding-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_animals.isEmpty && _error == null)
                        Text(
                          context.l10n.noActiveAnimalsAssigned(label),
                          key: const Key('shared-feeding-empty'),
                        )
                      else if (_animals.isNotEmpty) ...[
                        Text(
                          context.l10n.activeAnimalsAssignedToBox(
                            _animals.length,
                            label,
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const Key('shared-feeding-toggle-all'),
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _selectedIds = allSelected
                                        ? {}
                                        : _animals
                                              .map(
                                                (animal) => animal['id'] as int,
                                              )
                                              .toSet();
                                    _error = null;
                                  }),
                            child: Text(
                              allSelected
                                  ? context.l10n.deselectAll
                                  : context.l10n.selectAll,
                            ),
                          ),
                        ),
                        for (final animal in _animals)
                          Builder(
                            builder: (context) {
                              final names = AnimalDisplayNames.fromContext(
                                context,
                                commonName:
                                    (animal['commonName'] as String?) ?? '',
                                latinName:
                                    (animal['latinName'] as String?) ?? '',
                              );
                              final id = animal['id'] as int;
                              return CheckboxListTile(
                                key: Key('shared-feeding-animal-$id'),
                                value: _selectedIds.contains(id),
                                onChanged: _saving
                                    ? null
                                    : (selected) => setState(() {
                                        if (selected == true) {
                                          _selectedIds.add(id);
                                        } else {
                                          _selectedIds.remove(id);
                                        }
                                        _error = null;
                                      }),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(names.primary),
                                subtitle: Text(names.secondary),
                              );
                            },
                          ),
                        const Divider(height: 32),
                        ListTile(
                          key: const Key('shared-feeding-date-time'),
                          title: Text(context.l10n.dateAndTime),
                          subtitle: Text(
                            '${MaterialLocalizations.of(context).formatMediumDate(_fedAt)} '
                            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_fedAt))}',
                          ),
                          trailing: IconButton(
                            onPressed: _saving ? null : _selectDateTime,
                            icon: const Icon(Icons.calendar_today),
                          ),
                        ),
                        TextField(
                          key: const Key('shared-feeding-notes'),
                          controller: _notesController,
                          enabled: !_saving,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: context.l10n.notes,
                          ),
                        ),
                      ],
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
                        if (_animals.isNotEmpty)
                          FilledButton.icon(
                            key: const Key('shared-feeding-save'),
                            onPressed: _saving || _selectedIds.isEmpty
                                ? null
                                : _save,
                            icon: const Icon(Icons.restaurant),
                            label: Text(
                              _selectedIds.isEmpty
                                  ? context.l10n.selectAnimal
                                  : context.l10n.saveFeedings(
                                      _selectedIds.length,
                                    ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('shared-feeding-next-box'),
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(context.l10n.scanDifferentBox),
                        ),
                        if (_error != null && _animals.isEmpty)
                          TextButton(
                            onPressed: _loadAnimals,
                            child: Text(
                              sharedText(context, 'Retry', 'Erneut versuchen'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
