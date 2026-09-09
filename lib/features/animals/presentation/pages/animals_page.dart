import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/feeding_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../feedings/application/feeding_reminder_service.dart';
import '../../../feedings/domain/feeding_reminder_state.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import '../../../settings/animal_name_order.dart';
import '../../../settings/animal_sort_order.dart';
import '../../../settings/app_settings_controller.dart';
import '../animal_display_names.dart';
import '../animal_overview_sorting.dart';
import 'animal_detail_page.dart';
import 'animal_history_page.dart';
import 'new_animal_page.dart';

class AnimalsPage extends StatefulWidget {
  final AppDatabase database;
  final FeedingReminderClock? reminderNow;

  const AnimalsPage({super.key, required this.database, this.reminderNow});

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
    final animalNameOrder =
        settings?.animalNameOrder ?? AnimalNameOrder.commonNameFirst;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navigationAnimals),
        actions: [
          PopupMenuButton<AnimalSortOrder>(
            key: const Key('animal-sort-button'),
            initialValue: animalSortOrder,
            onSelected: (sortOrder) {
              settings?.setAnimalSortOrder(sortOrder);
            },
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.sortAnimals,
            itemBuilder: (context) {
              return AnimalSortOrder.values.map((sortOrder) {
                return CheckedPopupMenuItem<AnimalSortOrder>(
                  value: sortOrder,
                  checked: sortOrder == animalSortOrder,
                  child: Text(context.l10n.animalSortOrderLabel(sortOrder)),
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
          final animals = sortAnimalsForOverview(
            data?.animals ?? const <Animal>[],
            sortOrder: animalSortOrder,
            nameOrder: animalNameOrder,
            latestFeedingTimes:
                data?.latestFeedingTimes ?? const <int, DateTime>{},
          );
          final dueReminders =
              data?.dueReminders ?? const <FeedingReminderState>[];

          if (animals.isEmpty) {
            return Center(child: Text(context.l10n.noAnimalsAvailable));
          }

          final dueRemindersByAnimalId = {
            for (final reminder in dueReminders) reminder.animalId: reminder,
          };
          final hasReminderSummary = dueReminders.isNotEmpty;

          return ListView.builder(
            key: const PageStorageKey<String>('animals-overview-list'),
            controller: _scrollController,
            itemCount: animals.length + (hasReminderSummary ? 1 : 0),
            itemBuilder: (context, index) {
              if (hasReminderSummary && index == 0) {
                return _buildReminderSummary(context, dueReminders, animals);
              }

              final animalIndex = hasReminderSummary ? index - 1 : index;
              final animal = animals[animalIndex];
              final dueReminder = dueRemindersByAnimalId[animal.id];
              final displayNames = AnimalDisplayNames.fromContext(
                context,
                commonName: animal.commonName,
                latinName: animal.latinName,
              );

              return ListTile(
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
                    );
                  },
                ),
                title: Text(displayNames.primary),
                subtitle: Text(displayNames.secondary),
                trailing: dueReminder == null
                    ? const Icon(Icons.chevron_right)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: Key('animal-due-marker-${animal.id}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
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
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                onTap: () {
                  _openAnimalDetail(animal, animals);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-animal-button'),
        onPressed: _openNewAnimalPage,
        tooltip: context.l10n.addAnimal,
        child: const Icon(Icons.add),
      ),
    );
  }
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

String _formatDateTime(DateTime dateTime) {
  final localDateTime = dateTime.toLocal();
  final day = localDateTime.day.toString().padLeft(2, '0');
  final month = localDateTime.month.toString().padLeft(2, '0');
  final hour = localDateTime.hour.toString().padLeft(2, '0');
  final minute = localDateTime.minute.toString().padLeft(2, '0');

  return '$day.$month.${localDateTime.year} $hour:$minute';
}
