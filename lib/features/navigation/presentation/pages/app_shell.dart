import 'package:flutter/material.dart';

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
  int _currentIndex = 0;
  int _dataRevision = 0;

  void _handleRestoreCompleted() {
    setState(() {
      _dataRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BoxesPage(
        key: ValueKey('boxes-$_dataRevision'),
        database: widget.database,
      ),
      AnimalsPage(
        key: ValueKey('animals-$_dataRevision'),
        database: widget.database,
      ),
      SettingsPage(
        database: widget.database,
        onRestoreCompleted: _handleRestoreCompleted,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
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
    );
  }
}
