import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../feedings/application/feeding_reminder_service.dart';
import '../domain/feeding_notification_target.dart';
import '../infrastructure/local_notification_store.dart';
import 'local_notification_gateway.dart';

class FeedingNotificationController extends ChangeNotifier {
  FeedingNotificationController({
    required this.database,
    required this.gateway,
    required this.store,
    DateTime Function()? now,
    this.onOpenAnimal,
    this.onUnavailableTarget,
  }) : _now = now ?? DateTime.now,
       _reminders = FeedingReminderService(database, now: now);

  final AppDatabase database;
  final LocalNotificationGateway gateway;
  final LocalNotificationStore store;
  final void Function(int animalId)? onOpenAnimal;
  final VoidCallback? onUnavailableTarget;
  final DateTime Function() _now;
  final FeedingReminderService _reminders;
  StreamSubscription<Object?>? _changes;
  Future<void> _work = Future.value();
  final Map<String, _Delivery> _deliveries = {};
  bool _disposed = false;
  bool _started = false;
  bool _ready = false;
  bool _denied = false;
  bool _enabled = false;
  bool _allowed = false;
  bool _busy = false;
  bool _failed = false;
  String _languageCode = 'en';

  bool get isSupported => gateway.isSupported;
  bool get enabled => _enabled;
  bool get allowed => _allowed;
  bool get busy => _busy;
  bool get failed => _failed;
  bool get permissionBlocked => _denied || (_enabled && !_allowed);

  /// All writes and reconciliations are serialized, including committed DB changes.
  Future<void> _enqueue(Future<void> Function() operation) {
    _work = _work.then((_) async {
      if (_disposed || !isSupported) return;
      _busy = true;
      notifyListeners();
      try {
        if (!_ready) await _prepare();
        await operation();
      } catch (_) {
        _failed = true;
      } finally {
        _busy = false;
        if (!_disposed) notifyListeners();
      }
    });
    return _work;
  }

  Future<void> start() {
    if (_started || !isSupported) return _work;
    _started = true;
    return _enqueue(() => _reconcile(renew: true));
  }

  Future<void> _prepare() async {
    final raw = await store.read();
    if (raw != null) {
      try {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        _enabled = value['enabled'] == true;
        for (final item in (value['deliveries'] as List? ?? [])) {
          final delivery = _Delivery.fromJson(item as Map<String, dynamic>);
          _deliveries[delivery.target.identity] = delivery;
        }
      } on Object {
        // A corrupt device preference must never opt the user in.
        _enabled = false;
        _deliveries.clear();
      }
    }
    await gateway.initialize((payload) => unawaited(openPayload(payload)));
    _changes = database.tableUpdates().listen((updates) {
      if (updates.any(
        (update) =>
            update.table == database.animals.actualTableName ||
            update.table == database.feedingEvents.actualTableName,
      )) {
        unawaited(refresh());
      }
    });
    _ready = true;
  }

  Future<void> setEnabled(bool value) => _enqueue(() async {
    if (value) {
      _allowed = await gateway.requestPermission();
      _denied = !_allowed;
      if (!_allowed) {
        _enabled = false;
        await _save();
        await gateway.cancelAll();
        return;
      }
    }
    final previousEnabled = _enabled;
    _enabled = value;
    // Persist opt-out before OS calls, so a failed cancellation is retried at restart.
    try {
      await _save();
    } catch (_) {
      _enabled = previousEnabled;
      rethrow;
    }
    await _reconcile();
  });

  Future<void> refresh({bool renew = false}) =>
      _enqueue(() => _reconcile(renew: renew, preserveDue: true));

  Future<void> setLanguage(String code) {
    final language = code == 'de' ? 'de' : 'en';
    if (_languageCode == language) return _work;
    _languageCode = language;
    return refresh();
  }

  Future<void> openSettings() => _enqueue(gateway.openSettings);

  Future<void> _save() => store.write(
    jsonEncode({
      'enabled': _enabled,
      'deliveries': _deliveries.values.map((item) => item.toJson()).toList(),
    }),
  );

  Future<void> _reconcile({
    bool renew = false,
    bool preserveDue = false,
  }) async {
    _failed = false;
    final language = _languageCode;
    _allowed = await gateway.isAllowed();
    if (_allowed) _denied = false;
    if (!_enabled || !_allowed) {
      final pending = await gateway.pendingIds();
      await gateway.cancelAll();
      // Keep consumed appointments while permission is temporarily revoked.
      if (!_enabled) {
        _deliveries.clear();
      } else {
        _deliveries.removeWhere((_, delivery) => pending.contains(delivery.id));
      }
      await _save();
      return;
    }
    final states = await _reminders.getReminderStates();
    final targets = {
      for (final state in states)
        '${state.animalId}:${state.animal.createdAt.millisecondsSinceEpoch}':
            FeedingNotificationTarget(
              animalId: state.animalId,
              createdAt: state.animal.createdAt,
              dueAt: state.dueAt,
            ),
    };
    final pending = await gateway.pendingIds();
    final knownIds = _deliveries.values.map((item) => item.id).toSet();
    for (final id in pending.difference(knownIds)) {
      await gateway.cancel(id);
    }
    for (final entry in _deliveries.entries.toList()) {
      if (targets[entry.key]?.appointment != entry.value.target.appointment) {
        await gateway.cancel(entry.value.id);
        _deliveries.remove(entry.key);
      }
    }
    final usedIds = _deliveries.values.map((item) => item.id).toSet();
    for (final target in targets.values) {
      final previous = _deliveries[target.identity];
      // Android removes delivered alarms from the pending list. A persisted
      // appointment without a pending alarm has already been consumed; do not
      // notify again after dismissal, restart, language or clock changes.
      if (previous != null && !pending.contains(previous.id)) continue;
      final now = _now().toUtc();
      // Do not restart Android's delivery window for a due alarm on resume.
      // A cold start still renews pending alarms: force stop can remove alarms
      // from AlarmManager while leaving the plugin's persistent cache intact.
      if (previous != null &&
          previous.language == language &&
          (!renew || (preserveDue && !target.dueAt.isAfter(now)))) {
        continue;
      }
      var id = previous?.id ?? 1;
      if (previous == null) {
        while (usedIds.contains(id)) {
          id++;
        }
      }
      final at = target.dueAt.isAfter(now)
          ? target.dueAt.toUtc()
          : now.add(const Duration(seconds: 5));
      await gateway.schedule(
        id: id,
        at: at,
        languageCode: language,
        target: target,
      );
      _deliveries[target.identity] = _Delivery(id, target, language);
      usedIds.add(id);
      try {
        await _save();
      } catch (_) {
        await gateway.cancel(id);
        // Cancellation also removed any previous alarm with this ID. Keep the
        // appointment retryable rather than mistaking it for a delivered alert.
        _deliveries.remove(target.identity);
        rethrow;
      }
    }
    await _save();
  }

  Future<void> openPayload(String? payload) => _enqueue(() async {
    final target = FeedingNotificationTarget.parse(payload);
    if (target != null) {
      final current = await _reminders.getReminderStateForAnimal(
        target.animalId,
      );
      if (!_disposed &&
          current != null &&
          current.animal.createdAt.isAtSameMomentAs(target.createdAt) &&
          current.dueAt.isAtSameMomentAs(target.dueAt)) {
        onOpenAnimal?.call(target.animalId);
        return;
      }
    }
    if (!_disposed) onUnavailableTarget?.call();
  });

  @override
  void dispose() {
    _disposed = true;
    unawaited(_changes?.cancel());
    super.dispose();
  }
}

class _Delivery {
  const _Delivery(this.id, this.target, this.language);
  final int id;
  final FeedingNotificationTarget target;
  final String language;

  Map<String, Object> toJson() => {
    'id': id,
    'target': target.encode(),
    'language': language,
  };

  factory _Delivery.fromJson(Map<String, dynamic> value) {
    final target = FeedingNotificationTarget.parse(value['target'] as String?);
    final id = value['id'] as int;
    if (target == null || id <= 0 || id > 0x7fffffff) {
      throw const FormatException('Invalid notification delivery');
    }
    return _Delivery(id, target, value['language'] as String);
  }
}
