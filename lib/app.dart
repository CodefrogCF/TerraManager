import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/pages/app_shell.dart';
import 'features/settings/app_language.dart';
import 'features/settings/app_settings_controller.dart';
import 'l10n/app_localizations_context.dart';
import 'l10n/generated/app_localizations.dart';

class TerraManagerApp extends StatefulWidget {
  final AppDatabase database;
  final Locale? locale;

  const TerraManagerApp({super.key, required this.database, this.locale});

  @override
  State<TerraManagerApp> createState() => _TerraManagerAppState();
}

class _TerraManagerAppState extends State<TerraManagerApp> {
  late final AppSettingsController _settingsController;

  @override
  void initState() {
    super.initState();

    _settingsController = AppSettingsController();
    _settingsController.load();
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: _settingsController,
      child: ListenableBuilder(
        listenable: _settingsController,
        builder: (context, _) {
          final accentColor = _settingsController.accent.color;

          return MaterialApp(
            onGenerateTitle: (context) => context.l10n.appTitle,
            locale: widget.locale ?? _settingsController.language.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: supportedAppLocales,
            theme: AppTheme.lightTheme(seedColor: accentColor),
            darkTheme: AppTheme.darkTheme(seedColor: accentColor),
            themeMode: _settingsController.themeMode,
            home: AppShell(database: widget.database),
          );
        },
      ),
    );
  }
}
