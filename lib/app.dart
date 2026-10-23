import 'dart:async';

import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'features/animals/presentation/pages/animal_detail_page.dart';
import 'features/notifications/application/feeding_notification_controller.dart';
import 'features/notifications/application/local_notification_gateway.dart';
import 'features/notifications/infrastructure/android_local_notification_gateway.dart';
import 'features/notifications/infrastructure/local_notification_store.dart';
import 'features/notifications/presentation/local_notifications_settings.dart';
import 'features/onboarding/presentation/standalone_tutorial_gate.dart';
import 'features/settings/app_language.dart';
import 'features/settings/app_settings_controller.dart';
import 'l10n/app_localizations_context.dart';
import 'l10n/generated/app_localizations.dart';

class TerraManagerApp extends StatefulWidget {
  final AppDatabase database;
  final Locale? locale;
  final LocalNotificationGateway? notificationGateway;

  const TerraManagerApp({
    super.key,
    required this.database,
    this.locale,
    this.notificationGateway,
  });

  @override
  State<TerraManagerApp> createState() => _TerraManagerAppState();
}

class _TerraManagerAppState extends State<TerraManagerApp>
    with WidgetsBindingObserver {
  late final AppSettingsController _settingsController;
  late final FeedingNotificationController _notifications;
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  int? _pendingAnimal;
  int? _openedAnimal;
  bool _unavailableTarget = false;
  int _notificationDetailRevision = 0;

  @override
  void initState() {
    super.initState();

    _settingsController = AppSettingsController();
    _notifications = FeedingNotificationController(
      database: widget.database,
      gateway: widget.notificationGateway ?? AndroidLocalNotificationGateway(),
      store: PreferenceNotificationStore(),
      onOpenAnimal: (id) {
        _pendingAnimal = id;
        _drainNotificationTap();
      },
      onUnavailableTarget: () {
        _unavailableTarget = true;
        _drainNotificationTap();
      },
    );
    WidgetsBinding.instance.addObserver(this);
    _settingsController.addListener(_updateNotificationLanguage);
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    await _settingsController.load();
    if (!mounted) return;
    _updateNotificationLanguage();
    await _notifications.start();
  }

  void _updateNotificationLanguage() {
    final locale =
        widget.locale ??
        _settingsController.language.locale ??
        WidgetsBinding.instance.platformDispatcher.locale;
    unawaited(_notifications.setLanguage(locale.languageCode));
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _updateNotificationLanguage();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateNotificationLanguage();
      unawaited(_notifications.refresh(renew: true));
    }
  }

  void _drainNotificationTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _navigator.currentState == null) return;
      final id = _pendingAnimal;
      _pendingAnimal = null;
      if (id != null && id != _openedAnimal) {
        _openedAnimal = id;
        await _navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) =>
                AnimalDetailPage(database: widget.database, animalId: id),
          ),
        );
        _openedAnimal = null;
        if (mounted) {
          setState(() => _notificationDetailRevision++);
        }
      }
      if (_unavailableTarget && mounted) {
        _unavailableTarget = false;
        final context = _navigator.currentContext;
        if (context != null && context.mounted) {
          _messenger.currentState?.showSnackBar(
            SnackBar(content: Text(context.l10n.localNotificationsUnavailable)),
          );
        }
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsController.removeListener(_updateNotificationLanguage);
    _notifications.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LocalNotificationsScope(
      controller: _notifications,
      child: AppSettingsScope(
        controller: _settingsController,
        child: ListenableBuilder(
          listenable: _settingsController,
          builder: (context, _) {
            final accentColor = _settingsController.accent.color;

            return MaterialApp(
              navigatorKey: _navigator,
              scaffoldMessengerKey: _messenger,
              builder: (context, child) {
                // A cold-start tap can arrive before localization has created
                // the Navigator. Drain it once that subtree is ready.
                if (_pendingAnimal != null || _unavailableTarget) {
                  _drainNotificationTap();
                }
                return child ?? const SizedBox.shrink();
              },
              onGenerateTitle: (context) => context.l10n.appTitle,
              locale: widget.locale ?? _settingsController.language.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: supportedAppLocales,
              theme: AppTheme.lightTheme(seedColor: accentColor),
              darkTheme: AppTheme.darkTheme(seedColor: accentColor),
              themeMode: _settingsController.themeMode,
              home: StandaloneTutorialGate(
                database: widget.database,
                dataRevision: _notificationDetailRevision,
              ),
            );
          },
        ),
      ),
    );
  }
}
