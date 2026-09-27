import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_client/authentication/presentation/pages/shared_login_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_boxes_page.dart';
import 'package:terramanager/shared_client/feedings/presentation/feeding_reminder_state.dart';
import 'package:terramanager/shared_client/settings/presentation/pages/shared_settings_page.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

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
  List<Map<String, dynamic>> _reminders = const [];
  Object? _error;
  bool _busy = true;
  bool _connected = false;
  bool _refreshing = false;
  bool _backupBusy = false;
  int _refreshVersion = 0;
  int _page = 0;
  bool _foreground = true;

  Widget _animalsNavigationIcon({required bool selected}) => Badge(
    key: Key(
      selected
          ? 'animals-feeding-due-badge-selected'
          : 'animals-feeding-due-badge',
    ),
    isLabelVisible: _connected && hasDueSharedFeedings(_animals, _reminders),
    label: const Text('!'),
    child: Icon(selected ? Icons.pets : Icons.pets_outlined),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
    widget.api.addListener(_onApiChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_foreground && _session != null && !_busy && !_backupBusy) {
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
    if (_foreground && _session != null && !_busy && !_backupBusy) {
      unawaited(_refresh(quiet: true));
    }
  }

  void _onApiChanged() {
    if (_session != null && widget.api.session == null) {
      _session = null;
      _boxes = const [];
      _animals = const [];
      _reminders = const [];
      _refreshVersion++;
      _refreshing = false;
      _busy = false;
    }
    if (mounted) setState(() {});
  }

  void _onBackupBusyChanged(bool busy) {
    if (_backupBusy == busy) return;
    _backupBusy = busy;
    if (busy) {
      // Ignore a refresh that began before the exclusive backup operation.
      _refreshVersion++;
      _refreshing = false;
    }
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
        _reminders = const [];
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
    if (quiet && (_refreshing || _backupBusy)) return;
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
        widget.api.reminders(),
      ]);
      if (!mounted || version != _refreshVersion) return;
      setState(() {
        _boxes = results[0];
        _animals = results[1];
        _reminders = results[2];
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

    final canChange =
        _connected && widget.api.connected && !_busy && !_backupBusy;
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
        reminders: _reminders,
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
        onBackupBusyChanged: _onBackupBusyChanged,
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
            icon: _animalsNavigationIcon(selected: false),
            selectedIcon: _animalsNavigationIcon(selected: true),
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
