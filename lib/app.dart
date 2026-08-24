import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/pages/app_shell.dart';

class TerraManagerApp extends StatelessWidget {
  const TerraManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerraManager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}