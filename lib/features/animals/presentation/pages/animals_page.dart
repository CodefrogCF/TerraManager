import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/animal_category.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/feeding_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
import '../../../../core/presentation/widgets/overview_context_menu.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../feedings/application/feeding_reminder_service.dart';
import '../../../feedings/domain/feeding_reminder_state.dart';
import '../../../feedings/presentation/pages/feeding_history_page.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import '../../../settings/animal_name_order.dart';
import '../../../settings/animal_sort_order.dart';
import '../../../settings/app_settings_controller.dart';
import '../animal_archive_dialog.dart';
import '../animal_display_names.dart';
import '../animal_overview_sorting.dart';
import '../animal_quick_action_dialogs.dart';
import 'animal_detail_page.dart';
import 'animal_edit_page.dart';
import 'animal_history_page.dart';
import 'new_animal_page.dart';

enum _AnimalOverviewAction { createFeeding, rename, edit, archive, duplicate }

class AnimalsPage extends StatefulWidget {
  final AppDatabase database;
  final FeedingReminderClock? reminderNow;
  final int dataRevision;

  const AnimalsPage({
    super.key,
    required this.database,
    this.reminderNow,
    this.dataRevision = 0,
  });

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  late Future<_AnimalsOverviewData> _overviewFuture;

  final ScrollController _scrollController = ScrollController();

  final Map<int, Future<MediaAsset?>> _pictureFutures = {};

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  @override
  void didUpdateWidget(covariant AnimalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.database == oldWidget.database &&
        widget.dataRevision == oldWidget.dataRevision) {
      return;
    }

    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    _loadAnimals();
    _restoreScrollAfterLoad(previousOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  void _loadAnimals() {
    _pictureFutures.clear();

    _overviewFuture = _fetchOverview();
  }

  Future<_AnimalsOverviewData> _fetchOverview() async {
    final animals = await AnimalRepository(widget.database).getActiveAnimals();
    final latestFeedingTimes = await FeedingRepository(widget.database)
        .getLatestFeedingTimes(animals.map((animal) => animal.id));
    final reminderService = FeedingReminderService(
      widget.database,
      now: widget.reminderNow,
    );
    final dueReminders = reminderService
        .calculateReminderStates(
          animals: animals,
          latestFeedingTimes: latestFeedingTimes,
        )
        .where((state) => state.isDue)
        .toList(growable: false);

    return _AnimalsOverviewData(
      animals: animals,
      latestFeedingTimes: latestFeedingTimes,
      dueReminders: dueReminders,
    );
  }

  Future<void> _reloadAnimalsPreservingScroll(double previousOffset) async {
    setState(() {
      _loadAnimals();
    });

    await _restoreScrollAfterLoad(previousOffset);
  }

  Future<void> _restoreScrollAfterLoad(double previousOffset) async {
    try {
      await _overviewFuture;
    } catch (_) {
      return;
    }

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final maxOffset = _scrollController.position.maxScrollExtent;

      final targetOffset = previousOffset.clamp(0.0, maxOffset);

      _scrollController.jumpTo(targetOffset);
    });
  }

  Future<MediaAsset?> _pictureFutureFor(int? mediaId) {
    if (mediaId == null) {
      return Future<MediaAsset?>.value(null);
    }

    return _pictureFutures.putIfAbsent(
      mediaId,
      () => MediaRepository(widget.database).getMediaById(mediaId),
    );
  }

  Future<void> _openNewAnimalPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewAnimalPage(database: widget.database),
      ),
    );

    if (!mounted || created != true) {
      return;
    }

    setState(() {
      _loadAnimals();
    });
  }

  Future<void> _openAnimalDetail(Animal animal, List<Animal> animals) async {
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalDetailPage(
          database: widget.database,
          animalId: animal.id,
          reminderNow: widget.reminderNow,
          navigationContext: DetailNavigationContext.activeAnimals(
            animalIds: animals.map((animal) => animal.id),
            currentAnimalId: animal.id,
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadAnimalsPreservingScroll(previousOffset);
  }

  Future<void> _handleAnimalAction(
    _AnimalOverviewAction action,
    Animal animal,
  ) async {
    switch (action) {
      case _AnimalOverviewAction.createFeeding:
        await _createFeeding(animal);
        return;
      case _AnimalOverviewAction.rename:
        await _renameAnimal(animal);
        return;
      case _AnimalOverviewAction.edit:
        await _editAnimal(animal);
        return;
      case _AnimalOverviewAction.archive:
        await _archiveAnimal(animal);
        return;
      case _AnimalOverviewAction.duplicate:
        await _duplicateAnimal(animal);
        return;
    }
  }

  Future<void> _createFeeding(Animal animal) async {
    final created = await showFeedingEntryDialog(
      context: context,
      database: widget.database,
      animalId: animal.id,
    );
    if (!mounted || created != true) {
      return;
    }

    await _reloadAnimalsPreservingScroll(_currentScrollOffset());
    if (mounted) {
      _showMessage(context.l10n.feedingCreated);
    }
  }

  Future<void> _renameAnimal(Animal animal) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => RenameAnimalDialog(initialName: animal.commonName),
    );
    if (!mounted || name == null) {
      return;
    }

    try {
      final renamed = await AnimalRepository(widget.database)
          .renameAnimal(animalId: animal.id, commonName: name);
      if (!mounted) {
        return;
      }
      if (!renamed) {
        _showMessage(context.l10n.failedToRenameAnimal);
        return;
      }

      await _reloadAnimalsPreservingScroll(_currentScrollOffset());
      if (mounted) {
        _showMessage(context.l10n.animalRenamed);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToRenameAnimal);
      }
    }
  }

  Future<void> _editAnimal(Animal animal) async {
    final previousOffset = _currentScrollOffset();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AnimalEditPage(database: widget.database, animalId: animal.id),
      ),
    );
    if (mounted) {
      await _reloadAnimalsPreservingScroll(previousOffset);
    }
  }

  Future<void> _archiveAnimal(Animal animal) async {
    final input = await showDialog<AnimalArchiveInput>(
      context: context,
      builder: (_) => const AnimalArchiveDialog(hasUnsavedChanges: false),
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      final archived = await AnimalRepository(widget.database).archiveAnimal(
        animalId: animal.id,
        reason: input.reason,
        archivedAt: input.archivedAt,
        archiveNotes: input.notes,
      );
      if (!mounted) {
        return;
      }
      if (!archived) {
        _showMessage(context.l10n.failedToArchiveAnimal);
        return;
      }

      await _reloadAnimalsPreservingScroll(_currentScrollOffset());
      if (mounted) {
        _showMessage(context.l10n.animalArchived);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToArchiveAnimal);
      }
    }
  }

  Future<void> _duplicateAnimal(Animal animal) async {
    List<Box> boxes;
    try {
      boxes = await BoxRepository(widget.database).getActiveBoxes();
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToLoadBoxes);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (boxes.isEmpty) {
      await _showNoBoxesDialog();
      return;
    }

    final input = await showDialog<DuplicateAnimalInput>(
      context: context,
      builder: (_) => DuplicateAnimalDialog(
        initialName: context.l10n.copyName(animal.commonName),
        boxes: boxes,
        initialBoxId: animal.boxId,
      ),
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      await AnimalRepository(widget.database).duplicateAnimal(
        sourceAnimalId: animal.id,
        boxId: input.boxId,
        commonName: input.commonName,
      );
      if (!mounted) {
        return;
      }
      await _reloadAnimalsPreservingScroll(_currentScrollOffset());
      if (mounted) {
        _showMessage(context.l10n.animalDuplicated);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToDuplicateAnimal);
      }
    }
  }

  Future<void> _showNoBoxesDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('duplicate-animal-no-boxes-dialog'),
        title: Text(context.l10n.noBoxesAvailableTitle),
        content: Text(context.l10n.noBoxesForAnimal),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  double _currentScrollOffset() {
    return _scrollController.hasClients ? _scrollController.offset : 0;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildReminderSummary(
    BuildContext context,
    List<FeedingReminderState> reminders,
    List<Animal> animals,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('feeding-reminder-summary'),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: colorScheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notification_important_outlined,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.feedingReminders,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colorScheme.onErrorContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.animalsDueForFeeding(reminders.length),
                        key: const Key('feeding-reminder-summary-count'),
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final reminder in reminders) ...[
            Divider(
              height: 1,
              color: colorScheme.onErrorContainer.withAlpha(64),
            ),
            ListTile(
              key: Key('feeding-reminder-summary-item-${reminder.animalId}'),
              title: Text(
                AnimalDisplayNames.fromContext(
                  context,
                  commonName: reminder.animal.commonName,
                  latinName: reminder.animal.latinName,
                ).primary,
              ),
              subtitle: Text(
                context.l10n.feedingDueSince(_formatDateTime(reminder.dueAt)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _openAnimalDetail(reminder.animal, animals);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAnimalHistory() async {
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalHistoryPage(database: widget.database),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadAnimalsPreservingScroll(previousOffset);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.maybeOf(context);
    final animalSortOrder =
        settings?.animalSortOrder ?? AnimalSortOrder.createdOldestFirst;
    final categoryViewEnabled = settings?.animalCategoryViewEnabled ?? false;
    final animalNameOrder =
        settings?.animalNameOrder ?? AnimalNameOrder.commonNameFirst;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navigationAnimals),
        actions: [
          IconButton(
            key: const Key('animal-category-view-toggle'),
            isSelected: categoryViewEnabled,
            onPressed: settings == null
                ? null
                : () => settings.setAnimalCategoryViewEnabled(
                    !categoryViewEnabled,
                  ),
            icon: const Icon(Icons.toggle_on_outlined),
            selectedIcon: const Icon(Icons.toggle_off_outlined),
            tooltip: categoryViewEnabled
                ? context.l10n.hideAnimalCategoryGroups
                : context.l10n.showAnimalCategoryGroups,
          ),
          PopupMenuButton<AnimalSortCriterion>(
            key: const Key('animal-sort-button'),
            initialValue: animalSortOrder.criterion,
            onSelected: (criterion) {
              final sortOrder = criterion == animalSortOrder.criterion
                  ? animalSortOrder.reversed
                  : criterion.defaultOrder;
              settings?.setAnimalSortOrder(sortOrder);
            },
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.sortAnimals,
            itemBuilder: (context) {
              return AnimalSortCriterion.values.map((criterion) {
                final isActive = criterion == animalSortOrder.criterion;
                return CheckedPopupMenuItem<AnimalSortCriterion>(
                  key: Key('animal-sort-option-${criterion.name}'),
                  value: criterion,
                  checked: isActive,
                  child: Text(
                    context.l10n.animalSortCriterionMenuLabel(
                      criterion,
                      activeOrder: isActive ? animalSortOrder : null,
                    ),
                  ),
                );
              }).toList();
            },
          ),
          IconButton(
            key: const Key('animal-history-button'),
            onPressed: _openAnimalHistory,
            icon: const Icon(Icons.history),
            tooltip: context.l10n.animalHistory,
          ),
        ],
      ),
      body: FutureBuilder<_AnimalsOverviewData>(
        future: _overviewFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.failedToLoadAnimals));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          final rawAnimals = data?.animals ?? const <Animal>[];
          final categoryGroups = categoryViewEnabled
              ? groupAnimalsForCategoryOverview(
                  rawAnimals,
                  sortOrder: animalSortOrder,
                  nameOrder: animalNameOrder,
                  latestFeedingTimes:
                      data?.latestFeedingTimes ?? const <int, DateTime>{},
                  subcategoryLabel: context.l10n.animalSubcategoryLabel,
                )
              : null;
          final animals = categoryGroups == null
              ? sortAnimalsForOverview(
                  rawAnimals,
                  sortOrder: animalSortOrder,
                  nameOrder: animalNameOrder,
                  latestFeedingTimes:
                      data?.latestFeedingTimes ?? const <int, DateTime>{},
                )
              : categoryGroups
                    .expand((group) => group.animals)
                    .toList(growable: false);
          final dueReminders =
              data?.dueReminders ?? const <FeedingReminderState>[];

          if (animals.isEmpty) {
            return Center(child: Text(context.l10n.noAnimalsAvailable));
          }

          final dueRemindersByAnimalId = {
            for (final reminder in dueReminders) reminder.animalId: reminder,
          };
          final hasReminderSummary = dueReminders.isNotEmpty;
          final overviewEntries = categoryGroups == null
              ? animals
                    .map(_AnimalOverviewListEntry.animal)
                    .toList(growable: false)
              : _categoryOverviewEntries(categoryGroups);

          return ListView.builder(
            key: const PageStorageKey<String>('animals-overview-list'),
            controller: _scrollController,
            itemCount: overviewEntries.length + (hasReminderSummary ? 1 : 0),
            itemBuilder: (context, index) {
              if (hasReminderSummary && index == 0) {
                return _buildReminderSummary(context, dueReminders, animals);
              }

              final entryIndex = hasReminderSummary ? index - 1 : index;
              final entry = overviewEntries[entryIndex];
              if (entry.category != null) {
                final category = entry.category!;
                return Semantics(
                  header: true,
                  child: Padding(
                    key: Key('animal-category-heading-${category.name}'),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      context.l10n.animalCategoryPluralLabel(category),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                );
              }
              if (entry.isSubcategoryHeading) {
                final subcategory = entry.subcategory;
                final headingKey = subcategory?.name ?? 'not-specified';
                return Semantics(
                  header: true,
                  child: Padding(
                    key: Key('animal-subcategory-heading-$headingKey'),
                    padding: const EdgeInsets.fromLTRB(32, 12, 16, 4),
                    child: Text(
                      subcategory == null
                          ? context.l10n.notSpecified
                          : context.l10n.animalSubcategoryPluralLabel(
                              subcategory,
                            ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              }

              final animal = entry.animal!;
              final dueReminder = dueRemindersByAnimalId[animal.id];
              final displayNames = AnimalDisplayNames.fromContext(
                context,
                commonName: animal.commonName,
                latinName: animal.latinName,
              );

              return OverviewContextMenu<_AnimalOverviewAction>(
                key: Key('animal-context-menu-region-${animal.id}'),
                menuButtonKey: Key('animal-context-menu-button-${animal.id}'),
                tooltip: context.l10n.animalActions(displayNames.primary),
                onSelected: (action) {
                  _handleAnimalAction(action, animal);
                },
                itemBuilder: (context) => [
                  _animalMenuItem(
                    action: _AnimalOverviewAction.createFeeding,
                    icon: Icons.restaurant_outlined,
                    label: context.l10n.createFeeding,
                  ),
                  _animalMenuItem(
                    action: _AnimalOverviewAction.rename,
                    icon: Icons.drive_file_rename_outline,
                    label: context.l10n.renameAnimal,
                  ),
                  _animalMenuItem(
                    action: _AnimalOverviewAction.edit,
                    icon: Icons.edit_outlined,
                    label: context.l10n.editAnimal,
                  ),
                  _animalMenuItem(
                    action: _AnimalOverviewAction.archive,
                    icon: Icons.archive_outlined,
                    label: context.l10n.archiveAnimal,
                  ),
                  _animalMenuItem(
                    action: _AnimalOverviewAction.duplicate,
                    icon: Icons.copy_outlined,
                    label: context.l10n.duplicateAnimal,
                  ),
                ],
                builder: (context, menuButton) => ListTile(
                  key: Key('animal-list-item-${animal.id}'),
                  leading: FutureBuilder<MediaAsset?>(
                    future: _pictureFutureFor(animal.pictureMediaId),
                    builder: (context, pictureSnapshot) {
                      return MediaThumbnail(
                        key: Key('animal-thumbnail-${animal.id}'),
                        pictureBytes: pictureSnapshot.data?.data,
                        picturePath: pictureSnapshot.data == null
                            ? animal.picturePath
                            : null,
                        fallbackIcon: Icons.emoji_nature_outlined,
                        semanticsLabel: context.l10n.animalThumbnailLabel(
                          displayNames.primary,
                        ),
                      );
                    },
                  ),
                  title: Text(displayNames.primary),
                  subtitle: Text(displayNames.secondary),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dueReminder != null) ...[
                        Container(
                          key: Key('animal-due-marker-${animal.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            context.l10n.due,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      menuButton,
                    ],
                  ),
                  onTap: () {
                    _openAnimalDetail(animal, animals);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'animals-add-fab',
        key: const Key('add-animal-button'),
        onPressed: _openNewAnimalPage,
        tooltip: context.l10n.addAnimal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

PopupMenuItem<_AnimalOverviewAction> _animalMenuItem({
  required _AnimalOverviewAction action,
  required IconData icon,
  required String label,
}) {
  return PopupMenuItem<_AnimalOverviewAction>(
    value: action,
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(label)),
      ],
    ),
  );
}

class _AnimalsOverviewData {
  final List<Animal> animals;
  final Map<int, DateTime> latestFeedingTimes;
  final List<FeedingReminderState> dueReminders;

  const _AnimalsOverviewData({
    required this.animals,
    required this.latestFeedingTimes,
    required this.dueReminders,
  });
}

class _AnimalOverviewListEntry {
  final AnimalCategory? category;
  final AnimalSubcategory? subcategory;
  final Animal? animal;
  final bool isSubcategoryHeading;

  const _AnimalOverviewListEntry._({
    this.category,
    this.subcategory,
    this.animal,
    this.isSubcategoryHeading = false,
  });

  const _AnimalOverviewListEntry.category(AnimalCategory category)
    : this._(category: category);

  const _AnimalOverviewListEntry.subcategory(AnimalSubcategory? subcategory)
    : this._(subcategory: subcategory, isSubcategoryHeading: true);

  const _AnimalOverviewListEntry.animal(Animal animal) : this._(animal: animal);
}

List<_AnimalOverviewListEntry> _categoryOverviewEntries(
  List<AnimalCategoryOverviewGroup> groups,
) {
  return [
    for (final group in groups) ...[
      _AnimalOverviewListEntry.category(group.category),
      for (final subgroup in group.subgroups) ...[
        if (subgroup.showHeading)
          _AnimalOverviewListEntry.subcategory(subgroup.subcategory),
        for (final animal in subgroup.animals)
          _AnimalOverviewListEntry.animal(animal),
      ],
    ],
  ];
}

String _formatDateTime(DateTime dateTime) {
  final localDateTime = dateTime.toLocal();
  final day = localDateTime.day.toString().padLeft(2, '0');
  final month = localDateTime.month.toString().padLeft(2, '0');
  final hour = localDateTime.hour.toString().padLeft(2, '0');
  final minute = localDateTime.minute.toString().padLeft(2, '0');

  return '$day.$month.${localDateTime.year} $hour:$minute';
}
