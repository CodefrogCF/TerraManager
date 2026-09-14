import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../animals/presentation/pages/animals_page.dart';
import '../../../boxes/presentation/pages/boxes_page.dart';
import '../../../settings/presentation/pages/settings.dart';

class AppShell extends StatefulWidget {
  final AppDatabase database;

  const AppShell({super.key, required this.database});

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
  }

  void _handleFeedingChanged() {
    setState(() {
      _dataRevision++;
    });
  }

  void _handleAnimalsChanged() {
    setState(() {
      _animalsRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BoxesPage(
        key: ValueKey('boxes-$_dataRevision'),
        database: widget.database,
        onFeedingChanged: _handleFeedingChanged,
        onAnimalsChanged: _handleAnimalsChanged,
      ),
      AnimalsPage(
        key: ValueKey('animals-$_dataRevision'),
        database: widget.database,
        dataRevision: _animalsRevision,
      ),
      SettingsPage(
        database: widget.database,
        onRestoreCompleted: _handleRestoreCompleted,
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
              icon: const Icon(Icons.pets_outlined),
              selectedIcon: const Icon(Icons.pets),
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
