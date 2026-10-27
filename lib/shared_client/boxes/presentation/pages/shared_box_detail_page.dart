import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';
import 'package:terramanager/shared_client/custom_fields/presentation/shared_custom_fields.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_archive_records.dart';

import 'dart:async';

import 'shared_box_care_history_page.dart';

import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/animals/presentation/animal_overview.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_detail_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/box_overview.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_form.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_picture_gallery.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_thumbnail.dart';
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

class _SharedBoxDetailPageState extends State<SharedBoxDetailPage> {
  late int _id;
  SharedDetailNavigationContext? _navigationContext;
  late Future<Map<String, dynamic>> _record;
  late List<Map<String, dynamic>> _animals;
  late final SharedRefreshSubscription _refresh;
  ModalRoute<dynamic>? _route;
  bool _switching = false;
  String? _navigationError;

  @override
  void initState() {
    super.initState();
    _id = widget.id;
    _navigationContext = widget.navigationContext;
    _animals = widget.animals;
    _record = widget.api.box(_id);
    _refresh = widget.api.refresh.watch(
      dependencies: () => {
        'boxes': _navigationContext == null ? {_id} : null,
        'animals': null,
      },
      isVisible: () => mounted && !_switching && (_route?.isCurrent ?? true),
      refresh: _refreshChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(
          widget.api.refresh.refreshVisible().catchError((Object _) {}),
        );
      }
    });
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _refreshVisible() =>
      widget.api.refresh.reconcile().catchError((Object _) {});

  Future<void> _refreshChanged(SharedInvalidation change) async {
    final id = _id;
    final generation = widget.api.refresh.generation;
    bool current() =>
        mounted &&
        generation == widget.api.refresh.generation &&
        !widget.api.refresh.paused;
    var readingRecord = false;
    try {
      await _record.catchError((Object _) => <String, dynamic>{});
      if (!current()) return;
      readingRecord = change.affects('boxes', id);
      final box = readingRecord ? await widget.api.box(id) : await _record;
      if (!current()) return;
      readingRecord = false;
      final animals = change.affects('animals')
          ? await widget.api.animals()
          : null;
      if (!current()) return;
      final navigation = _navigationContext;
      final boxes =
          navigation != null &&
              (change.affects('boxes') ||
                  (navigation.showEmptyBoxesLast && change.affects('animals')))
          ? await widget.api.boxes()
          : null;
      if (!current()) return;
      final updated = navigation == null || boxes == null
          ? navigation
          : navigation.withRecords(
              _orderedBoxIds(navigation, boxes, animals: animals ?? _animals),
            );
      if (generation != widget.api.refresh.generation) return;
      if (navigation != null &&
          (updated == null ||
              (box['status'] == 'archived') != navigation.archived)) {
        if (mounted && id == _id) leaveRemovedSharedDetail(context);
        return;
      }
      if (!mounted || id != _id) return;
      setState(() {
        if (change.affects('boxes', id)) _record = Future.value(box);
        if (animals != null) _animals = animals;
        _navigationContext = updated;
      });
    } on SharedApiException catch (error) {
      if (generation != widget.api.refresh.generation) return;
      if (error.status != 404 || !readingRecord) rethrow;
      if (mounted && id == _id) leaveRemovedSharedDetail(context);
    }
  }

  List<int> _orderedBoxIds(
    SharedDetailNavigationContext navigation,
    List<Map<String, dynamic>> boxes, {
    List<Map<String, dynamic>>? animals,
  }) => navigation.archiveSortOrder != null
      ? sortSharedArchiveRecords(
          boxes,
          order: navigation.archiveSortOrder!,
          displayName: boxLabel,
        ).map(recordId).toList()
      : sortSharedBoxesForOverview(
          boxes.where(
            (box) => (box['status'] == 'archived') == navigation.archived,
          ),
          navigation.boxSortOrder!,
          showEmptyBoxesLast: navigation.showEmptyBoxesLast,
          occupiedBoxIds: (animals ?? _animals)
              .map((animal) => animal['boxId'])
              .whereType<int>()
              .toSet(),
        ).map(recordId).toList();

  Future<void> _switchAdjacent({required bool next}) async {
    final navigation = _navigationContext;
    if (navigation == null || _switching) return;
    final originalId = _id;
    setState(() => _switching = true);
    try {
      final boxes = await widget.api.boxes();
      final sortAnimals = navigation.showEmptyBoxesLast
          ? await widget.api.animals()
          : null;
      final ids = _orderedBoxIds(navigation, boxes, animals: sortAnimals);
      final current = navigation.withRecords(ids);
      if (!mounted) return;
      if (current == null) {
        leaveRemovedSharedDetail(context);
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
      final animals = sortAnimals ?? await widget.api.animals();
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
      if (mounted) {
        setState(() => _switching = false);
        if (_id != originalId) _refresh.markStale();
        unawaited(
          widget.api.refresh.refreshVisible().catchError((Object _) {}),
        );
      }
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
        unawaited(_refreshVisible());
      }
    } catch (_) {
      if (mounted) showSharedDetailFailure(context);
    }
  }

  Future<bool> _change(
    Future<void> Function() action, {
    bool clearNavigation = false,
  }) async {
    final saved = await widget.change(action);
    if (!mounted) return false;
    if (saved) {
      if (clearNavigation) setState(() => _navigationContext = null);
    } else {
      showSharedDetailFailure(context);
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
            builder: (context, snapshot) {
              final box = snapshot.data;
              if (box == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('box-care-history-button'),
                    tooltip: context.l10n.boxCareHistory,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SharedBoxCareHistoryPage(
                          api: widget.api,
                          boxId: _id,
                          label: boxLabel(box),
                          change: _change,
                        ),
                      ),
                    ),
                  ),
                  if (box['status'] == 'active')
                    ListenableBuilder(
                      listenable: widget.api,
                      builder: (context, _) => IconButton(
                        key: const Key('edit-box-button'),
                        tooltip: sharedText(
                          context,
                          'Edit Box',
                          'Box bearbeiten',
                        ),
                        onPressed: widget.api.connected ? _openEdit : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                ],
              );
            },
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
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return SharedLoadFailure(onRetry: _reload);
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
                        onChanged: () => unawaited(_refreshVisible()),
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
                      SharedDetailRow(
                        label: context.l10n.reason,
                        value: box['archiveReason'] == null
                            ? context.l10n.notSpecified
                            : sharedArchiveReasonLabel(
                                context,
                                box['archiveReason'] as String,
                                box: true,
                              ),
                      ),
                      SharedDetailRow(
                        label: context.l10n.archiveDate,
                        value:
                            _dateTimeLabel(box['archivedAt'] as String?) ??
                            context.l10n.notSpecified,
                      ),
                      SharedDetailRow(
                        label: context.l10n.archiveNote,
                        value: box['archiveNotes'] as String?,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      context.l10n.dimensions,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SharedDetailRow(
                      label: context.l10n.width,
                      value: box['widthCm'] == null
                          ? null
                          : '${box['widthCm']} cm',
                    ),
                    SharedDetailRow(
                      label: context.l10n.height,
                      value: box['heightCm'] == null
                          ? null
                          : '${box['heightCm']} cm',
                    ),
                    SharedDetailRow(
                      label: context.l10n.depth,
                      value: box['depthCm'] == null
                          ? null
                          : '${box['depthCm']} cm',
                    ),
                    SharedDetailRow(
                      label: 'QR ID',
                      value: box['qrId']?.toString(),
                    ),
                    SharedDetailRow(
                      label: context.l10n.boxId,
                      value: _id.toString(),
                    ),
                    SharedDetailRow(
                      label: context.l10n.created,
                      value: _dateTimeLabel(box['createdAt'] as String?),
                    ),
                    SharedDetailRow(
                      label: context.l10n.updated,
                      value: _dateTimeLabel(box['updatedAt'] as String?),
                    ),
                    SharedDetailRow(
                      label: sharedText(
                        context,
                        'Temperature zones',
                        'Temperaturzonen',
                      ),
                      value: box['temperatureZones'] as String?,
                    ),
                    SharedCustomFieldsSection(
                      key: ValueKey('custom-fields-${box['id']}'),
                      api: widget.api,
                      target: CustomFieldTarget.box,
                      id: recordId(box),
                    ),
                    SharedDetailRow(
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
                                    'stored',
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
