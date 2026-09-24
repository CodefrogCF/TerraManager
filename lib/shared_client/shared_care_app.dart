import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/settings/app_language.dart';
import '../features/settings/app_settings_controller.dart';
import '../l10n/app_localizations_context.dart';
import '../l10n/generated/app_localizations.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_text.dart';

class SharedCareApp extends StatefulWidget {
  const SharedCareApp({super.key, required this.api});

  final SharedApiClient api;

  @override
  State<SharedCareApp> createState() => _SharedCareAppState();
}

class _SharedCareAppState extends State<SharedCareApp> {
  final AppSettingsController _settings = AppSettingsController();

  @override
  void initState() {
    super.initState();
    unawaited(_settings.load());
  }

  @override
  void dispose() {
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
        onGenerateTitle: (context) => context.l10n.appTitle,
        locale: _settings.language.locale,
        supportedLocales: supportedAppLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightTheme(seedColor: _settings.accent.color),
        darkTheme: AppTheme.darkTheme(seedColor: _settings.accent.color),
        themeMode: _settings.themeMode,
        home: SharedCareHome(api: widget.api),
      ),
    ),
  );
}

class SharedCareHome extends StatefulWidget {
  const SharedCareHome({super.key, required this.api});

  final SharedApiClient api;

  @override
  State<SharedCareHome> createState() => _SharedCareHomeState();
}

class _SharedCareHomeState extends State<SharedCareHome>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  SharedSession? _session;
  List<Map<String, dynamic>> _boxes = const [];
  List<Map<String, dynamic>> _animals = const [];
  Object? _error;
  bool _busy = true;
  bool _connected = false;
  bool _refreshing = false;
  int _refreshVersion = 0;
  int _page = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
    widget.api.addListener(_onApiChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_foreground && _session != null && !_busy) {
        unawaited(_refresh(quiet: true));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.api.removeListener(_onApiChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _session != null && !_busy) {
      unawaited(_refresh(quiet: true));
    }
  }

  void _onApiChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    try {
      final session = await widget.api.restoreSession();
      if (!mounted) return;
      setState(() => _session = session);
      if (session != null) {
        await _refresh();
      } else {
        setState(() => _busy = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _busy = false;
        _connected = false;
      });
    }
  }

  Future<void> _login(String username, String password) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.api.login(username, password);
      if (!mounted) return;
      setState(() => _session = session);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error;
        _connected = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.logout();
      if (!mounted) return;
      setState(() {
        _session = null;
        _boxes = const [];
        _animals = const [];
        _connected = false;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (_session == null) return;
    if (quiet && _refreshing) return;
    final version = ++_refreshVersion;
    _refreshing = true;
    if (!quiet && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.api.boxes(),
        widget.api.animals(),
      ]);
      if (!mounted || version != _refreshVersion) return;
      setState(() {
        _boxes = results[0];
        _animals = results[1];
        _busy = false;
        _connected = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted || version != _refreshVersion) return;
      setState(() {
        _busy = false;
        _error = error;
        _connected = false;
        if (widget.api.session == null) _session = null;
      });
    } finally {
      if (version == _refreshVersion) _refreshing = false;
    }
  }

  Future<bool> _change(Future<void> Function() operation) async {
    if (!_connected || !widget.api.connected || _busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    _refreshVersion++;
    _refreshing = false;
    try {
      await operation();
      await _refresh();
      // A successful API response confirms the write even if the follow-up
      // reload fails. The collection remains disabled until it reloads.
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _error = error;
        _connected = widget.api.connected;
        _busy = false;
        if (widget.api.session == null) _session = null;
      });
      return false;
    }
  }

  String _errorMessage(BuildContext context, Object error) {
    if (error is SharedConnectionException) {
      return sharedText(
        context,
        'Connection lost. Check the server and reload before making changes.',
        'Verbindung verloren. Prüfe den Server und lade neu, bevor du Änderungen vornimmst.',
      );
    }
    if (error is SharedApiException) {
      if (error.code == 'invalid_credentials') {
        return sharedText(
          context,
          'Invalid username or password.',
          'Benutzername oder Passwort ungültig.',
        );
      }
      if (error.code == 'rate_limited') {
        return sharedText(
          context,
          'Too many attempts. Try again later.',
          'Zu viele Versuche. Bitte später erneut versuchen.',
        );
      }
      if (error.code == 'csrf_failed') {
        return sharedText(
          context,
          'Session verification failed. Reload and sign in again.',
          'Sitzungsprüfung fehlgeschlagen. Neu laden und erneut anmelden.',
        );
      }
      if (error.status == 401) {
        return sharedText(
          context,
          'Your session expired. Please sign in again.',
          'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
        );
      }
      if (Localizations.localeOf(context).languageCode == 'de') {
        return switch (error.code) {
          'stale_record' => 'Der Datensatz wurde geändert. Bitte neu laden und den neuen Stand prüfen.',
          'conflict' => 'Die Änderung widerspricht dem aktuellen Serverstand. Bitte neu laden.',
          'invalid_data' =>
            'Die eingegebenen Daten wurden vom Server abgelehnt.',
          'forbidden' => 'Für diese Aktion fehlt die Berechtigung.',
          _ => 'Die Anfrage konnte nicht abgeschlossen werden.',
        };
      }
      return error.message;
    }
    return sharedText(
      context,
      'The request could not be completed.',
      'Die Anfrage konnte nicht abgeschlossen werden.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_busy && _session == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_session == null) {
      return SharedLoginPage(
        busy: _busy,
        error: _error == null ? null : _errorMessage(context, _error!),
        onLogin: _login,
        onRetry: _bootstrap,
      );
    }

    final canChange = _connected && widget.api.connected && !_busy;
    final content = switch (_page) {
      0 => SharedBoxesPage(
        api: widget.api,
        boxes: _boxes,
        animals: _animals,
        connected: canChange,
        change: _change,
        onReload: _refresh,
      ),
      1 => SharedAnimalsPage(
        api: widget.api,
        boxes: _boxes,
        animals: _animals,
        connected: canChange,
        change: _change,
        onReload: _refresh,
      ),
      _ => SharedSettingsPage(
        api: widget.api,
        username: _session!.username,
        role: _session!.role,
        connected: _connected && widget.api.connected,
        actionsEnabled: canChange,
        onLogout: _logout,
        onRestored: _refresh,
      ),
    };

    return Scaffold(
      appBar: _page == 2
          ? AppBar(
              title: Text(context.l10n.navigationSettings),
              actions: [
                IconButton(
                  key: const Key('shared-refresh'),
                  tooltip: sharedText(context, 'Reload', 'Neu laden'),
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            MaterialBanner(
              key: const Key('shared-error'),
              content: Text(_errorMessage(context, _error!)),
              actions: [
                TextButton(
                  onPressed: _busy ? null : _refresh,
                  child: Text(sharedText(context, 'Retry', 'Erneut versuchen')),
                ),
              ],
            ),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (index) => setState(() => _page = index),
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
    );
  }
}

class SharedLoginPage extends StatefulWidget {
  const SharedLoginPage({
    super.key,
    required this.busy,
    required this.error,
    required this.onLogin,
    required this.onRetry,
  });

  final bool busy;
  final String? error;
  final Future<void> Function(String, String) onLogin;
  final Future<void> Function() onRetry;

  @override
  State<SharedLoginPage> createState() => _SharedLoginPageState();
}

class _SharedLoginPageState extends State<SharedLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.appTitle)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sharedText(context, 'Shared Care', 'Gemeinsame Betreuung'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                key: const Key('shared-username'),
                controller: _username,
                enabled: !widget.busy,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(
                  labelText: sharedText(context, 'Username', 'Benutzername'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('shared-password'),
                controller: _password,
                enabled: !widget.busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: sharedText(context, 'Password', 'Passwort'),
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('shared-login'),
                onPressed: widget.busy ? null : _submit,
                child: Text(sharedText(context, 'Sign in', 'Anmelden')),
              ),
              if (widget.error != null)
                TextButton(
                  onPressed: widget.busy ? null : widget.onRetry,
                  child: Text(sharedText(context, 'Retry', 'Erneut versuchen')),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  void _submit() {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return;
    widget.onLogin(_username.text.trim(), _password.text);
  }
}
