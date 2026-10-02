import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/core/presentation/widgets/overview_context_menu.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_schedule_page.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/shared_client/animals/presentation/animal_overview.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_detail_page.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_form.dart';
import 'package:terramanager/shared_client/boxes/presentation/widgets/shared_box_selection_dialog.dart';
import 'package:terramanager/shared_client/care_history/presentation/pages/shared_history_page.dart';
import 'package:terramanager/shared_client/media/application/shared_overview_image_cache.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_thumbnail.dart';
import 'package:terramanager/shared_client/navigation/application/shared_detail_navigation.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_change_feedback.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_archive_records.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_archive_dialog.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_duplicate_dialog.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_menu_item.dart';

enum _AnimalAction { details, feeding, edit, archive, duplicate, restore }

class SharedAnimalsPage extends StatefulWidget {
  const SharedAnimalsPage({
    super.key,
    required this.api,
    required this.boxes,
    required this.animals,
    this.reminders = const [],
    required this.connected,
    required this.change,
    required this.onReload,
    this.archived = false,
  });

  final bool archived;
  final SharedApiClient api;
  final List<Map<String, dynamic>> boxes;
  final List<Map<String, dynamic>> animals;
  final List<Map<String, dynamic>> reminders;
  final bool connected;
  final SharedChange change;
  final Future<void> Function() onReload;

  @override
  State<SharedAnimalsPage> createState() => _SharedAnimalsPageState();
}

class _SharedAnimalsPageState extends State<SharedAnimalsPage> {
  late SharedOverviewImageCache _images;

  Future<void> _openFeedingSchedule(
    List<({Map<String, dynamic> animal, DateTime dueAt})> reminders,
    AnimalNameOrder nameOrder,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedingSchedulePage(
          entries: [
            for (final reminder in reminders)
              FeedingScheduleEntry(
                animalId: recordId(reminder.animal),
                animalName: animalLabel(reminder.animal, order: nameOrder),
                dueAt: reminder.dueAt,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _images = SharedOverviewImageCache(loadBytes: widget.api.mediaBytes);
  }

  @override
  void didUpdateWidget(covariant SharedAnimalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _archiveData?.value = _archiveSnapshot;
    if (oldWidget.api != widget.api) {
      _images.dispose();
      _images = SharedOverviewImageCache(loadBytes: widget.api.mediaBytes);
    } else {
      _images.retain(
        widget.animals
            .map((record) => record['pictureMediaId'])
            .whereType<int>(),
      );
    }
  }

  @override
  void dispose() {
    _images.dispose();
    _archiveData?.dispose();
    _archiveData = null;
    super.dispose();
  }

  Future<void> _reload() async {
    await widget.onReload();
    if (mounted) setState(_images.clear);
  }

  bool get _archived => widget.archived;
  ValueNotifier<SharedArchiveSnapshot>? _archiveData;
  SharedArchiveSnapshot get _archiveSnapshot => (
    boxes: widget.boxes,
    animals: widget.animals,
    connected: widget.connected,
  );

  Future<void> _openArchive() async {
    final data = _archiveData = ValueNotifier(_archiveSnapshot);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ValueListenableBuilder<SharedArchiveSnapshot>(
          valueListenable: data,
          builder: (context, snapshot, _) => SharedAnimalsPage(
            api: widget.api,
            boxes: snapshot.boxes,
            animals: snapshot.animals,
            connected: snapshot.connected,
            change: widget.change,
            onReload: _reload,
            archived: true,
          ),
        ),
      ),
    );
    if (identical(_archiveData, data)) {
      _archiveData = null;
      data.dispose();
    }
  }

  bool _dueRemindersExpanded = true;

  String _reminderDate(DateTime date) {
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Widget _dueReminderSummary(
    List<({Map<String, dynamic> animal, DateTime dueAt})> reminders,
    AnimalNameOrder nameOrder,
  ) => Card(
    key: const Key('shared-feeding-reminder-summary'),
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    color: Theme.of(context).colorScheme.errorContainer,
    child: ExpansionTile(
      // Keep ExpansionTile's Boolean PageStorage value separate from the
      // overview scroll offset, which is stored as a number.
      key: const PageStorageKey<String>(
        'shared-feeding-reminder-summary-toggle',
      ),
      initiallyExpanded: _dueRemindersExpanded,
      onExpansionChanged: (expanded) =>
          setState(() => _dueRemindersExpanded = expanded),
      leading: const Icon(Icons.notification_important_outlined),
      title: Text(context.l10n.feedingReminders),
      subtitle: Text(context.l10n.animalsDueForFeeding(reminders.length)),
      children: [
        for (final reminder in reminders)
          ListTile(
            key: Key(
              'shared-feeding-reminder-due-${recordId(reminder.animal)}',
            ),
            leading: const Icon(Icons.restaurant_outlined),
            title: Text(animalLabel(reminder.animal, order: nameOrder)),
            subtitle: Text(
              context.l10n.feedingDueSince(_reminderDate(reminder.dueAt)),
            ),
            onTap: () => _openAnimal(reminder.animal),
          ),
      ],
    ),
  );

  Future<void> _openAnimal(Map<String, dynamic> animal) async {
    final settings = AppSettingsScope.of(context);
    final values = _archived
        ? sortSharedArchiveRecords(
            widget.animals,
            order: settings.animalArchiveSortOrder,
            displayName: (animal) =>
                animalLabel(animal, order: settings.animalNameOrder),
          )
        : sortSharedAnimalsForOverview(
            widget.animals.where(
              (item) => (item['status'] == 'archived') == _archived,
            ),
            order: settings.animalSortOrder,
            nameOrder: settings.animalNameOrder,
          );
    final rows = sharedAnimalOverviewRows(
      context,
      values,
      groupCategories: !_archived && settings.animalCategoryViewEnabled,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedAnimalDetailPage(
          api: widget.api,
          id: recordId(animal),
          boxes: widget.boxes,
          connected: widget.connected,
          change: widget.change,
          navigationContext: SharedDetailNavigationContext.animals(
            recordIds: rows.whereType<Map<String, dynamic>>().map(recordId),
            currentRecordId: recordId(animal),
            archived: _archived,
            sortOrder: settings.animalSortOrder,
            archiveSortOrder: _archived
                ? settings.animalArchiveSortOrder
                : null,
            nameOrder: settings.animalNameOrder,
            groupCategories: !_archived && settings.animalCategoryViewEnabled,
          ),
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _animalAction(
    _AnimalAction action,
    Map<String, dynamic> animal,
  ) async {
    if (action == _AnimalAction.details) {
      await _openAnimal(animal);
      return;
    }
    if (!widget.connected || !widget.api.connected) return;
    final id = recordId(animal);
    switch (action) {
      case _AnimalAction.details:
        return;
      case _AnimalAction.feeding:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SharedHistoryPage(
              api: widget.api,
              animalId: id,
              kind: SharedHistoryKind.feedings,
              active: true,
              change: widget.change,
              createOnOpen: true,
            ),
          ),
        );
      case _AnimalAction.edit:
        try {
          final current = await widget.api.animal(id);
          if (!mounted) return;
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => SharedAnimalForm(
                api: widget.api,
                boxes: widget.boxes,
                change: widget.change,
                initial: current,
              ),
            ),
          );
          if (mounted) await _reload();
        } catch (_) {
          if (mounted) showSharedChangeFailure(context);
        }
      case _AnimalAction.archive:
        final choice = await showArchiveDialog(
          context,
          reasons: const ['sold', 'traded', 'deceased', 'rehomed', 'other'],
        );
        if (choice == null) return;
        final saved = await widget.change(() async {
          await widget.api.archiveAnimal(id, choice.$1, choice.$2);
        });
        if (!saved && mounted) showSharedChangeFailure(context);
      case _AnimalAction.duplicate:
        final saved = await showSharedDuplicateDialog(
          context,
          api: widget.api,
          change: widget.change,
          source: animal,
          boxes: widget.boxes,
        );
        if (saved == true && mounted) await _reload();
      case _AnimalAction.restore:
        final destination = await selectActiveBox(context, widget.boxes);
        if (destination == null || !mounted) return;
        final saved = await widget.change(() async {
          await widget.api.restoreAnimal(id, destination);
        });
        if (!saved && mounted) showSharedChangeFailure(context);
    }
  }

  List<PopupMenuEntry<_AnimalAction>> _animalMenu(BuildContext context) => [
    sharedMenuItem(
      _AnimalAction.details,
      Icons.open_in_new_outlined,
      sharedText(context, 'Open details', 'Details öffnen'),
    ),
    sharedMenuItem(
      _AnimalAction.feeding,
      Icons.restaurant_outlined,
      context.l10n.createFeeding,
    ),
    sharedMenuItem(
      _AnimalAction.edit,
      Icons.edit_outlined,
      context.l10n.editAnimal,
    ),
    sharedMenuItem(
      _AnimalAction.archive,
      Icons.archive_outlined,
      context.l10n.archiveAnimal,
    ),
    sharedMenuItem(
      _AnimalAction.duplicate,
      Icons.copy_outlined,
      context.l10n.duplicateAnimal,
    ),
  ];

  List<PopupMenuEntry<_AnimalAction>> _archivedAnimalMenu(
    BuildContext context,
  ) => [
    sharedMenuItem(
      _AnimalAction.details,
      Icons.open_in_new_outlined,
      sharedText(context, 'Open details', 'Details öffnen'),
    ),
    sharedMenuItem(
      _AnimalAction.restore,
      Icons.unarchive_outlined,
      context.l10n.restoreAnimal,
    ),
  ];

  Widget _bigPictureAnimalCard(
    Map<String, dynamic> animal,
    Set<int> dueAnimalIds,
    AnimalNameOrder nameOrder,
    bool archived,
  ) {
    final id = recordId(animal);
    final primary = animalLabel(animal, order: nameOrder);
    final common = (animal['commonName'] as String?)?.trim() ?? '';
    final latin = (animal['latinName'] as String?)?.trim() ?? '';
    final secondary = nameOrder == AnimalNameOrder.commonNameFirst
        ? latin
        : common;
    final box = widget.boxes
        .where((entry) => entry['id'] == animal['boxId'])
        .firstOrNull;
    Widget card(Widget? menuButton) => Card(
      key: Key('animal-list-item-$id'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAnimal(animal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SharedThumbnail(
                    key: Key('animal-big-picture-$id'),
                    api: widget.api,
                    images: _images,
                    mediaId: animal['pictureMediaId'] as int?,
                    fallback: Icons.emoji_nature_outlined,
                    width: double.infinity,
                    height: double.infinity,
                    iconSize: 72,
                    borderRadius: 0,
                  ),
                  if (dueAnimalIds.contains(id))
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Tooltip(
                        message: context.l10n.feedingDue,
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .errorContainer,
                          child: const Icon(
                            Icons.notification_important_outlined,
                          ),
                        ),
                      ),
                    ),
                  if (archived)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Tooltip(
                        message: context.l10n.animalHistory,
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainer,
                          child: const Icon(Icons.archive_outlined),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (secondary.isNotEmpty && secondary != primary)
                          Text(
                            secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (box != null)
                          Text(
                            boxLabel(box),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ?menuButton,
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return OverviewContextMenu<_AnimalAction>(
      key: Key('animal-context-menu-region-$id'),
      menuButtonKey: Key('animal-context-menu-button-$id'),
      tooltip: context.l10n.animalActions(primary),
      onSelected: (action) => _animalAction(action, animal),
      itemBuilder: archived ? _archivedAnimalMenu : _animalMenu,
      builder: (context, button) => card(button),
    );
  }

  Widget _bigPictureAnimalGrid(
    List<Object> rows,
    Set<int> dueAnimalIds,
    AnimalNameOrder nameOrder,
    List<({Map<String, dynamic> animal, DateTime dueAt})> dueReminders,
    ({Map<String, dynamic> animal, DateTime dueAt})? nextReminder,
    List<({Map<String, dynamic> animal, DateTime dueAt})> allReminders,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = switch (constraints.maxWidth) {
        >= 1000 => 3,
        >= 600 => 2,
        _ => 1,
      };
      final delegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: columns == 1 ? 1.35 : 1.0,
      );
      final slivers = <Widget>[];
      if (dueReminders.isNotEmpty || nextReminder != null) {
        slivers.add(
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (dueReminders.isNotEmpty)
                  _dueReminderSummary(dueReminders, nameOrder),
                if (nextReminder != null)
                  Card(
                    key: const Key('shared-next-feeding-summary'),
                    child: ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: Text(context.l10n.nextFeeding),
                      subtitle: Text(
                        context.l10n.nextFeedingSummaryForAnimal(
                          animalLabel(nextReminder.animal, order: nameOrder),
                          _reminderDate(nextReminder.dueAt),
                        ),
                      ),
                      onTap: () =>
                          _openFeedingSchedule(allReminders, nameOrder),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      void addGrid(List<Map<String, dynamic>> animals) {
        if (animals.isEmpty) return;
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            sliver: SliverGrid(
              gridDelegate: delegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) => _bigPictureAnimalCard(
                  animals[index],
                  dueAnimalIds,
                  nameOrder,
                  _archived,
                ),
                childCount: animals.length,
              ),
            ),
          ),
        );
      }

      var group = <Map<String, dynamic>>[];
      for (final row in rows) {
        if (row is Map<String, dynamic>) {
          group.add(row);
        } else {
          addGrid(group);
          group = [];
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  row as String,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          );
        }
      }
      addGrid(group);
      return CustomScrollView(
        key: PageStorageKey<String>(
          _archived
              ? 'shared-animals-archive-grid'
              : 'shared-animals-overview-grid',
        ),
        slivers: slivers,
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final values = _archived
        ? sortSharedArchiveRecords(
            widget.animals,
            order: settings.animalArchiveSortOrder,
            displayName: (animal) =>
                animalLabel(animal, order: settings.animalNameOrder),
          )
        : sortSharedAnimalsForOverview(
            widget.animals.where(
              (animal) => (animal['status'] == 'archived') == _archived,
            ),
            order: settings.animalSortOrder,
            nameOrder: settings.animalNameOrder,
          );
    final rows = sharedAnimalOverviewRows(
      context,
      values,
      groupCategories: !_archived && settings.animalCategoryViewEnabled,
    );
    final reminderEntries = <({Map<String, dynamic> animal, DateTime dueAt})>[];
    if (!_archived) {
      for (final reminder in widget.reminders) {
        final animal = values
            .where((entry) => entry['id'] == reminder['animalId'])
            .firstOrNull;
        final dueAt = DateTime.tryParse(reminder['dueAt'] as String? ?? '');
        if (animal != null && dueAt != null) {
          reminderEntries.add((animal: animal, dueAt: dueAt));
        }
      }
      reminderEntries.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    }
    final now = DateTime.now();
    final dueReminders = reminderEntries
        .where((entry) => !entry.dueAt.isAfter(now))
        .toList();
    final nextReminder = settings.nextFeedingSummaryEnabled
        ? reminderEntries
                  .where((entry) => entry.dueAt.isAfter(now))
                  .firstOrNull ??
              reminderEntries.firstOrNull
        : null;
    final reminderRowCount =
        (dueReminders.isEmpty ? 0 : 1) + (nextReminder == null ? 0 : 1);
    return ConstrainedPageWidth(
      child: Scaffold(
        appBar: AppBar(
          leading: _archived
              ? IconButton(
                  tooltip: sharedText(context, 'Back', 'Zurück'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          title: Text(
            _archived
                ? context.l10n.animalHistory
                : context.l10n.navigationAnimals,
          ),
          actions: [
            if (!_archived)
              IconButton(
                key: const Key('animal-category-view-toggle'),
                isSelected: settings.animalCategoryViewEnabled,
                onPressed: () => settings.setAnimalCategoryViewEnabled(
                  !settings.animalCategoryViewEnabled,
                ),
                icon: const Icon(Icons.toggle_on_outlined),
                selectedIcon: const Icon(Icons.toggle_off_outlined),
                tooltip: settings.animalCategoryViewEnabled
                    ? context.l10n.hideAnimalCategoryGroups
                    : context.l10n.showAnimalCategoryGroups,
              ),
            if (_archived)
              PopupMenuButton<ArchiveSortCriterion>(
                key: const Key('animal-archive-sort-button'),
                tooltip: context.l10n.sortArchivedAnimals,
                icon: const Icon(Icons.sort),
                initialValue: settings.animalArchiveSortOrder.criterion,
                onSelected: (criterion) {
                  final current = settings.animalArchiveSortOrder;
                  settings.setAnimalArchiveSortOrder(
                    criterion == current.criterion
                        ? current.reversed
                        : criterion.defaultOrder,
                  );
                },
                itemBuilder: (context) => [
                  for (final criterion in ArchiveSortCriterion.values)
                    CheckedPopupMenuItem<ArchiveSortCriterion>(
                      key: Key('animal-archive-sort-option-${criterion.name}'),
                      value: criterion,
                      checked:
                          criterion ==
                          settings.animalArchiveSortOrder.criterion,
                      child: Text(
                        context.l10n.archiveSortCriterionMenuLabel(
                          criterion,
                          activeOrder:
                              criterion ==
                                  settings.animalArchiveSortOrder.criterion
                              ? settings.animalArchiveSortOrder
                              : null,
                        ),
                      ),
                    ),
                ],
              )
            else
              PopupMenuButton<AnimalSortCriterion>(
                key: const Key('animal-sort-button'),
                initialValue: settings.animalSortOrder.criterion,
                tooltip: context.l10n.sortAnimals,
                icon: const Icon(Icons.sort),
                onSelected: (criterion) {
                  final current = settings.animalSortOrder.normalized;
                  settings.setAnimalSortOrder(
                    criterion == current.criterion
                        ? current.reversed
                        : criterion.defaultOrder,
                  );
                },
                itemBuilder: (context) => [
                  for (final criterion in const [
                    AnimalSortCriterion.created,
                    AnimalSortCriterion.displayName,
                    AnimalSortCriterion.age,
                    AnimalSortCriterion.latestFeeding,
                  ])
                    CheckedPopupMenuItem<AnimalSortCriterion>(
                      key: Key('animal-sort-option-${criterion.name}'),
                      value: criterion,
                      checked: criterion == settings.animalSortOrder.criterion,
                      child: Text(
                        context.l10n.animalSortCriterionMenuLabel(
                          criterion,
                          activeOrder:
                              criterion == settings.animalSortOrder.criterion
                              ? settings.animalSortOrder
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            if (!_archived)
              IconButton(
                key: const Key('animal-history-button'),
                tooltip: context.l10n.animalHistory,
                onPressed: _openArchive,
                icon: const Icon(Icons.history),
              ),
            IconButton(
              key: const Key('shared-refresh'),
              tooltip: sharedText(context, 'Reload', 'Neu laden'),
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: _archived
            ? null
            : FloatingActionButton(
                key: const Key('add-animal-button'),
                heroTag: 'shared-animal-add',
                tooltip: context.l10n.addAnimal,
                onPressed:
                    widget.connected &&
                        widget.boxes.any((box) => box['status'] == 'active')
                    ? () => Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SharedAnimalForm(
                            api: widget.api,
                            boxes: widget.boxes,
                            change: widget.change,
                          ),
                        ),
                      )
                    : null,
                child: const Icon(Icons.add),
              ),
        body: values.isEmpty
            ? Center(
                child: Text(
                  _archived
                      ? context.l10n.noArchivedAnimals
                      : context.l10n.noAnimalsAvailable,
                ),
              )
            : !_archived && settings.bigPictureModeEnabled
            ? _bigPictureAnimalGrid(
                rows,
                dueReminders.map((entry) => recordId(entry.animal)).toSet(),
                settings.animalNameOrder,
                dueReminders,
                nextReminder,
                reminderEntries,
              )
            : ListView.builder(
                key: PageStorageKey<String>(
                  _archived
                      ? 'shared-animals-archive'
                      : 'shared-animals-overview',
                ),
                itemCount: reminderRowCount + rows.length,
                itemBuilder: (context, index) {
                  var rowIndex = index;
                  if (dueReminders.isNotEmpty) {
                    if (rowIndex == 0) {
                      return _dueReminderSummary(
                        dueReminders,
                        settings.animalNameOrder,
                      );
                    }
                    rowIndex--;
                  }
                  if (nextReminder != null) {
                    if (rowIndex == 0) {
                      return Card(
                        key: const Key('shared-next-feeding-summary'),
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: ListTile(
                          leading: const Icon(Icons.schedule_outlined),
                          title: Text(context.l10n.nextFeeding),
                          subtitle: Text(
                            context.l10n.nextFeedingSummaryForAnimal(
                              animalLabel(
                                nextReminder.animal,
                                order: settings.animalNameOrder,
                              ),
                              _reminderDate(nextReminder.dueAt),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openFeedingSchedule(
                            reminderEntries,
                            settings.animalNameOrder,
                          ),
                        ),
                      );
                    }
                    rowIndex--;
                  }
                  final row = rows[rowIndex];
                  if (row is String) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        row,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }
                  final animal = row as Map<String, dynamic>;
                  final id = recordId(animal);
                  final primary = animalLabel(
                    animal,
                    order: settings.animalNameOrder,
                  );
                  final common =
                      (animal['commonName'] as String?)?.trim() ?? '';
                  final latin = (animal['latinName'] as String?)?.trim() ?? '';
                  final secondary =
                      settings.animalNameOrder ==
                          AnimalNameOrder.commonNameFirst
                      ? latin
                      : common;
                  final box = widget.boxes
                      .where((entry) => entry['id'] == animal['boxId'])
                      .firstOrNull;
                  Widget tile(Widget? menuButton) => ListTile(
                    key: Key('animal-list-item-$id'),
                    leading: SharedThumbnail(
                      api: widget.api,
                      images: _images,
                      mediaId: animal['pictureMediaId'] as int?,
                      fallback: Icons.emoji_nature_outlined,
                    ),
                    title: Text(primary),
                    subtitle: Text(
                      [
                        if (secondary.isNotEmpty && secondary != primary)
                          secondary,
                        if (_archived)
                          sharedArchiveSummary(context, animal, box: false)
                        else if (box != null)
                          boxLabel(box),
                      ].join(' · '),
                    ),
                    trailing: menuButton,
                    onTap: () => _openAnimal(animal),
                  );
                  return OverviewContextMenu<_AnimalAction>(
                    key: Key('animal-context-menu-region-$id'),
                    menuButtonKey: Key('animal-context-menu-button-$id'),
                    tooltip: context.l10n.animalActions(primary),
                    onSelected: (action) => _animalAction(action, animal),
                    itemBuilder: _archived ? _archivedAnimalMenu : _animalMenu,
                    builder: (context, button) => tile(button),
                  );
                },
              ),
      ),
    );
  }
}
