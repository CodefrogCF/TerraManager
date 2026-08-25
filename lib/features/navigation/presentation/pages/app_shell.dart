import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../boxes/presentation/pages/boxes_page.dart';
import '../../../animals/presentation/pages/animals_page.dart';
import '../../../settings/presentation/pages/settings.dart';

class AppShell extends StatefulWidget {
  final AppDatabase database;

  const AppShell({
    super.key,
    required this.database,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      BoxesPage(database: widget.database),
      const AnimalsPage(),
      const SettingsPage(),
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
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Boxes',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_nature_outlined),
            selectedIcon: Icon(Icons.emoji_nature),
            label: 'Animals',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}