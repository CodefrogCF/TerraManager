import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:terramanager/shared_client/changes/application/shared_change_stream.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';

enum SharedSyncPhase {
  stopped,
  suspended,
  reconciling,
  connecting,
  streaming,
  fallback,
  authRequired,
}

/// One tab's connection policy. Hints only wake authoritative reconciliation.
/// One timer owns connect/liveness deadlines OR fallback polling/retry timing.
class SharedSyncController extends ChangeNotifier {
  SharedSyncController({
    required this.refresh,
    required this.stream,
    required this.onAuthenticationRequired,
    DateTime Function()? now,
    double Function()? random,
    Timer Function(Duration, void Function())? schedule,
    this.pollInterval = const Duration(seconds: 15),
    this.retryBase = const Duration(seconds: 30),
    this.retryMaximum = const Duration(minutes: 2),
    this.connectTimeout = const Duration(seconds: 8),
    this.silenceTimeout = const Duration(seconds: 45),
    this.stablePeriod = const Duration(seconds: 30),
  }) : _now = now ?? _monotonicClock(),
       _random = random ?? Random().nextDouble,
       _schedule = schedule ?? Timer.new {
    stream.addListener(_streamChanged);
    refresh.activity.addListener(_readFinished);
  }
  static DateTime Function() _monotonicClock() {
    final origin = DateTime.now();
    final watch = Stopwatch()..start();
    return () => origin.add(watch.elapsed);
  }

  final SharedRefreshController refresh;
  final SharedChangeStream stream;
  final void Function() onAuthenticationRequired;
  final DateTime Function() _now;
  final double Function() _random;
  final Timer Function(Duration, void Function()) _schedule;
  final Duration pollInterval,
      retryBase,
      retryMaximum,
      connectTimeout,
      silenceTimeout,
      stablePeriod;
  Object? _session;
  bool _foreground = true,
      _backup = false,
      _terminal = false,
      _disposed = false;
  bool _connected = false;
  bool get connected => _connected;
  Object? _error;
  Object? get error => _error;
  SharedSyncPhase _phase = SharedSyncPhase.stopped;
  SharedSyncPhase get phase => _phase;
  Timer? _timer;
  Future<void>? _running;
  int? _runningGeneration;
  int _generation = 0, _failures = 0, _muting = 0;
  int _hintVersion = 0, _activityVersion = 0;
  String? _lastWakeId;
  DateTime? _lastQuery, _retryAt, _connectDeadline, _lastActivity, _openedAt;
  bool _probeAllowed = false;
  bool get _active =>
      !_disposed && _session != null && !_terminal && _foreground && !_backup;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _stopSource({bool clear = false}) {
    _muting++;
    stream.stop(clearReceived: clear);
    _muting--;
    _connectDeadline = _lastActivity = _openedAt = null;
  }

  void setSession(Object? session) {
    if (_disposed || identical(session, _session)) return;
    _generation++;
    _timer?.cancel();
    _session = session;
    _terminal = false;
    _connected = false;
    _error = null;
    _failures = 0;
    _lastQuery = _retryAt = null;
    _lastWakeId = null;
    _probeAllowed = false;
    _stopSource(clear: true);
    refresh.reset(invalidate: session != null);
    refresh.paused = !_active;
    _phase = session == null
        ? SharedSyncPhase.stopped
        : SharedSyncPhase.suspended;
    _notify();
    if (_active) {
      refresh.reconcileClock();
      unawaited(reconcile().catchError((Object _) {}));
    }
  }

  void setEnvironment({required bool foreground, required bool backupBusy}) {
    if (_disposed || (_foreground == foreground && _backup == backupBusy)) {
      return;
    }
    _foreground = foreground;
    _backup = backupBusy;
    _generation++;
    _timer?.cancel();
    _stopSource();
    refresh.paused = !_active;
    _connected = false;
    _phase = _terminal
        ? SharedSyncPhase.authRequired
        : _session == null
        ? SharedSyncPhase.stopped
        : SharedSyncPhase.suspended;
    _notify();
    if (_active) {
      refresh.reconcileClock();
      unawaited(reconcile().catchError((Object _) {}));
    }
  }

  /// Only successful local replacement calls this; failed restore retains state.
  void collectionReplaced() {
    if (_disposed) return;
    _generation++;
    _timer?.cancel();
    _stopSource();
    _connected = false;
    refresh.reset();
    _lastWakeId = null;
    if (_active) unawaited(reconcile().catchError((Object _) {}));
  }

  Future<void> reconcile() {
    if (!_active) return Future.value();
    final running = _running;
    if (running != null) {
      if (_runningGeneration == _generation) {
        // Tell #227 about a hint crossing its currently outstanding reads.
        return refresh.reconcile();
      }
      final generation = _generation;
      return () async {
        try {
          await running;
        } catch (_) {}
        if (_active && generation == _generation) await reconcile();
      }();
    }
    final generation = _generation;
    final completion = Completer<void>();
    _running = completion.future;
    _runningGeneration = generation;
    if (stream.state != SharedStreamState.open &&
        stream.state != SharedStreamState.connecting) {
      _phase = SharedSyncPhase.reconciling;
      _timer?.cancel();
    }
    _lastQuery = _now();
    unawaited(() async {
      try {
        await refresh.reconcile();
        if (_active && generation == _generation) {
          _connected = true;
          _error = null;
          _probeAllowed = true;
        }
        completion.complete();
      } catch (error, stack) {
        if (_active && generation == _generation) {
          _connected = false;
          _error = error;
          if (error is SharedApiException && error.status == 401) {
            _authenticationRequired();
          } else {
            _stopSource();
            _phase = SharedSyncPhase.fallback;
            _probeAllowed = false;
          }
        }
        completion.completeError(error, stack);
      } finally {
        _running = null;
        _runningGeneration = null;
        if (_active && generation == _generation) {
          _notify();
          _drive();
        }
      }
    }());
    return completion.future;
  }

  void _readFinished() {
    if (!_active) return;
    final failure = refresh.lastFailure;
    if (failure != null) {
      _connected = false;
      _error = failure;
      if (failure is SharedApiException && failure.status == 401) {
        _authenticationRequired();
        return;
      }
      // Also catches reads started by visible routes rather than this owner.
      if (stream.state == SharedStreamState.open ||
          stream.state == SharedStreamState.connecting) {
        _streamFailed();
      }
    } else if (refresh.lastReconciled) {
      _connected = true;
      _error = null;
    } else {
      return;
    }
    _notify();
  }

  /// A failed command must stay unconfirmed until authoritative reads recover.
  void reportConnectionFailure(Object error) {
    if (!_active) return;
    _connected = false;
    _error = error;
    if (stream.state == SharedStreamState.open ||
        stream.state == SharedStreamState.connecting) {
      _streamFailed();
    } else {
      _probeAllowed = false;
      _phase = SharedSyncPhase.fallback;
      _notify();
      _drive();
    }
  }

  void _authenticationRequired() {
    if (_terminal || _disposed) return;
    _terminal = true;
    _generation++;
    _timer?.cancel();
    _stopSource(clear: true);
    refresh.paused = true;
    _connected = false;
    _error = const SharedApiException(
      401,
      'unauthorized',
      'Your session expired. Please sign in again.',
    );
    _phase = SharedSyncPhase.authRequired;
    _notify();
    onAuthenticationRequired();
  }

  void _streamChanged() {
    if (_muting != 0 || !_active) return;
    if (stream.state == SharedStreamState.authRequired) {
      _authenticationRequired();
      return;
    }
    if (stream.state == SharedStreamState.failed) {
      _streamFailed();
      return;
    }
    if (stream.state == SharedStreamState.open) {
      final opened = _openedAt == null;
      _openedAt ??= _now();
      if (opened || stream.activityVersion != _activityVersion) {
        _activityVersion = stream.activityVersion;
        _lastActivity = _now();
      }
      _phase = SharedSyncPhase.streaming;
      if (_now().difference(_openedAt!) >= stablePeriod) _failures = 0;
      _reschedule();
      if (opened) unawaited(reconcile().catchError((Object _) {}));
    }
    if (stream.hintVersion != _hintVersion) {
      _hintVersion = stream.hintVersion;
      final cursor = stream.hint?.cursor;
      if (cursor != null &&
          cursor != _lastWakeId &&
          cursor != refresh.appliedCursor) {
        _lastWakeId = cursor;
        unawaited(reconcile().catchError((Object _) {}));
      }
    }
  }

  void _streamFailed() {
    if (!_active) return;
    _stopSource();
    final exponent = min(_failures++, 10);
    final ceiling = min(
      retryMaximum.inMilliseconds,
      retryBase.inMilliseconds * (1 << exponent),
    );
    final delay = (ceiling * (0.75 + 0.25 * _random().clamp(0.0, 1.0))).round();
    _retryAt = _now().add(Duration(milliseconds: delay));
    _probeAllowed =
        false; // A successful authoritative query must precede another probe.
    _phase = SharedSyncPhase.fallback;
    _notify();
    _drive();
  }

  void _connect() {
    if (!_active || !stream.source.supported || !_probeAllowed) return;
    _timer?.cancel(); // No fallback polling schedule survives an SSE probe.
    _probeAllowed = false;
    _phase = SharedSyncPhase.connecting;
    _connectDeadline = _now().add(connectTimeout);
    _lastActivity = _openedAt = null;
    _notify();
    stream.start();
    _reschedule();
  }

  void _drive() {
    if (!_active) return;
    if (stream.state == SharedStreamState.open ||
        stream.state == SharedStreamState.connecting) {
      _reschedule();
      return;
    }
    if (_running != null) return;
    if (stream.source.supported &&
        _probeAllowed &&
        (_retryAt == null || !_retryAt!.isAfter(_now()))) {
      _connect();
      return;
    }
    _phase = SharedSyncPhase.fallback;
    _reschedule();
  }

  void _reschedule() {
    _timer?.cancel();
    if (!_active) return;
    DateTime? deadline;
    if (stream.state == SharedStreamState.connecting) {
      deadline = _connectDeadline;
    } else if (stream.state == SharedStreamState.open) {
      deadline = (_lastActivity ?? _now()).add(silenceTimeout);
    } else if (_running == null) {
      deadline = (_lastQuery ?? _now()).add(pollInterval);
      if (stream.source.supported &&
          _probeAllowed &&
          _retryAt != null &&
          _retryAt!.isBefore(deadline)) {
        deadline = _retryAt;
      }
    }
    if (deadline == null) return;
    final difference = deadline.difference(_now());
    _timer = _schedule(difference.isNegative ? Duration.zero : difference, () {
      if (!_active) return;
      if (stream.state == SharedStreamState.open ||
          stream.state == SharedStreamState.connecting) {
        _streamFailed();
      } else if (_lastQuery == null ||
          !_lastQuery!.add(pollInterval).isAfter(_now())) {
        unawaited(reconcile().catchError((Object _) {}));
      } else {
        _drive();
      }
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _timer?.cancel();
    stream.removeListener(_streamChanged);
    refresh.activity.removeListener(_readFinished);
    _stopSource(clear: true);
    refresh.paused = true;
    super.dispose();
  }
}
