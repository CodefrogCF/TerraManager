import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/pages/app_shell.dart';

class TerraManagerApp extends StatelessWidget {
  final AppDatabase database;

  const TerraManagerApp({
    super.key,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerraManager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: AppShell(database: database),
    );
  }
}