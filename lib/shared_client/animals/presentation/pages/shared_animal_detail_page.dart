import 'package:terramanager/shared_client/shared/presentation/shared_archive_records.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/shared_client/animals/presentation/animal_overview.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_form.dart';
import 'package:terramanager/shared_client/animals/presentation/widgets/shared_shedding_section.dart';
import 'package:terramanager/shared_client/animals/presentation/widgets/shared_weight_section.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_detail_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/widgets/shared_box_selection_dialog.dart';
import 'package:terramanager/shared_client/care_history/presentation/pages/shared_history_page.dart';
import 'package:terramanager/shared_client/feedings/presentation/pages/shared_feeding_reminder_page.dart';
import 'package:terramanager/shared_client/feedings/presentation/widgets/shared_feeding_information.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_picture_gallery.dart';
import 'package:terramanager/shared_client/navigation/application/shared_detail_navigation.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_detail_feedback.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_archive_dialog.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_deletion_dialog.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_detail_row.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_load_failure.dart';

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
        if (mounted && id == _id) leaveRemovedSharedDetail(context);
        return;
      }
      final updatedNavigation = navigation == null || animals == null
          ? null
          : navigation.withRecords(_orderedAnimalIds(navigation, animals));
      if (navigation != null && updatedNavigation == null) {
        if (mounted && id == _id) leaveRemovedSharedDetail(context);
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
        leaveRemovedSharedDetail(context);
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
    if (navigation.archiveSortOrder != null) {
      return sortSharedArchiveRecords(
        animals,
        order: navigation.archiveSortOrder!,
        displayName: (animal) =>
            animalLabel(animal, order: navigation.animalNameOrder!),
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
        leaveRemovedSharedDetail(context);
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
      if (mounted) showSharedDetailFailure(context);
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
      if (mounted) showSharedDetailFailure(context);
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
      showSharedDetailFailure(context);
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
              if (snapshot.hasError) return SharedLoadFailure(onRetry: _reload);
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
                    SharedFeedingInformation(
                      entries: _feedings,
                      animal: animal,
                      due: true,
                      onRetry: _reload,
                      onHistory: _openFeedingHistory,
                    ),
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
                    SharedFeedingInformation(
                      entries: _feedings,
                      animal: animal,
                      due: false,
                      onRetry: _reload,
                      onHistory: _openFeedingHistory,
                    ),
                    SharedDetailRow(
                      label: sharedText(context, 'Status', 'Status'),
                      value: active
                          ? sharedText(context, 'Active', 'Aktiv')
                          : sharedText(context, 'Archived', 'Archiviert'),
                    ),
                    SharedDetailRow(
                      label: sharedText(context, 'Box', 'Box'),
                      value: box == null ? null : boxLabel(box),
                      onTap: box == null ? null : () => _openBox(recordId(box)),
                    ),
                    SharedDetailRow(
                      label: sharedText(context, 'Category', 'Kategorie'),
                      value: sharedCategoryLabel(
                        context,
                        animal['category'] as String?,
                      ),
                    ),
                    SharedDetailRow(
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
                    SharedDetailRow(
                      label: sharedText(context, 'Sex', 'Geschlecht'),
                      value: sharedSexLabel(context, animal['sex'] as String?),
                    ),
                    if (DateTime.tryParse(animal['birthDate'] as String? ?? '')
                        case final birthDate?)
                      SharedDetailRow(
                        label: context.l10n.birthDateLowercase,
                        value: MaterialLocalizations.of(context)
                            .formatMediumDate(birthDate),
                      ),
                    if (BirthDateAccuracy.values
                            .where(
                              (value) =>
                                  value.name == animal['birthDateAccuracy'],
                            )
                            .firstOrNull
                        case final accuracy?)
                      SharedDetailRow(
                        label: context.l10n.birthDateAccuracyLowercase,
                        value: context.l10n.birthAccuracyLabel(accuracy),
                      ),
                    SharedDetailRow(
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
                      SharedDetailRow(
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
                    SharedDetailRow(
                      label: sharedText(context, 'Humidity', 'Feuchtigkeit'),
                      value:
                          animal['humidityMin'] == null &&
                              animal['humidityMax'] == null
                          ? null
                          : '${animal['humidityMin'] ?? '–'}–${animal['humidityMax'] ?? '–'} %',
                    ),
                    if (animal['showWeightOnDetail'] != false)
                      SharedWeightSection(
                        entries: _weights,
                        animal: animal,
                        active: active,
                        connected: widget.api.connected,
                        onAdd: () => _openHistory(
                          SharedHistoryKind.weights,
                          active: true,
                          createOnOpen: true,
                        ),
                        onHistory: () => _openHistory(
                          SharedHistoryKind.weights,
                          active: active,
                        ),
                      ),
                    if (animal['showSheddingOnDetail'] != false)
                      SharedSheddingSection(
                        entries: _shedding,
                        active: active,
                        connected: widget.api.connected,
                        onAdd: () => _openHistory(
                          SharedHistoryKind.shedding,
                          active: true,
                          createOnOpen: true,
                        ),
                        onHistory: () => _openHistory(
                          SharedHistoryKind.shedding,
                          active: active,
                        ),
                      ),
                    SharedDetailRow(
                      label: sharedText(
                        context,
                        'Origin / habitat',
                        'Herkunft / Lebensraum',
                      ),
                      value: animal['originHabitat'] as String?,
                    ),
                    SharedDetailRow(
                      label: sharedText(
                        context,
                        'Rest / dormancy',
                        'Ruhezeiten',
                      ),
                      value: animal['restOrDormancyPeriods'] as String?,
                    ),
                    SharedDetailRow(
                      label: sharedText(context, 'Notes', 'Notizen'),
                      value: animal['notes'] as String?,
                    ),
                    if (!active)
                      SharedDetailRow(
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
                      SharedDetailRow(
                        label: context.l10n.archiveDateLowercase,
                        value: _dateOnlyLabel(animal['archivedAt'] as String?),
                      ),
                    if (!active)
                      SharedDetailRow(
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
                      if (widget.api.canDeleteCollection)
                        TextButton.icon(
                          onPressed: widget.api.connected
                              ? () async {
                                  if (!await confirmPermanentDeletion(
                                    context,
                                  )) {
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
