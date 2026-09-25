import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations_context.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_feeding_reminder_page.dart';
import 'shared_forms.dart';
import 'shared_history_page.dart';
import 'shared_text.dart';

class SharedBoxDetailPage extends StatefulWidget {
  const SharedBoxDetailPage({
    super.key,
    required this.api,
    required this.id,
    required this.boxes,
    required this.animals,
    required this.connected,
    required this.change,
  });
  final SharedApiClient api;
  final int id;
  final List<Map<String, dynamic>> boxes;
  final List<Map<String, dynamic>> animals;
  final bool connected;
  final SharedChange change;

  @override
  State<SharedBoxDetailPage> createState() => _SharedBoxDetailPageState();
}

class _SharedBoxDetailPageState extends State<SharedBoxDetailPage>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _record;
  late List<Map<String, dynamic>> _animals;
  Timer? _timer;
  bool _foreground = true;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animals = widget.animals;
    _record = widget.api.box(widget.id);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_refreshVisible());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refreshVisible());
  }

  Future<void> _refreshVisible() async {
    if (!mounted ||
        !_foreground ||
        _polling ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _polling = true;
    try {
      final box = await widget.api.box(widget.id);
      final animals = await widget.api.animals();
      if (mounted && _foreground && ModalRoute.of(context)?.isCurrent == true) {
        setState(() {
          _record = Future.value(box);
          _animals = animals;
        });
      }
    } catch (_) {
      // Keep the last readable record; the page's manual reload reports errors.
    } finally {
      _polling = false;
    }
  }

  void _reload() => setState(() {
    _record = widget.api.box(widget.id);
  });

  Future<void> _openEdit() async {
    try {
      final box = await _record;
      if (!mounted || box['status'] != 'active') return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SharedBoxForm(
            api: widget.api,
            initial: box,
            change: widget.change,
          ),
        ),
      );
      if (mounted) _reload();
    } catch (_) {
      if (mounted) _showFailure(context);
    }
  }

  Future<bool> _change(Future<void> Function() action) async {
    final saved = await widget.change(action);
    if (!mounted) return false;
    if (saved) {
      _reload();
    } else {
      _showFailure(context);
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Box ${widget.id}'),
      actions: [
        FutureBuilder<Map<String, dynamic>>(
          future: _record,
          builder: (context, snapshot) => snapshot.data?['status'] == 'active'
              ? ListenableBuilder(
                  listenable: widget.api,
                  builder: (context, _) => IconButton(
                    tooltip: sharedText(context, 'Edit Box', 'Box bearbeiten'),
                    onPressed: widget.api.connected ? _openEdit : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadFailure(onRetry: _reload);
        }
        final box = snapshot.data!;
        final active = box['status'] == 'active';
        final animals = _animals
            .where((animal) => animal['boxId'] == widget.id)
            .toList();
        return ListenableBuilder(
          listenable: widget.api,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SharedPictureGallery(
                api: widget.api,
                kind: 'boxes',
                recordId: widget.id,
                active: active,
                change: _change,
                onChanged: _reload,
              ),
              const SizedBox(height: 12),
              Text(
                ((box['name'] as String?)?.trim().isNotEmpty ?? false)
                    ? (box['name'] as String).trim()
                    : 'Box ${widget.id}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              _DetailRow(label: 'QR ID', value: box['qrId']?.toString()),
              _DetailRow(
                label: sharedText(context, 'Dimensions', 'Maße'),
                value:
                    '${[box['widthCm'], box['heightCm'], box['depthCm']].map((value) => value?.toString() ?? '–').join(' × ')} cm',
              ),
              _DetailRow(
                label: sharedText(
                  context,
                  'Temperature zones',
                  'Temperaturzonen',
                ),
                value: box['temperatureZones'] as String?,
              ),
              _DetailRow(
                label: sharedText(context, 'Notes', 'Notizen'),
                value: box['notes'] as String?,
              ),
              if (!active)
                _DetailRow(
                  label: sharedText(context, 'Archive reason', 'Archivgrund'),
                  value: box['archiveReason'] == null
                      ? null
                      : sharedArchiveReasonLabel(
                          context,
                          box['archiveReason'] as String,
                          box: true,
                        ),
                ),
              const Divider(),
              Text(
                sharedText(context, 'Animals', 'Tiere'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final animal in animals)
                ListTile(
                  title: Text(animalLabel(animal)),
                  subtitle: Text(animal['status']?.toString() ?? ''),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SharedAnimalDetailPage(
                        api: widget.api,
                        id: recordId(animal),
                        boxes: widget.boxes,
                        connected: widget.connected,
                        change: widget.change,
                      ),
                    ),
                  ),
                ),
              const Divider(),
              if (active) ...[
                OutlinedButton.icon(
                  onPressed: widget.api.connected
                      ? () async {
                          final choice = await showArchiveDialog(
                            context,
                            reasons: const [
                              'sold',
                              'replaced',
                              'damaged',
                              'other',
                            ],
                          );
                          if (choice == null) return;
                          await _change(() async {
                            await widget.api.archiveBox(
                              widget.id,
                              choice.$1,
                              choice.$2,
                            );
                          });
                        }
                      : null,
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(
                    sharedText(context, 'Archive Box', 'Box archivieren'),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.api.connected
                      ? () => _change(() async {
                          await widget.api.duplicateBox(
                            widget.id,
                            box['name'] as String?,
                          );
                        })
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(
                    sharedText(context, 'Duplicate Box', 'Box duplizieren'),
                  ),
                ),
              ] else ...[
                FilledButton.tonalIcon(
                  onPressed: widget.api.connected
                      ? () => _change(() async {
                          await widget.api.restoreBox(widget.id);
                        })
                      : null,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: Text(
                    sharedText(context, 'Restore Box', 'Box wiederherstellen'),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.api.connected
                      ? () async {
                          if (!await confirmPermanentDeletion(context)) return;
                          final done = await _change(() async {
                            await widget.api.deleteBox(widget.id);
                          });
                          if (done && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(
                    sharedText(
                      context,
                      'Delete permanently',
                      'Endgültig löschen',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class SharedAnimalDetailPage extends StatefulWidget {
  const SharedAnimalDetailPage({
    super.key,
    required this.api,
    required this.id,
    required this.boxes,
    required this.connected,
    required this.change,
  });
  final SharedApiClient api;
  final int id;
  final List<Map<String, dynamic>> boxes;
  final bool connected;
  final SharedChange change;

  @override
  State<SharedAnimalDetailPage> createState() => _SharedAnimalDetailPageState();
}

class _SharedAnimalDetailPageState extends State<SharedAnimalDetailPage>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _record;
  late Future<List<Map<String, dynamic>>> _feedings;
  late List<Map<String, dynamic>> _boxes;
  Timer? _timer;
  bool _foreground = true;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boxes = widget.boxes;
    _record = widget.api.animal(widget.id);
    _feedings = widget.api.feedings(widget.id);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_refreshVisible());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refreshVisible());
  }

  Future<void> _refreshVisible() async {
    if (!mounted ||
        !_foreground ||
        _polling ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _polling = true;
    try {
      final animal = await widget.api.animal(widget.id);
      final feedings = await widget.api.feedings(widget.id);
      final boxes = await widget.api.boxes();
      if (mounted && _foreground && ModalRoute.of(context)?.isCurrent == true) {
        setState(() {
          _record = Future.value(animal);
          _feedings = Future.value(feedings);
          _boxes = boxes;
        });
      }
    } catch (_) {
      // Keep the last readable record; the page's manual reload reports errors.
    } finally {
      _polling = false;
    }
  }

  void _reload() => setState(() {
    _record = widget.api.animal(widget.id);
    _feedings = widget.api.feedings(widget.id);
  });

  DateTime? _latestFeeding(List<Map<String, dynamic>> entries) {
    DateTime? latest;
    for (final entry in entries) {
      final date = DateTime.tryParse(entry['fedAt'] as String? ?? '');
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Widget _feedingInformation(Map<String, dynamic> animal, {required bool due}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedings,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return due
              ? const SizedBox.shrink()
              : ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(context.l10n.failedToLoadLatestFeeding),
                  trailing: const Icon(Icons.refresh),
                  onTap: _reload,
                );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        final latest = _latestFeeding(snapshot.data!);
        final interval = animal['feedingReminderIntervalDays'] as int?;
        final baseline = DateTime.tryParse(
          animal['feedingReminderBaseline'] as String? ?? '',
        );
        final next = interval == null || interval <= 0 || baseline == null
            ? null
            : (latest ?? baseline).add(Duration(days: interval));
        final overdue = next != null && !next.isAfter(DateTime.now());
        if (due) {
          if (!overdue || animal['status'] != 'active') {
            return const SizedBox.shrink();
          }
          return Card(
            key: const Key('shared-feeding-reminder-status'),
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.notification_important_outlined),
              title: Text(context.l10n.feedingDue),
              subtitle: Text(
                context.l10n.feedingDueSince(_dateLabel(context, next)),
              ),
              onTap: () => _openFeedingHistory(true),
            ),
          );
        }
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: Text(context.l10n.latestFeeding),
              subtitle: Text(
                latest == null
                    ? context.l10n.noFeedingEventsAvailable
                    : _dateLabel(context, latest),
              ),
              onTap: () => _openFeedingHistory(animal['status'] == 'active'),
            ),
            if (next != null && !overdue && animal['status'] == 'active')
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(context.l10n.nextFeeding),
                subtitle: Text(_dateLabel(context, next)),
                onTap: () => _openFeedingHistory(true),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openFeedingHistory(bool active) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedHistoryPage(
          api: widget.api,
          animalId: widget.id,
          kind: SharedHistoryKind.feedings,
          active: active,
          change: widget.change,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openBox(int id) async {
    try {
      final animals = await widget.api.animals();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SharedBoxDetailPage(
            api: widget.api,
            id: id,
            boxes: widget.boxes,
            animals: animals,
            connected: widget.api.connected,
            change: widget.change,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _showFailure(context);
    }
  }

  Future<void> _openEdit() async {
    try {
      final animal = await _record;
      if (!mounted || animal['status'] != 'active') return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SharedAnimalForm(
            api: widget.api,
            boxes: widget.boxes,
            initial: animal,
            change: widget.change,
          ),
        ),
      );
      if (mounted) _reload();
    } catch (_) {
      if (mounted) _showFailure(context);
    }
  }

  Future<void> _openReminderSettings() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SharedFeedingReminderPage(
          api: widget.api,
          animalId: widget.id,
          change: widget.change,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<bool> _change(Future<void> Function() action) async {
    final saved = await widget.change(action);
    if (!mounted) return false;
    if (saved) {
      _reload();
    } else {
      _showFailure(context);
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(sharedText(context, 'Animal details', 'Tierdetails')),
      actions: [
        FutureBuilder<Map<String, dynamic>>(
          future: _record,
          builder: (context, snapshot) => snapshot.data?['status'] == 'active'
              ? ListenableBuilder(
                  listenable: widget.api,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('shared-feeding-reminder-settings'),
                        tooltip: context.l10n.feedingReminder,
                        onPressed: widget.api.connected
                            ? _openReminderSettings
                            : null,
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                      IconButton(
                        tooltip: sharedText(
                          context,
                          'Edit Animal',
                          'Tier bearbeiten',
                        ),
                        onPressed: widget.api.connected ? _openEdit : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _LoadFailure(onRetry: _reload);
        final animal = snapshot.data!;
        final active = animal['status'] == 'active';
        final box = _boxes
            .where((entry) => entry['id'] == animal['boxId'])
            .firstOrNull;
        return ListenableBuilder(
          listenable: widget.api,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _feedingInformation(animal, due: true),
              SharedPictureGallery(
                api: widget.api,
                kind: 'animals',
                recordId: widget.id,
                active: active,
                change: _change,
                onChanged: _reload,
              ),
              const SizedBox(height: 12),
              Text(
                animalLabel(animal),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if ((animal['latinName'] as String?)?.isNotEmpty ?? false)
                Text(
                  animal['latinName'] as String,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              _feedingInformation(animal, due: false),
              _DetailRow(
                label: sharedText(context, 'Status', 'Status'),
                value: animal['status'] as String?,
              ),
              _DetailRow(
                label: sharedText(context, 'Box', 'Box'),
                value: box == null ? null : boxLabel(box),
                onTap: box == null ? null : () => _openBox(recordId(box)),
              ),
              _DetailRow(
                label: sharedText(context, 'Category', 'Kategorie'),
                value: sharedCategoryLabel(
                  context,
                  animal['category'] as String?,
                ),
              ),
              _DetailRow(
                label: sharedText(context, 'Subcategory', 'Unterkategorie'),
                value: sharedSubcategoryLabel(
                  context,
                  animal['subcategory'] as String?,
                ),
              ),
              _DetailRow(
                label: sharedText(context, 'Sex', 'Geschlecht'),
                value: sharedSexLabel(context, animal['sex'] as String?),
              ),
              _DetailRow(
                label: sharedText(
                  context,
                  'Day temperature',
                  'Tagestemperatur',
                ),
                value: '${animal['tempMin']}–${animal['tempMax']} °C',
              ),
              if (animal['nighttimeTemperatureMin'] != null ||
                  animal['nighttimeTemperatureMax'] != null)
                _DetailRow(
                  label: sharedText(
                    context,
                    'Night temperature',
                    'Nachttemperatur',
                  ),
                  value:
                      '${animal['nighttimeTemperatureMin']}–${animal['nighttimeTemperatureMax']} °C',
                ),
              _DetailRow(
                label: sharedText(context, 'Humidity', 'Feuchtigkeit'),
                value: '${animal['humidityMin']}–${animal['humidityMax']} %',
              ),
              _DetailRow(
                label: sharedText(
                  context,
                  'Origin / habitat',
                  'Herkunft / Lebensraum',
                ),
                value: animal['originHabitat'] as String?,
              ),
              _DetailRow(
                label: sharedText(context, 'Rest / dormancy', 'Ruhezeiten'),
                value: animal['restOrDormancyPeriods'] as String?,
              ),
              _DetailRow(
                label: sharedText(context, 'Notes', 'Notizen'),
                value: animal['notes'] as String?,
              ),
              if (!active)
                _DetailRow(
                  label: sharedText(context, 'Archive reason', 'Archivgrund'),
                  value: animal['archiveReason'] == null
                      ? null
                      : sharedArchiveReasonLabel(
                          context,
                          animal['archiveReason'] as String,
                          box: false,
                        ),
                ),
              const Divider(),
              for (final item in [
                (
                  SharedHistoryKind.feedings,
                  Icons.restaurant,
                  'Feeding history',
                  'Fütterungsverlauf',
                ),
                (
                  SharedHistoryKind.weights,
                  Icons.monitor_weight_outlined,
                  'Weight history',
                  'Gewichtsverlauf',
                ),
                (
                  SharedHistoryKind.shedding,
                  Icons.auto_awesome,
                  'Shedding history',
                  'Häutungsverlauf',
                ),
              ])
                if ((item.$1 != SharedHistoryKind.weights ||
                        animal['showWeightOnDetail'] != false) &&
                    (item.$1 != SharedHistoryKind.shedding ||
                        animal['showSheddingOnDetail'] != false))
                  ListTile(
                    leading: Icon(item.$2),
                    title: Text(sharedText(context, item.$3, item.$4)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SharedHistoryPage(
                          api: widget.api,
                          animalId: widget.id,
                          kind: item.$1,
                          active: active,
                          change: widget.change,
                        ),
                      ),
                    ),
                  ),
              const Divider(),
              if (active) ...[
                OutlinedButton.icon(
                  onPressed: widget.api.connected
                      ? () async {
                          final choice = await showArchiveDialog(
                            context,
                            reasons: const [
                              'sold',
                              'traded',
                              'deceased',
                              'rehomed',
                              'other',
                            ],
                          );
                          if (choice == null) return;
                          await _change(() async {
                            await widget.api.archiveAnimal(
                              widget.id,
                              choice.$1,
                              choice.$2,
                            );
                          });
                        }
                      : null,
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(
                    sharedText(context, 'Archive Animal', 'Tier archivieren'),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.api.connected
                      ? () => _change(() async {
                          await widget.api.duplicateAnimal(
                            widget.id,
                            animal['boxId'] as int,
                            animal['commonName'] as String,
                          );
                        })
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(
                    sharedText(context, 'Duplicate Animal', 'Tier duplizieren'),
                  ),
                ),
              ] else ...[
                FilledButton.tonalIcon(
                  onPressed: widget.api.connected
                      ? () async {
                          final destination = await selectActiveBox(
                            context,
                            widget.boxes,
                          );
                          if (destination == null) return;
                          await _change(() async {
                            await widget.api.restoreAnimal(
                              widget.id,
                              destination,
                            );
                          });
                        }
                      : null,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: Text(
                    sharedText(
                      context,
                      'Restore Animal',
                      'Tier wiederherstellen',
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.api.connected
                      ? () async {
                          if (!await confirmPermanentDeletion(context)) return;
                          final done = await _change(() async {
                            await widget.api.deleteAnimal(widget.id);
                          });
                          if (done && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(
                    sharedText(
                      context,
                      'Delete permanently',
                      'Endgültig löschen',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class SharedPictureGallery extends StatefulWidget {
  const SharedPictureGallery({
    super.key,
    required this.api,
    required this.kind,
    required this.recordId,
    required this.active,
    required this.change,
    required this.onChanged,
  });
  final SharedApiClient api;
  final String kind;
  final int recordId;
  final bool active;
  final SharedChange change;
  final VoidCallback onChanged;

  @override
  State<SharedPictureGallery> createState() => _SharedPictureGalleryState();
}

class _SharedPictureGalleryState extends State<SharedPictureGallery> {
  late Future<List<Map<String, dynamic>>> _pictures;

  @override
  void initState() {
    super.initState();
    _pictures = widget.api.pictures(widget.kind, widget.recordId);
  }

  void _reload() => setState(() {
    _pictures = widget.api.pictures(widget.kind, widget.recordId);
  });

  Future<void> _add() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        if (mounted) _showFailure(context);
        return;
      }
      final name = picked.name;
      final lower = name.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      final saved = await widget.change(() async {
        await widget.api.addPicture(
          widget.kind,
          widget.recordId,
          name,
          mime,
          bytes,
        );
      });
      if (!mounted) return;
      if (saved) {
        _reload();
        widget.onChanged();
      } else {
        _showFailure(context);
      }
    } catch (_) {
      if (mounted) _showFailure(context);
    }
  }

  Future<void> _pictureAction(
    Map<String, dynamic> picture,
    String action,
  ) async {
    final mediaId = picture['mediaId'] as int;
    if (action == 'delete' && !await confirmPermanentDeletion(context)) {
      return;
    }
    final saved = await widget.change(() async {
      if (action == 'primary') {
        await widget.api.setPrimaryPicture(
          widget.kind,
          widget.recordId,
          mediaId,
        );
      } else {
        await widget.api.removePicture(widget.kind, widget.recordId, mediaId);
      }
    });
    if (!mounted) return;
    if (saved) {
      _reload();
      widget.onChanged();
    } else {
      _showFailure(context);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _pictures,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return SizedBox(
          height: 48,
          child: snapshot.hasError
              ? _LoadFailure(onRetry: _reload)
              : const Center(child: CircularProgressIndicator()),
        );
      }
      final pictures = snapshot.data!;
      final primary =
          pictures
              .where((picture) => picture['isPrimary'] == true)
              .firstOrNull ??
          pictures.firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: primary == null
                  ? ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          widget.kind == 'boxes'
                              ? Icons.inventory_2_outlined
                              : Icons.emoji_nature_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Image.network(
                      widget.api.mediaUrl(primary['mediaId'] as int).toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.l10n.pictureGallery),
            children: [
              if (pictures.isNotEmpty)
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final picture in pictures)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Image.network(
                                widget.api
                                    .mediaUrl(picture['mediaId'] as int)
                                    .toString(),
                                height: 150,
                                width: 150,
                                fit: BoxFit.cover,
                              ),
                              if (picture['isPrimary'] == true)
                                const Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Icon(Icons.star, color: Colors.amber),
                                ),
                              if (widget.active)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: PopupMenuButton<String>(
                                    enabled: widget.api.connected,
                                    onSelected: (action) =>
                                        _pictureAction(picture, action),
                                    itemBuilder: (context) => [
                                      if (picture['isPrimary'] != true)
                                        PopupMenuItem(
                                          value: 'primary',
                                          child: Text(
                                            sharedText(
                                              context,
                                              'Set as primary',
                                              'Als Hauptbild setzen',
                                            ),
                                          ),
                                        ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          sharedText(
                                            context,
                                            'Delete picture',
                                            'Bild löschen',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (pictures.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.l10n.noPictures),
                ),
            ],
          ),
          if (widget.active)
            TextButton.icon(
              onPressed: widget.api.connected ? _add : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                sharedText(context, 'Add picture', 'Bild hinzufügen'),
              ),
            ),
        ],
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.onTap});
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: onTap == null
                ? Text(value!)
                : InkWell(
                    onTap: onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            value!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: onRetry,
      child: Text(
        sharedText(
          context,
          'Could not load. Retry',
          'Laden fehlgeschlagen. Erneut versuchen',
        ),
      ),
    ),
  );
}

void _showFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sharedText(
          context,
          'The request failed. Reload and check the server state.',
          'Die Anfrage ist fehlgeschlagen. Neu laden und Serverstand prüfen.',
        ),
      ),
    ),
  );
}

Future<(String, String?)?> showArchiveDialog(
  BuildContext context, {
  required List<String> reasons,
}) => showDialog<(String, String?)>(
  context: context,
  builder: (_) => _ArchiveDialog(reasons: reasons),
);

class _ArchiveDialog extends StatefulWidget {
  const _ArchiveDialog({required this.reasons});
  final List<String> reasons;

  @override
  State<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<_ArchiveDialog> {
  late String _reason = widget.reasons.first;
  final TextEditingController _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(sharedText(context, 'Archive', 'Archivieren')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reason,
          items: [
            for (final value in widget.reasons)
              DropdownMenuItem(
                value: value,
                child: Text(
                  sharedArchiveReasonLabel(
                    context,
                    value,
                    box: widget.reasons.contains('replaced'),
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _reason = value);
          },
        ),
        TextField(
          controller: _notes,
          decoration: InputDecoration(
            labelText: sharedText(context, 'Notes', 'Notizen'),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        onPressed: () {
          final notes = _notes.text.trim();
          Navigator.of(context).pop((_reason, notes.isEmpty ? null : notes));
        },
        child: Text(sharedText(context, 'Archive', 'Archivieren')),
      ),
    ],
  );
}

Future<bool> confirmPermanentDeletion(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          sharedText(context, 'Delete permanently?', 'Endgültig löschen?'),
        ),
        content: Text(
          sharedText(
            context,
            'This cannot be undone.',
            'Dies kann nicht rückgängig gemacht werden.',
          ),
        ),
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
    ) ??
    false;

Future<int?> selectActiveBox(
  BuildContext context,
  List<Map<String, dynamic>> boxes,
) async => showDialog<int>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(sharedText(context, 'Choose Box', 'Box auswählen')),
    children: [
      for (final box in boxes.where((box) => box['status'] == 'active'))
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(recordId(box)),
          child: Text(boxLabel(box)),
        ),
    ],
  ),
);
