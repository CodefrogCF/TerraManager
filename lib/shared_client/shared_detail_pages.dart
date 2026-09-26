import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/presentation/widgets/responsive_picture_frame.dart';
import '../core/presentation/widgets/constrained_page_width.dart';
import '../core/database/enums/birth_date_accuracy.dart';
import '../features/settings/animal_name_order.dart';
import '../features/settings/animal_sort_order.dart';
import '../features/settings/app_settings_controller.dart';
import '../features/media/presentation/pages/full_screen_image_page.dart';
import '../l10n/app_localizations_context.dart';
import '../l10n/app_localizations_labels.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_detail_navigation.dart';
import 'shared_feeding_reminder_page.dart';
import 'shared_forms.dart';
import 'shared_history_page.dart';
import 'shared_text.dart';

void _leaveRemovedDetail(BuildContext context) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  final messenger = ScaffoldMessenger.of(context);
  final message = sharedText(
    context,
    'This record is no longer available in the current overview.',
    'Dieser Eintrag ist in der aktuellen Übersicht nicht mehr verfügbar.',
  );
  Navigator.of(context).pop();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

class SharedBoxDetailPage extends StatefulWidget {
  const SharedBoxDetailPage({
    super.key,
    required this.api,
    required this.id,
    required this.boxes,
    required this.animals,
    required this.connected,
    required this.change,
    this.navigationContext,
  });
  final SharedApiClient api;
  final int id;
  final List<Map<String, dynamic>> boxes;
  final List<Map<String, dynamic>> animals;
  final bool connected;
  final SharedChange change;
  final SharedDetailNavigationContext? navigationContext;

  @override
  State<SharedBoxDetailPage> createState() => _SharedBoxDetailPageState();
}

class _SharedBoxDetailPageState extends State<SharedBoxDetailPage>
    with WidgetsBindingObserver {
  late int _id;
  SharedDetailNavigationContext? _navigationContext;
  late Future<Map<String, dynamic>> _record;
  late List<Map<String, dynamic>> _animals;
  Timer? _timer;
  bool _foreground = true;
  bool _polling = false;
  bool _switching = false;
  String? _navigationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _id = widget.id;
    _navigationContext = widget.navigationContext;
    _animals = widget.animals;
    _record = widget.api.box(_id);
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
        _switching ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _polling = true;
    final id = _id;
    try {
      final box = await widget.api.box(id);
      final animals = await widget.api.animals();
      final navigation = _navigationContext;
      final boxes = navigation == null ? null : await widget.api.boxes();
      if (navigation != null &&
          (box['status'] == 'archived') != navigation.archived) {
        if (mounted && id == _id) _leaveRemovedDetail(context);
        return;
      }
      final updatedNavigation = navigation == null || boxes == null
          ? null
          : navigation.withRecords(_orderedBoxIds(navigation, boxes));
      if (navigation != null && updatedNavigation == null) {
        if (mounted && id == _id) _leaveRemovedDetail(context);
        return;
      }
      if (mounted &&
          id == _id &&
          _foreground &&
          ModalRoute.of(context)?.isCurrent == true) {
        setState(() {
          _record = Future.value(box);
          _animals = animals;
          if (updatedNavigation != null) _navigationContext = updatedNavigation;
        });
      }
    } on SharedApiException catch (error) {
      if (error.status == 404 && mounted && id == _id) {
        _leaveRemovedDetail(context);
      }
      // Other failures keep the last readable record.
    } catch (_) {
      // Keep the last readable record; the page's manual reload reports errors.
    } finally {
      _polling = false;
    }
  }

  List<int> _orderedBoxIds(
    SharedDetailNavigationContext navigation,
    List<Map<String, dynamic>> boxes,
  ) => sortSharedBoxesForOverview(
    boxes.where((box) => (box['status'] == 'archived') == navigation.archived),
    navigation.boxSortOrder!,
  ).map(recordId).toList();

  Future<void> _switchAdjacent({required bool next}) async {
    final navigation = _navigationContext;
    if (navigation == null || _switching) return;
    setState(() => _switching = true);
    try {
      final boxes = await widget.api.boxes();
      final ids = _orderedBoxIds(navigation, boxes);
      final current = navigation.withRecords(ids);
      if (!mounted) return;
      if (current == null) {
        _leaveRemovedDetail(context);
        return;
      }
      final targetId = next ? current.nextRecordId : current.previousRecordId;
      if (targetId == null) {
        setState(() => _navigationContext = current);
        return;
      }
      Map<String, dynamic> box;
      try {
        box = await widget.api.box(targetId);
      } on SharedApiException catch (error) {
        if (error.status != 404) rethrow;
        if (mounted) {
          setState(() {
            _navigationContext = current.withRecords(
              ids.where((id) => id != targetId),
            );
            _navigationError = sharedText(
              context,
              'The adjacent Box is no longer available.',
              'Die benachbarte Box ist nicht mehr verfügbar.',
            );
          });
        }
        return;
      }
      if (box['status'] != (navigation.archived ? 'archived' : 'active')) {
        if (mounted) {
          setState(() {
            _navigationContext = current.withRecords(
              ids.where((id) => id != targetId),
            );
            _navigationError = sharedText(
              context,
              'The adjacent Box changed its archive state.',
              'Die benachbarte Box hat ihren Archivstatus geändert.',
            );
          });
        }
        return;
      }
      final animals = await widget.api.animals();
      if (!mounted) return;
      setState(() {
        _id = targetId;
        _record = Future.value(box);
        _animals = animals;
        _navigationContext = current.withRecords(ids, selectedId: targetId);
        _navigationError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _navigationError = sharedText(
            context,
            'Could not load the adjacent Box. Try again.',
            'Die benachbarte Box konnte nicht geladen werden. Versuche es erneut.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  void _reload() => setState(() {
    _record = widget.api.box(_id);
  });

  String? _dateTimeLabel(String? source) {
    final date = DateTime.tryParse(source ?? '');
    if (date == null) return null;
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

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
      if (mounted) {
        _reload();
        unawaited(_refreshVisible());
      }
    } catch (_) {
      if (mounted) _showFailure(context);
    }
  }

  Future<bool> _change(
    Future<void> Function() action, {
    bool clearNavigation = false,
  }) async {
    final saved = await widget.change(action);
    if (!mounted) return false;
    if (saved) {
      if (clearNavigation) _navigationContext = null;
      _reload();
    } else {
      _showFailure(context);
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) => ConstrainedPageWidth(
    child: Scaffold(
      appBar: AppBar(
        title: Text('Box $_id'),
        actions: [
          FutureBuilder<Map<String, dynamic>>(
            future: _record,
            builder: (context, snapshot) => snapshot.data?['status'] == 'active'
                ? ListenableBuilder(
                    listenable: widget.api,
                    builder: (context, _) => IconButton(
                      tooltip: sharedText(
                        context,
                        'Edit Box',
                        'Box bearbeiten',
                      ),
                      onPressed: widget.api.connected ? _openEdit : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
        bottom: _navigationContext == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: SharedDetailNavigationBar(
                  contextData: _navigationContext!,
                  busy: _switching,
                  onPrevious: () => _switchAdjacent(next: false),
                  onNext: () => _switchAdjacent(next: true),
                ),
              ),
      ),
      body: ConstrainedPageWidth(
        maxWidth: 760,
        child: SharedDetailSwipeRegion(
          enabled: _navigationContext != null && !_switching,
          onPrevious: () => _switchAdjacent(next: false),
          onNext: () => _switchAdjacent(next: true),
          child: FutureBuilder<Map<String, dynamic>>(
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
              final assignedAnimals = _animals.where(
                (animal) =>
                    animal['boxId'] == _id && animal['status'] != 'archived',
              );
              final nameOrder = assignedAnimals.isEmpty
                  ? AnimalNameOrder.commonNameFirst
                  : AppSettingsScope.of(context).animalNameOrder;
              final animals = sortSharedAnimalsForOverview(
                assignedAnimals,
                order: AnimalSortOrder.displayNameAscending,
                nameOrder: nameOrder,
              );
              return ListenableBuilder(
                listenable: widget.api,
                builder: (context, _) => ListView(
                  key: ValueKey<String>('shared-box-detail-list-$_id'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_switching) const LinearProgressIndicator(),
                    if (_navigationError != null)
                      Text(
                        _navigationError!,
                        key: const Key('shared-detail-navigation-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (_) {},
                      child: SharedPictureGallery(
                        key: ValueKey<String>('shared-box-gallery-$_id'),
                        api: widget.api,
                        kind: 'boxes',
                        recordId: _id,
                        active: active,
                        change: _change,
                        onChanged: _reload,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ((box['name'] as String?)?.trim().isNotEmpty ?? false)
                          ? (box['name'] as String).trim()
                          : 'Box $_id',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (!active) ...[
                      Text(
                        context.l10n.archived,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _DetailRow(
                        label: context.l10n.reason,
                        value: box['archiveReason'] == null
                            ? context.l10n.notSpecified
                            : sharedArchiveReasonLabel(
                                context,
                                box['archiveReason'] as String,
                                box: true,
                              ),
                      ),
                      _DetailRow(
                        label: context.l10n.archiveDate,
                        value:
                            _dateTimeLabel(box['archivedAt'] as String?) ??
                            context.l10n.notSpecified,
                      ),
                      _DetailRow(
                        label: context.l10n.archiveNote,
                        value: box['archiveNotes'] as String?,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      context.l10n.dimensions,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _DetailRow(
                      label: context.l10n.width,
                      value: box['widthCm'] == null
                          ? null
                          : '${box['widthCm']} cm',
                    ),
                    _DetailRow(
                      label: context.l10n.height,
                      value: box['heightCm'] == null
                          ? null
                          : '${box['heightCm']} cm',
                    ),
                    _DetailRow(
                      label: context.l10n.depth,
                      value: box['depthCm'] == null
                          ? null
                          : '${box['depthCm']} cm',
                    ),
                    _DetailRow(label: 'QR ID', value: box['qrId']?.toString()),
                    _DetailRow(
                      label: context.l10n.boxId,
                      value: _id.toString(),
                    ),
                    _DetailRow(
                      label: context.l10n.created,
                      value: _dateTimeLabel(box['createdAt'] as String?),
                    ),
                    _DetailRow(
                      label: context.l10n.updated,
                      value: _dateTimeLabel(box['updatedAt'] as String?),
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
                    const Divider(),
                    Text(
                      sharedText(context, 'Animals', 'Tiere'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final animal in animals)
                      Card(
                        child: ListTile(
                          key: Key('assigned-animal-${recordId(animal)}'),
                          leading: SharedThumbnail(
                            key: Key(
                              'assigned-animal-thumbnail-${recordId(animal)}',
                            ),
                            api: widget.api,
                            mediaId: animal['pictureMediaId'] as int?,
                            fallback: Icons.emoji_nature_outlined,
                          ),
                          title: Text(
                            animalLabel(
                              animal,
                              order: AppSettingsScope.of(context)
                                  .animalNameOrder,
                            ),
                          ),
                          subtitle: Text(
                            (AppSettingsScope.of(context).animalNameOrder ==
                                            AnimalNameOrder.commonNameFirst
                                        ? animal['latinName']
                                        : animal['commonName'])
                                    ?.toString()
                                    .trim() ??
                                '',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SharedAnimalDetailPage(
                                api: widget.api,
                                id: recordId(animal),
                                boxes: widget.boxes,
                                connected: widget.connected,
                                change: widget.change,
                                navigationContext:
                                    SharedDetailNavigationContext.boxAnimals(
                                      recordIds: animals.map(recordId),
                                      currentRecordId: recordId(animal),
                                      boxId: _id,
                                      nameOrder: nameOrder,
                                    ),
                              ),
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
                                    _id,
                                    choice.$1,
                                    choice.$2,
                                  );
                                }, clearNavigation: true);
                              }
                            : null,
                        icon: const Icon(Icons.archive_outlined),
                        label: Text(
                          sharedText(context, 'Archive Box', 'Box archivieren'),
                        ),
                      ),
                    ] else ...[
                      FilledButton.tonalIcon(
                        onPressed: widget.api.connected
                            ? () => _change(() async {
                                await widget.api.restoreBox(_id);
                              }, clearNavigation: true)
                            : null,
                        icon: const Icon(Icons.unarchive_outlined),
                        label: Text(
                          sharedText(
                            context,
                            'Restore Box',
                            'Box wiederherstellen',
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.api.connected
                            ? () async {
                                if (!await confirmPermanentDeletion(context)) {
                                  return;
                                }
                                final done = await _change(() async {
                                  await widget.api.deleteBox(_id);
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
        ),
      ),
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
    this.navigationContext,
  });
  final SharedApiClient api;
  final int id;
  final List<Map<String, dynamic>> boxes;
  final bool connected;
  final SharedChange change;
  final SharedDetailNavigationContext? navigationContext;

  @override
  State<SharedAnimalDetailPage> createState() => _SharedAnimalDetailPageState();
}

class _SharedAnimalDetailPageState extends State<SharedAnimalDetailPage>
    with WidgetsBindingObserver {
  late int _id;
  SharedDetailNavigationContext? _navigationContext;
  late Future<Map<String, dynamic>> _record;
  late Future<List<Map<String, dynamic>>> _feedings;
  late Future<List<Map<String, dynamic>>?> _weights;
  late Future<List<Map<String, dynamic>>?> _shedding;
  late List<Map<String, dynamic>> _boxes;
  Timer? _timer;
  bool _foreground = true;
  bool _polling = false;
  bool _switching = false;
  String? _navigationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _id = widget.id;
    _navigationContext = widget.navigationContext;
    _boxes = widget.boxes;
    _record = widget.api.animal(_id);
    _feedings = widget.api.feedings(_id);
    _weights = _optionalHistory(() => widget.api.weights(_id));
    _shedding = _optionalHistory(() => widget.api.shedding(_id));
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
        _switching ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _polling = true;
    final id = _id;
    try {
      final animal = await widget.api.animal(id);
      final feedings = await widget.api.feedings(id);
      final weights = await _optionalHistory(() => widget.api.weights(id));
      final shedding = await _optionalHistory(() => widget.api.shedding(id));
      final boxes = await widget.api.boxes();
      final navigation = _navigationContext;
      final animals = navigation == null ? null : await widget.api.animals();
      if (navigation != null &&
          ((animal['status'] == 'archived') != navigation.archived ||
              (navigation.source == SharedDetailSource.boxAnimals &&
                  animal['boxId'] != navigation.sourceBoxId))) {
        if (mounted && id == _id) _leaveRemovedDetail(context);
        return;
      }
      final updatedNavigation = navigation == null || animals == null
          ? null
          : navigation.withRecords(_orderedAnimalIds(navigation, animals));
      if (navigation != null && updatedNavigation == null) {
        if (mounted && id == _id) _leaveRemovedDetail(context);
        return;
      }
      if (mounted &&
          id == _id &&
          _foreground &&
          ModalRoute.of(context)?.isCurrent == true) {
        setState(() {
          _record = Future.value(animal);
          _feedings = Future.value(feedings);
          _weights = Future.value(weights);
          _shedding = Future.value(shedding);
          _boxes = boxes;
          if (updatedNavigation != null) _navigationContext = updatedNavigation;
        });
      }
    } on SharedApiException catch (error) {
      if (error.status == 404 && mounted && id == _id) {
        _leaveRemovedDetail(context);
      }
    } catch (_) {
      // Keep the last readable record; the page's manual reload reports errors.
    } finally {
      _polling = false;
    }
  }

  List<int> _orderedAnimalIds(
    SharedDetailNavigationContext navigation,
    List<Map<String, dynamic>> animals,
  ) {
    if (navigation.source == SharedDetailSource.boxAnimals) {
      return sortSharedAnimalsForOverview(
        animals.where(
          (animal) =>
              animal['boxId'] == navigation.sourceBoxId &&
              animal['status'] != 'archived',
        ),
        order: AnimalSortOrder.displayNameAscending,
        nameOrder: navigation.animalNameOrder!,
      ).map(recordId).toList();
    }
    final sorted = sortSharedAnimalsForOverview(
      animals.where(
        (animal) => (animal['status'] == 'archived') == navigation.archived,
      ),
      order: navigation.animalSortOrder!,
      nameOrder: navigation.animalNameOrder!,
    );
    return sharedAnimalOverviewRows(
      context,
      sorted,
      groupCategories: navigation.groupCategories,
    ).whereType<Map<String, dynamic>>().map(recordId).toList();
  }

  Future<void> _switchAdjacent({required bool next}) async {
    final navigation = _navigationContext;
    if (navigation == null || _switching) return;
    setState(() => _switching = true);
    try {
      final animals = await widget.api.animals();
      if (!mounted) return;
      final ids = _orderedAnimalIds(navigation, animals);
      final current = navigation.withRecords(ids);
      if (current == null) {
        _leaveRemovedDetail(context);
        return;
      }
      final targetId = next ? current.nextRecordId : current.previousRecordId;
      if (targetId == null) {
        setState(() => _navigationContext = current);
        return;
      }
      Map<String, dynamic> animal;
      try {
        animal = await widget.api.animal(targetId);
      } on SharedApiException catch (error) {
        if (error.status != 404) rethrow;
        if (mounted) {
          setState(() {
            _navigationContext = current.withRecords(
              ids.where((id) => id != targetId),
            );
            _navigationError = sharedText(
              context,
              'The adjacent Animal is no longer available.',
              'Das benachbarte Tier ist nicht mehr verfügbar.',
            );
          });
        }
        return;
      }
      if ((animal['status'] == 'archived') != navigation.archived ||
          (navigation.source == SharedDetailSource.boxAnimals &&
              animal['boxId'] != navigation.sourceBoxId)) {
        if (mounted) {
          setState(() {
            _navigationContext = current.withRecords(
              ids.where((id) => id != targetId),
            );
            _navigationError = sharedText(
              context,
              'The adjacent Animal left this overview.',
              'Das benachbarte Tier gehört nicht mehr zu dieser Übersicht.',
            );
          });
        }
        return;
      }
      final feedings = await widget.api.feedings(targetId);
      final weights = await _optionalHistory(
        () => widget.api.weights(targetId),
      );
      final shedding = await _optionalHistory(
        () => widget.api.shedding(targetId),
      );
      final boxes = await widget.api.boxes();
      if (!mounted) return;
      setState(() {
        _id = targetId;
        _record = Future.value(animal);
        _feedings = Future.value(feedings);
        _weights = Future.value(weights);
        _shedding = Future.value(shedding);
        _boxes = boxes;
        _navigationContext = current.withRecords(ids, selectedId: targetId);
        _navigationError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _navigationError = sharedText(
            context,
            'Could not load the adjacent Animal. Try again.',
            'Das benachbarte Tier konnte nicht geladen werden. Versuche es erneut.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  void _reload() => setState(() {
    _record = widget.api.animal(_id);
    _feedings = widget.api.feedings(_id);
    _weights = _optionalHistory(() => widget.api.weights(_id));
    _shedding = _optionalHistory(() => widget.api.shedding(_id));
  });

  Future<List<Map<String, dynamic>>?> _optionalHistory(
    Future<List<Map<String, dynamic>>> Function() load,
  ) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

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

  String? _dateOnlyLabel(String? source) {
    final date = DateTime.tryParse(source ?? '');
    return date == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  }

  String _temperatureNumber(Object? value) => NumberFormat(
    '0.0',
    Localizations.localeOf(context).toLanguageTag(),
  ).format((value as num).toDouble());

  String? _temperatureRange(Object? minimum, Object? maximum) {
    if (minimum == null && maximum == null) return null;
    if (minimum != null && maximum != null) {
      return context.l10n.temperatureRange(
        _temperatureNumber(minimum),
        _temperatureNumber(maximum),
      );
    }
    return '${_temperatureNumber(minimum ?? maximum)} °C';
  }

  Widget _weightSection(Map<String, dynamic> animal, bool active) =>
      FutureBuilder<List<Map<String, dynamic>>?>(
        future: _weights,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          final weights = [...snapshot.data!]
            ..sort(
              (a, b) => (b['measuredAt'] as String? ?? '').compareTo(
                a['measuredAt'] as String? ?? '',
              ),
            );
          final latest = weights.firstOrNull;
          final grams = latest?['weightGrams'] as num?;
          final legacy = (animal['weight'] as String?)?.trim();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (grams != null)
                _DetailRow(
                  key: const Key('shared-weight-detail'),
                  label: context.l10n.weight,
                  value: context.l10n.weightMeasurement(
                    NumberFormat(
                      '0.##',
                      Localizations.localeOf(context).toLanguageTag(),
                    ).format(grams),
                  ),
                )
              else if (legacy != null && legacy.isNotEmpty)
                _DetailRow(label: context.l10n.weight, value: legacy),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: active && widget.api.connected
                        ? () => _openHistory(
                            SharedHistoryKind.weights,
                            active: true,
                            createOnOpen: true,
                          )
                        : null,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addWeightMeasurement),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _openHistory(SharedHistoryKind.weights, active: active),
                    icon: const Icon(Icons.history),
                    label: Text(context.l10n.weightHistory),
                  ),
                ],
              ),
            ],
          );
        },
      );

  Widget _sheddingSection(bool active) =>
      FutureBuilder<List<Map<String, dynamic>>?>(
        future: _shedding,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          final entries = [...snapshot.data!]
            ..sort(
              (a, b) => (b['shedAt'] as String? ?? '').compareTo(
                a['shedAt'] as String? ?? '',
              ),
            );
          final latest = DateTime.tryParse(
            entries.firstOrNull?['shedAt'] as String? ?? '',
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(
                key: const Key('shared-shedding-detail'),
                label: context.l10n.latestShedding,
                value: latest == null
                    ? context.l10n.noSheddingEventsAvailable
                    : _dateLabel(context, latest),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: active && widget.api.connected
                        ? () => _openHistory(
                            SharedHistoryKind.shedding,
                            active: true,
                            createOnOpen: true,
                          )
                        : null,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addSheddingEvent),
                  ),
                  TextButton.icon(
                    onPressed: () => _openHistory(
                      SharedHistoryKind.shedding,
                      active: active,
                    ),
                    icon: const Icon(Icons.history),
                    label: Text(context.l10n.sheddingHistory),
                  ),
                ],
              ),
            ],
          );
        },
      );

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
    await _openHistory(SharedHistoryKind.feedings, active: active);
  }

  Future<void> _openHistory(
    SharedHistoryKind kind, {
    required bool active,
    bool createOnOpen = false,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedHistoryPage(
          api: widget.api,
          animalId: _id,
          kind: kind,
          active: active,
          change: widget.change,
          createOnOpen: createOnOpen,
        ),
      ),
    );
    if (mounted) {
      _reload();
      unawaited(_refreshVisible());
    }
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
      if (mounted) {
        _reload();
        unawaited(_refreshVisible());
      }
    } catch (_) {
      if (mounted) _showFailure(context);
    }
  }

  Future<void> _openReminderSettings() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SharedFeedingReminderPage(
          api: widget.api,
          animalId: _id,
          change: widget.change,
        ),
      ),
    );
    if (mounted) {
      _reload();
      unawaited(_refreshVisible());
    }
  }

  Future<bool> _change(
    Future<void> Function() action, {
    bool clearNavigation = false,
  }) async {
    final saved = await widget.change(action);
    if (!mounted) return false;
    if (saved) {
      if (clearNavigation) _navigationContext = null;
      _reload();
    } else {
      _showFailure(context);
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) => ConstrainedPageWidth(
    child: Scaffold(
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
                          tooltip: context.l10n.feedingHistory,
                          onPressed: () => _openFeedingHistory(true),
                          icon: const Icon(Icons.restaurant_outlined),
                        ),
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
        bottom: _navigationContext == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: SharedDetailNavigationBar(
                  contextData: _navigationContext!,
                  busy: _switching,
                  onPrevious: () => _switchAdjacent(next: false),
                  onNext: () => _switchAdjacent(next: true),
                ),
              ),
      ),
      body: ConstrainedPageWidth(
        maxWidth: 760,
        child: SharedDetailSwipeRegion(
          enabled: _navigationContext != null && !_switching,
          onPrevious: () => _switchAdjacent(next: false),
          onNext: () => _switchAdjacent(next: true),
          child: FutureBuilder<Map<String, dynamic>>(
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
                  key: ValueKey<String>('shared-animal-detail-list-$_id'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_switching) const LinearProgressIndicator(),
                    if (_navigationError != null)
                      Text(
                        _navigationError!,
                        key: const Key('shared-detail-navigation-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    _feedingInformation(animal, due: true),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (_) {},
                      child: SharedPictureGallery(
                        key: ValueKey<String>('shared-animal-gallery-$_id'),
                        api: widget.api,
                        kind: 'animals',
                        recordId: _id,
                        active: active,
                        change: _change,
                        onChanged: _reload,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      animalLabel(
                        animal,
                        order: AppSettingsScope.of(context).animalNameOrder,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (((AppSettingsScope.of(context).animalNameOrder ==
                                        AnimalNameOrder.commonNameFirst
                                    ? animal['latinName']
                                    : animal['commonName'])
                                as String?)
                            ?.trim()
                            .isNotEmpty ==
                        true)
                      Text(
                        (AppSettingsScope.of(context).animalNameOrder ==
                                    AnimalNameOrder.commonNameFirst
                                ? animal['latinName']
                                : animal['commonName'])
                            as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 8),
                    _feedingInformation(animal, due: false),
                    _DetailRow(
                      label: sharedText(context, 'Status', 'Status'),
                      value: active
                          ? sharedText(context, 'Active', 'Aktiv')
                          : sharedText(context, 'Archived', 'Archiviert'),
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
                      label: sharedText(
                        context,
                        'Subcategory',
                        'Unterkategorie',
                      ),
                      value: sharedSubcategoryLabel(
                        context,
                        animal['subcategory'] as String?,
                      ),
                    ),
                    _DetailRow(
                      label: sharedText(context, 'Sex', 'Geschlecht'),
                      value: sharedSexLabel(context, animal['sex'] as String?),
                    ),
                    if (DateTime.tryParse(animal['birthDate'] as String? ?? '')
                        case final birthDate?)
                      _DetailRow(
                        label: context.l10n.birthDateLowercase,
                        value: MaterialLocalizations.of(context)
                            .formatMediumDate(birthDate.toLocal()),
                      ),
                    if (BirthDateAccuracy.values
                            .where(
                              (value) =>
                                  value.name == animal['birthDateAccuracy'],
                            )
                            .firstOrNull
                        case final accuracy?)
                      _DetailRow(
                        label: context.l10n.birthDateAccuracyLowercase,
                        value: context.l10n.birthAccuracyLabel(accuracy),
                      ),
                    _DetailRow(
                      key: const Key('daytime-temperature-detail'),
                      label: context.l10n.daytimeTemperature,
                      value: _temperatureRange(
                        animal['tempMin'],
                        animal['tempMax'],
                      ),
                    ),
                    if (animal['nighttimeTemperatureMin'] != null ||
                        animal['nighttimeTemperatureMax'] != null ||
                        animal['nighttimeTemperature'] != null)
                      _DetailRow(
                        label: sharedText(
                          context,
                          'Night temperature',
                          'Nachttemperatur',
                        ),
                        key: const Key('nighttime-temperature-detail'),
                        value: _temperatureRange(
                          animal['nighttimeTemperatureMin'] ??
                              animal['nighttimeTemperature'],
                          animal['nighttimeTemperatureMax'] ??
                              animal['nighttimeTemperature'],
                        ),
                      ),
                    _DetailRow(
                      label: sharedText(context, 'Humidity', 'Feuchtigkeit'),
                      value:
                          animal['humidityMin'] == null &&
                              animal['humidityMax'] == null
                          ? null
                          : '${animal['humidityMin'] ?? '–'}–${animal['humidityMax'] ?? '–'} %',
                    ),
                    if (animal['showWeightOnDetail'] != false)
                      _weightSection(animal, active),
                    if (animal['showSheddingOnDetail'] != false)
                      _sheddingSection(active),
                    _DetailRow(
                      label: sharedText(
                        context,
                        'Origin / habitat',
                        'Herkunft / Lebensraum',
                      ),
                      value: animal['originHabitat'] as String?,
                    ),
                    _DetailRow(
                      label: sharedText(
                        context,
                        'Rest / dormancy',
                        'Ruhezeiten',
                      ),
                      value: animal['restOrDormancyPeriods'] as String?,
                    ),
                    _DetailRow(
                      label: sharedText(context, 'Notes', 'Notizen'),
                      value: animal['notes'] as String?,
                    ),
                    if (!active)
                      _DetailRow(
                        label: sharedText(
                          context,
                          'Archive reason',
                          'Archivgrund',
                        ),
                        value: animal['archiveReason'] == null
                            ? null
                            : sharedArchiveReasonLabel(
                                context,
                                animal['archiveReason'] as String,
                                box: false,
                              ),
                      ),
                    if (!active)
                      _DetailRow(
                        label: context.l10n.archiveDateLowercase,
                        value: _dateOnlyLabel(animal['archivedAt'] as String?),
                      ),
                    if (!active)
                      _DetailRow(
                        label: context.l10n.archiveNote,
                        value: animal['archiveNotes'] as String?,
                      ),
                    const Divider(),
                    if (active) ...[
                      OutlinedButton.icon(
                        onPressed: widget.api.connected
                            ? () => _openHistory(
                                SharedHistoryKind.feedings,
                                active: true,
                                createOnOpen: true,
                              )
                            : null,
                        icon: const Icon(Icons.restaurant_outlined),
                        label: Text(context.l10n.createFeeding),
                      ),
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
                                    _id,
                                    choice.$1,
                                    choice.$2,
                                  );
                                }, clearNavigation: true);
                              }
                            : null,
                        icon: const Icon(Icons.archive_outlined),
                        label: Text(
                          sharedText(
                            context,
                            'Archive Animal',
                            'Tier archivieren',
                          ),
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
                                    _id,
                                    destination,
                                  );
                                }, clearNavigation: true);
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
                                if (!await confirmPermanentDeletion(context)) {
                                  return;
                                }
                                final done = await _change(() async {
                                  await widget.api.deleteAnimal(_id);
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
        ),
      ),
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

  void _openPicture(Map<String, dynamic> picture) {
    FullScreenImagePage.openNetwork(
      context,
      imageUrl: widget.api.mediaUrl(picture['mediaId'] as int),
      title: widget.kind == 'boxes'
          ? context.l10n.boxPicture
          : context.l10n.animalPicture,
    );
  }

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
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: primary != null,
                label: primary == null
                    ? null
                    : widget.kind == 'boxes'
                    ? context.l10n.openBoxPicture
                    : context.l10n.openAnimalPicture,
                child: MouseRegion(
                  cursor: primary == null
                      ? MouseCursor.defer
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    key: const Key('shared-open-primary-picture'),
                    onTap: primary == null ? null : () => _openPicture(primary),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ResponsivePictureFrame(
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Image.network(
                                widget.api
                                    .mediaUrl(primary['mediaId'] as int)
                                    .toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 72,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
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
                                  Semantics(
                                    button: true,
                                    label: widget.kind == 'boxes'
                                        ? context.l10n.openBoxPicture
                                        : context.l10n.openAnimalPicture,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        key: Key(
                                          'shared-open-gallery-picture-${picture['mediaId']}',
                                        ),
                                        onTap: () => _openPicture(picture),
                                        child: Image.network(
                                          widget.api
                                              .mediaUrl(
                                                picture['mediaId'] as int,
                                              )
                                              .toString(),
                                          height: 150,
                                          width: 150,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const SizedBox(
                                                height: 150,
                                                width: 150,
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (picture['isPrimary'] == true)
                                    const Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      ),
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
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });
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
