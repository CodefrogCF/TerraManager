import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../animals/presentation/pages/animals_page.dart';
import '../../../boxes/presentation/pages/boxes_page.dart';
import '../../../settings/presentation/pages/settings.dart';

class AppShell extends StatefulWidget {
  final AppDatabase database;

  const AppShell({
    super.key,
    required this.database,
  });

  @override
  State<AppShell> createState() =>
      _AppShellState();
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
        key: ValueKey(
          'boxes-$_dataRevision',
        ),
        database: widget.database,
      ),
      AnimalsPage(
        key: ValueKey(
          'animals-$_dataRevision',
        ),
        database: widget.database,
      ),
      SettingsPage(
        database: widget.database,
        onRestoreCompleted:
            _handleRestoreCompleted,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon:
                Icon(Icons.home),
            label: 'Boxes',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.pets_outlined,
            ),
            selectedIcon:
                Icon(Icons.pets),
            label: 'Animals',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
            ),
            selectedIcon:
                Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}