import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../animals/presentation/pages/animals_page.dart';
import '../../../boxes/presentation/pages/boxes_page.dart';
import '../../../settings/presentation/pages/settings.dart';
import '../../../feedings/application/feeding_reminder_service.dart';
import '../../../feedings/domain/feeding_reminder_state.dart';
import '../../../feedings/presentation/widgets/feeding_reminder_clock.dart';

class AppShell extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onReplayTutorial;
  final VoidCallback? onShowReleaseHighlights;
  final FeedingReminderClock? reminderNow;
  final int dataRevision;

  const AppShell({
    super.key,
    required this.database,
    this.onReplayTutorial,
    this.onShowReleaseHighlights,
    this.reminderNow,
    this.dataRevision = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _pageCount = 3;
  static const double _minimumSwipeDistance = 80;
  static const double _minimumSwipeVelocity = 500;

  int _currentIndex = 0;
  int _dataRevision = 0;
  double _horizontalDragDistance = 0;
  int _animalsRevision = 0;
  List<FeedingReminderState> _feedingReminders = const [];
  int _reminderRequest = 0;
  StreamSubscription<Set<TableUpdate>>? _reminderChanges;

  @override
  void initState() {
    super.initState();
    _watchReminderChanges();
    _refreshReminderDate();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.database != oldWidget.database) {
      _watchReminderChanges();
    }
    if (widget.database != oldWidget.database ||
        widget.dataRevision != oldWidget.dataRevision) {
      _dataRevision++;
      _refreshReminderDate();
    }
  }

  @override
  void dispose() {
    unawaited(_reminderChanges?.cancel());
    super.dispose();
  }

  void _watchReminderChanges() {
    unawaited(_reminderChanges?.cancel());
    final database = widget.database;
    _reminderChanges = database
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            database.animals,
            database.feedingEvents,
          ]),
        )
        .listen((_) {
          if (!mounted || widget.database != database) return;
          setState(() => _animalsRevision++);
          unawaited(_refreshReminderDate());
        });
  }

  Future<void> _refreshReminderDate() async {
    final request = ++_reminderRequest;

    final reminders = await FeedingReminderService(
      widget.database,
      now: widget.reminderNow,
    ).getReminderStates(includePaused: true);

    if (!mounted || request != _reminderRequest) {
      return;
    }

    setState(() => _feedingReminders = reminders);
  }

  void _selectPage(int index) {
    if (index < 0 || index >= _pageCount || index == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _horizontalDragDistance = 0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? 0;
  }

  void _handleHorizontalDragCancel() {
    _horizontalDragDistance = 0;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final hasEnoughDistance =
        _horizontalDragDistance.abs() >= _minimumSwipeDistance;
    final hasEnoughVelocity = velocity.abs() >= _minimumSwipeVelocity;

    if (!hasEnoughDistance && !hasEnoughVelocity) {
      _horizontalDragDistance = 0;
      return;
    }

    final direction = hasEnoughVelocity ? velocity : _horizontalDragDistance;
    _selectPage(direction < 0 ? _currentIndex + 1 : _currentIndex - 1);
    _horizontalDragDistance = 0;
  }

  void _handleRestoreCompleted() {
    setState(() {
      _dataRevision++;
    });

    _refreshReminderDate();
  }

  Widget _animalsNavigationIcon({
    required bool selected,
    required DateTime now,
  }) {
    return Badge(
      key: Key(
        selected
            ? 'animals-feeding-due-badge-selected'
            : 'animals-feeding-due-badge',
      ),
      isLabelVisible: _feedingReminders.any(
        (reminder) => reminder.isDueAt(now),
      ),
      label: const Text('!'),
      child: Icon(selected ? Icons.pets : Icons.pets_outlined),
    );
  }

  @override
  Widget build(BuildContext context) => FeedingReminderClockView(
    transitions: _feedingReminders.expand((reminder) => reminder.transitions),
    now: widget.reminderNow,
    builder: _buildAt,
  );

  Widget _buildAt(BuildContext context, DateTime now) {
    final pages = [
      BoxesPage(
        key: ValueKey('boxes-$_dataRevision'),
        database: widget.database,
      ),
      AnimalsPage(
        key: ValueKey('animals-$_dataRevision'),
        database: widget.database,
        reminderNow: widget.reminderNow,
        dataRevision: _animalsRevision,
      ),
      SettingsPage(
        database: widget.database,
        onRestoreCompleted: _handleRestoreCompleted,
        onReplayTutorial: widget.onReplayTutorial,
        onShowReleaseHighlights: widget.onShowReleaseHighlights,
      ),
    ];

    final pageLabel = switch (_currentIndex) {
      0 => context.l10n.navigationBoxes,
      1 => context.l10n.navigationAnimals,
      _ => context.l10n.navigationSettings,
    };

    return Scaffold(
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.pageUp, control: true): () =>
              _selectPage(_currentIndex - 1),
          const SingleActivator(
            LogicalKeyboardKey.pageDown,
            control: true,
          ): () =>
              _selectPage(_currentIndex + 1),
        },
        child: Focus(
          autofocus: true,
          child: Semantics(
            key: const Key('primary-page-semantics'),
            container: true,
            explicitChildNodes: true,
            label: context.l10n.primaryPage,
            value: pageLabel,
            hint: context.l10n.primaryPageSwipeHint,
            child: GestureDetector(
              key: const Key('primary-page-swipe-area'),
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onHorizontalDragStart: _handleHorizontalDragStart,
              onHorizontalDragUpdate: _handleHorizontalDragUpdate,
              onHorizontalDragCancel: _handleHorizontalDragCancel,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Semantics(
        key: const Key('primary-navigation-semantics'),
        container: true,
        label: context.l10n.primaryNavigation,
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectPage,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: context.l10n.navigationBoxes,
            ),
            NavigationDestination(
              icon: _animalsNavigationIcon(selected: false, now: now),
              selectedIcon: _animalsNavigationIcon(selected: true, now: now),
              label: context.l10n.navigationAnimals,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: context.l10n.navigationSettings,
            ),
          ],
        ),
      ),
    );
  }
}
