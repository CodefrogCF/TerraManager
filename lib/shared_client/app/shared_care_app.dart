import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/core/theme/app_theme.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/navigation/presentation/pages/shared_care_home.dart';
import 'package:terramanager/shared_client/navigation/presentation/shared_browser_back_observer.dart';
import 'package:terramanager/shared_client/settings/application/shared_account_settings.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

class SharedCareApp extends StatefulWidget {
  const SharedCareApp({super.key, required this.api});

  final SharedApiClient api;

  @override
  State<SharedCareApp> createState() => _SharedCareAppState();
}

class _SharedCareAppState extends State<SharedCareApp> {
  late final SharedAccountSettings _settings = SharedAccountSettings(
    widget.api,
  );
  final _browserBack = SharedBrowserBackObserver();
  final _webNavigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    unawaited(_settings.load());
  }

  @override
  void dispose() {
    _browserBack.dispose();
    widget.api.close();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSettingsScope(
    controller: _settings,
    child: ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        navigatorObservers: kIsWeb ? const [] : [_browserBack],
        // MaterialApp's default Navigator selects single-entry browser history.
        // Shared Care owns a multi-entry stack for its imperative routes instead.
        builder: (context, child) => Column(
          children: [
            if (_settings.saveError != null)
              MaterialBanner(
                content: Text(
                  sharedText(
                    context,
                    'Personal preferences could not be saved. Check your connection and try again.',
                    'Persönliche Einstellungen konnten nicht gespeichert werden. Prüfe die Verbindung und versuche es erneut.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _settings.dismissError,
                    child: Text(sharedText(context, 'Dismiss', 'Schließen')),
                  ),
                ],
              ),
            Expanded(
              child: kIsWeb
                  ? Navigator(
                      key: _webNavigator,
                      reportsRouteUpdateToEngine: false,
                      observers: [_browserBack],
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => ConstrainedPageWidth(
                          maxWidth: 960,
                          child: SharedCareHome(api: widget.api),
                        ),
                      ),
                    )
                  : child!,
            ),
          ],
        ),
        onGenerateTitle: (context) => context.l10n.appTitle,
        locale: _settings.language.locale,
        supportedLocales: supportedAppLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightTheme(seedColor: _settings.accent.color),
        darkTheme: AppTheme.darkTheme(seedColor: _settings.accent.color),
        themeMode: _settings.themeMode,
        home: ConstrainedPageWidth(
          maxWidth: 960,
          child: SharedCareHome(api: widget.api),
        ),
      ),
    ),
  );
}
