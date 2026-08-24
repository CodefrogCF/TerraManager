import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/boxes/presentation/pages/boxes_page.dart';

class TerraManagerApp extends StatelessWidget {
  const TerraManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerraManager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const BoxesPage(),
    );
  }
}