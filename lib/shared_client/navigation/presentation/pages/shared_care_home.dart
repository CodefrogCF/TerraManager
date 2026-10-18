import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';

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
  bool _commandBusy = false;
  void _onSyncChanged() {
    if (!mounted || _session == null || _backupBusy) return;
    final sync = widget.api.synchronization;
    final finished = sync.connected;
    if (_connected != sync.connected ||
        _error != sync.error ||
        (finished && (!_initialLoaded || (_busy && !_commandBusy)))) {
      setState(() {
        _connected = sync.connected;
        _error = sync.error;
        if (finished) {
          _initialLoaded = true;
          if (!_commandBusy) _busy = false;
        } else if (sync.error != null && !_commandBusy) {
          _busy = false;
        }
      });
    }
  }

  SharedSession? _session;
  List<Map<String, dynamic>> _boxes = const [];
  List<Map<String, dynamic>> _animals = const [];
  List<Map<String, dynamic>> _reminders = const [];
  Object? _error;
  bool _busy = true;
  bool _connected = false;
  bool _backupBusy = false;
  int _page = 0;
  bool _initialLoaded = false;
  bool _foreground = true;
  ModalRoute<dynamic>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  final _subscriptions = <SharedRefreshSubscription>[];

  Future<void> _readCollection(String kind) async {
    final owner = widget.api.session;
    final generation = widget.api.refresh.generation;
    final values = await switch (kind) {
      'boxes' => widget.api.boxes(),
      'animals' => widget.api.animals(),
      _ => widget.api.reminders(),
    };
    if (!mounted ||
        _session == null ||
        !identical(owner, widget.api.session) ||
        generation != widget.api.refresh.generation) {
      return;
    }
    setState(() {
      switch (kind) {
        case 'boxes':
          _boxes = values;
        case 'animals':
          _animals = values;
        default:
          _reminders = values;
          _scheduleDueTimes();
      }
    });
  }

  void _scheduleDueTimes() => widget.api.refresh.scheduleDueTimes(
    _reminders
        .map((r) => DateTime.tryParse(r['dueAt'] as String? ?? ''))
        .whereType<DateTime>(),
  );
  void _clockChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pollChanges() async {
    if (_session == null || _backupBusy || !_foreground) return;
    final owner = widget.api.session;
    final generation = widget.api.refresh.generation;
    bool current() =>
        mounted &&
        identical(owner, widget.api.session) &&
        generation == widget.api.refresh.generation &&
        _foreground &&
        !_backupBusy;
    try {
      await widget.api.synchronization.reconcile();
      if (current()) _onSyncChanged();
    } catch (error) {
      if (current()) {
        setState(() {
          _busy = false;
          _connected = false;
          _error = error;
        });
      }
    }
  }

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
    for (final kind in ['boxes', 'animals', 'reminders']) {
      _subscriptions.add(
        widget.api.refresh.watch(
          dependencies: () => {kind: null},
          isVisible: () =>
              mounted &&
              _session != null &&
              !_backupBusy &&
              (!_initialLoaded ||
                  widget.api.refresh.hasVisibleDemand(kind) ||
                  (kind != 'boxes' && (_route?.isCurrent ?? true))),
          refresh: (_) => _readCollection(kind),
        ),
      );
    }
    widget.api.refresh.clock.addListener(_clockChanged);
    widget.api.synchronization.addListener(_onSyncChanged);
    unawaited(_bootstrap());
    widget.api.addListener(_onApiChanged);
  }

  @override
  void dispose() {
    widget.api.synchronization.removeListener(_onSyncChanged);
    widget.api.synchronization.setSession(null);
    for (final s in _subscriptions) {
      s.dispose();
    }
    widget.api.refresh.clock.removeListener(_clockChanged);
    WidgetsBinding.instance.removeObserver(this);
    widget.api.removeListener(_onApiChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    widget.api.synchronization.setEnvironment(
      foreground: _foreground,
      backupBusy: _backupBusy,
    );
  }

  void _onApiChanged() {
    final current = widget.api.session;
    if (_session != null &&
        identical(_session, current) &&
        !widget.api.connected) {
      widget.api.synchronization.reportConnectionFailure(
        const SharedConnectionException(),
      );
    }
    if (_session != null && !identical(_session, current)) {
      _session = current;
      _initialLoaded = false;
      _boxes = const [];
      _animals = const [];
      _reminders = const [];
      _commandBusy = false;
      _connected = false;
      _busy = current != null;
      widget.api.synchronization.setSession(current);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(current, widget.api.session)) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
    if (mounted) setState(() {});
  }

  void _onBackupBusyChanged(bool busy) {
    if (_backupBusy == busy) return;
    _backupBusy = busy;
    widget.api.synchronization.setEnvironment(
      foreground: _foreground,
      backupBusy: busy,
    );
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    try {
      final session = await widget.api.restoreSession();
      if (!mounted) return;
      setState(() => _session = session);
      widget.api.synchronization.setSession(session);
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
      widget.api.synchronization.setSession(session);
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
    final owner = widget.api.session;
    try {
      await widget.api.logout();
      if (!mounted ||
          (widget.api.session != null &&
              !identical(owner, widget.api.session))) {
        return;
      }
      setState(() {
        _session = null;
        _boxes = const [];
        _animals = const [];
        _reminders = const [];
        _connected = false;
        _busy = false;
      });
    } catch (error) {
      if (!mounted ||
          (widget.api.session != null &&
              !identical(owner, widget.api.session))) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (_session == null || _backupBusy) return;
    if (!quiet && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    if (_initialLoaded) {
      widget.api.refresh.invalidate(SharedInvalidation({}, true));
    }
    await _pollChanges();
  }

  Future<bool> _change(Future<void> Function() operation) async {
    if (!_connected || !widget.api.connected || _busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    final owner = widget.api.session;
    _commandBusy = true;
    try {
      await operation();
      if (!identical(owner, widget.api.session)) return false;
      await _pollChanges();
      // A successful API response confirms the write even if the follow-up
      // reload fails. The collection remains disabled until it reloads.
      return true;
    } catch (error) {
      if (!identical(owner, widget.api.session)) return false;
      if (error is SharedConnectionException) {
        widget.api.synchronization.reportConnectionFailure(error);
      }
      if (!mounted) return false;
      setState(() {
        _error = error;
        _connected = widget.api.connected;
        _busy = false;
        if (widget.api.session == null) _session = null;
      });
      return false;
    } finally {
      if (identical(owner, widget.api.session)) {
        _commandBusy = false;
        if (mounted) setState(() => _busy = false);
      }
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
        onRestored: () async {
          _initialLoaded = false;
          widget.api.synchronization.collectionReplaced();
        },
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
