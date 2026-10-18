import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:terramanager/shared_client/changes/infrastructure/api/shared_changes_api.dart';

/// Invalidation hints contain owner IDs, never patches or replacement records.
class SharedInvalidation {
  SharedInvalidation([
    Map<String, Iterable<int>?> resources = const {},
    this.reset = false,
  ]) : resources = _bounded(resources);
  static Map<String, Set<int>?> _bounded(
    Map<String, Iterable<int>?> resources,
  ) => {
    for (final e in resources.entries)
      if (e.value == null || e.value!.isNotEmpty)
        e.key: e.value == null ? null : _boundedIds(e.value!),
  };
  static Set<int>? _boundedIds(Iterable<int> ids) {
    final values = <int>{};
    for (final id in ids) {
      values.add(id);
      if (values.length > 128) return null;
    }
    return values;
  }

  final Map<String, Set<int>?> resources;
  final bool reset;
  bool get isEmpty => !reset && resources.isEmpty;
  bool affects(String kind, [int? id]) =>
      reset ||
      resources.containsKey('collection') ||
      (resources.containsKey(kind) &&
          (id == null ||
              resources[kind] == null ||
              resources[kind]!.contains(id)));
  SharedInvalidation merge(SharedInvalidation other) => reset || other.reset
      ? SharedInvalidation({}, true)
      : SharedInvalidation({
          for (final key in {...resources.keys, ...other.resources.keys})
            key:
                (resources.containsKey(key) && resources[key] == null) ||
                    (other.resources.containsKey(key) &&
                        other.resources[key] == null)
                ? null
                : {...?resources[key], ...?other.resources[key]},
        }, reset || other.reset);
  SharedInvalidation matching(Map<String, Set<int>?> dependencies) =>
      SharedInvalidation({
        for (final e in resources.entries)
          if (e.key == 'collection' ||
              (dependencies.containsKey(e.key) &&
                  (e.value == null ||
                      dependencies[e.key] == null ||
                      e.value!.intersection(dependencies[e.key]!).isNotEmpty)))
            e.key: e.value,
      }, reset);
  factory SharedInvalidation.fromQuery(SharedChangeQuery query) {
    final body = query.body;
    if (body == null) return SharedInvalidation();
    var result = SharedInvalidation({}, body['reset'] == true);
    for (final change in body['changes'] as List) {
      if (change is! Map || change['resources'] is! Map) {
        throw const FormatException('Invalid change hints');
      }
      final raw = change['resources'] as Map;
      final resources = <String, Iterable<int>?>{};
      for (final e in raw.entries) {
        if (e.key is! String ||
            (e.value != null &&
                (e.value is! List ||
                    (e.value as List).any((id) => id is! int)))) {
          throw const FormatException('Invalid resource IDs');
        }
        if (e.value == null || (e.value as List).isNotEmpty) {
          resources[e.key as String] = (e.value as List?)?.cast<int>();
        }
      }
      result = result.merge(SharedInvalidation(resources));
    }
    if (body['preferencesChanged'] == true) {
      result = result.merge(SharedInvalidation({'preferences': null}));
    }
    return result;
  }
}

/// One transient controller per API/session. Scheduling and the SSE
/// transport call reconcile(); neither can acknowledge a cursor themselves.
class SharedRefreshController {
  SharedRefreshController({
    required this.queryChanges,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final Future<SharedChangeQuery> Function({String? since}) queryChanges;
  final _subscriptions = <SharedRefreshSubscription>[];
  final _demands = <SharedRefreshDemand>[];
  late final clock = ValueNotifier<DateTime>(_now());
  final _dueTimes = <Object, List<DateTime>>{};
  String? _appliedCursor;
  String? _dispatchedCursor;
  String? get appliedCursor => _appliedCursor;
  int _mediaGeneration = 0;
  int get mediaGeneration => _mediaGeneration;
  Future<void>? _running;
  bool _requested = false;
  bool _disposed = false;
  bool _paused = false;
  bool get paused => _paused;
  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (value) {
      _generation++;
      _dueTimer?.cancel();
    } else {
      reconcileClock();
    }
  }

  int get generation => _generation;
  int _scope = 0;
  int? _runningGeneration;
  final activity = ValueNotifier<int>(0);
  Object? lastFailure;
  bool lastReconciled = false;
  int get scope => _scope;
  int _generation = 0;
  Timer? _dueTimer;

  SharedRefreshSubscription watch({
    required Map<String, Set<int>?> Function() dependencies,
    required bool Function() isVisible,
    required Future<void> Function(SharedInvalidation) refresh,
    Future<void>? initialLoad,
  }) {
    final subscription = SharedRefreshSubscription._(
      this,
      dependencies,
      isVisible,
      refresh,
      initialLoad,
    );
    _subscriptions.add(subscription);
    return subscription;
  }

  SharedRefreshDemand observe(Set<String> kinds, bool Function() isVisible) {
    final demand = SharedRefreshDemand._(this, kinds, isVisible);
    _demands.add(demand);
    return demand;
  }

  bool hasVisibleDemand(String kind) =>
      _demands.any((d) => d.kinds.contains(kind) && d.isVisible());

  /// Invalidate without acknowledging any advertised cursor (also for #228).
  void invalidate(SharedInvalidation change) {
    if (_disposed) return;
    for (final subscription in _subscriptions.toList()) {
      final matching = change.matching(subscription.dependencies());
      subscription._dirty = subscription._dirty.merge(matching);
    }
  }

  /// Called on route return without waiting for the next network interval.
  Future<void> refreshVisible() async {
    if (_disposed || paused) return;
    // Serialize with reconciliation so a read never races another read.
    if (_running != null) {
      _requested = true;
      return _joinCurrent(query: false);
    }
    return _start(query: false);
  }

  Future<void> reconcile() {
    if (_disposed || paused) return Future.value();
    _requested = true;
    return _running == null ? _start(query: true) : _joinCurrent(query: true);
  }

  Future<void> _joinCurrent({required bool query}) {
    final running = _running!;
    if (_runningGeneration == _generation) return running;
    final generation = _generation;
    return () async {
      try {
        await running;
      } catch (_) {
        /* Previous session/pause owns its failure. */
      }
      if (_disposed || paused || generation != _generation) return;
      await (query ? reconcile() : refreshVisible());
    }();
  }

  Future<void> _start({required bool query}) {
    final completion = Completer<void>();
    _running = completion.future;
    final generation = _generation;
    final scope = _scope;
    _runningGeneration = generation;
    unawaited(() async {
      var queried = false;
      try {
        var check = query;
        do {
          _requested = false;
          if (_disposed || paused || generation != _generation) break;
          SharedChangeQuery? response;
          if (check) {
            response = await queryChanges(since: _appliedCursor);
            if (_disposed || paused || generation != _generation) break;
            queried = true;
            if (response.cursor != _dispatchedCursor) {
              final change = SharedInvalidation.fromQuery(response);
              if (change.reset) _mediaGeneration++;
              invalidate(change);
              _dispatchedCursor = response.cursor;
            }
          }
          var reads = false;
          // New bindings or hints added during a read are included on the next
          // pass. A failed binding retains its dirty hints and the old cursor.
          do {
            var batchRead = false;
            for (final s in _subscriptions.toList()) {
              if (s._disposed || !s.isVisible() || s._dirty.isEmpty) continue;
              final dirty = s._dirty;
              s._dirty = SharedInvalidation();
              try {
                final initialLoad = s._initialLoad;
                s._initialLoad = null;
                await initialLoad;
                if (s._disposed) continue;
                if (_disposed || paused || generation != _generation) {
                  if (scope == _scope) s._dirty = dirty.merge(s._dirty);
                  break;
                }
                await s.refresh(dirty);
                if (_disposed || paused || generation != _generation) {
                  if (scope == _scope) s._dirty = dirty.merge(s._dirty);
                  break;
                }
              } catch (_) {
                if (scope == _scope) s._dirty = dirty.merge(s._dirty);
                rethrow;
              }
              batchRead = true;
            }
            reads |= batchRead;
            if (!batchRead ||
                _disposed ||
                paused ||
                generation != _generation) {
              break;
            }
          } while (_subscriptions.any(
            (s) => !s._disposed && s.isVisible() && !s._dirty.isEmpty,
          ));
          if (_disposed || paused || generation != _generation) break;
          if (response != null) _appliedCursor = response.cursor;
          // Reads may have crossed a commit. Query again from the cursor whose
          // required reads succeeded, even if no second notification arrived.
          check = reads || _requested;
        } while (check);
        if (!_disposed && !paused && generation == _generation) {
          lastFailure = null;
          lastReconciled = queried;
          activity.value++;
        }
        completion.complete();
      } catch (e, st) {
        if (!_disposed && !paused && generation == _generation) {
          lastFailure = e;
          lastReconciled = false;
          activity.value++;
        }
        completion.completeError(e, st);
      } finally {
        _running = null;
        _runningGeneration = null;
      }
    }());
    return completion.future;
  }

  /// Lifecycle adapters call this before reconciling after foregrounding.
  void reconcileClock() {
    if (_disposed) return;
    clock.value = _now();
    _scheduleDueTimer();
  }

  /// Keep the due state current without a collection GET or database write.
  void scheduleDueTimes(
    Iterable<DateTime> dueTimes, {
    Object owner = 'overview',
  }) {
    if (_disposed) return;
    _dueTimes[owner] = dueTimes.toList();
    _scheduleDueTimer();
  }

  void clearDueTimes(Object owner) {
    _dueTimes.remove(owner);
    _scheduleDueTimer();
  }

  void _scheduleDueTimer() {
    _dueTimer?.cancel();
    final now = _now();
    final future =
        _dueTimes.values.expand((v) => v).where((d) => d.isAfter(now)).toList()
          ..sort();
    if (_disposed || paused || future.isEmpty) return;
    _dueTimer = Timer(future.first.difference(now), () {
      if (_disposed) return;
      clock.value = _now();
      _scheduleDueTimer();
    });
  }

  void reset({bool invalidate = true}) {
    _generation++;
    _scope++;
    lastFailure = null;
    _mediaGeneration++;
    _appliedCursor = _dispatchedCursor = null;
    _dueTimer?.cancel();
    _dueTimes.clear();
    for (final s in _subscriptions) {
      s._dirty = SharedInvalidation({}, invalidate);
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _dueTimer?.cancel();
    _subscriptions.clear();
    _demands.clear();
    clock.dispose();
    activity.dispose();
  }
}

class SharedRefreshSubscription {
  SharedRefreshSubscription._(
    this._owner,
    this.dependencies,
    this.isVisible,
    this.refresh,
    this._initialLoad,
  );
  final SharedRefreshController _owner;
  final Map<String, Set<int>?> Function() dependencies;
  final bool Function() isVisible;
  final Future<void> Function(SharedInvalidation) refresh;
  Future<void>? _initialLoad;
  SharedInvalidation _dirty = SharedInvalidation();
  bool _disposed = false;
  void markStale() {
    if (!_disposed) _dirty = SharedInvalidation({}, true);
  }

  void dispose() {
    _disposed = true;
    _owner._subscriptions.remove(this);
  }
}

class SharedRefreshDemand {
  SharedRefreshDemand._(this._owner, this.kinds, this.isVisible);
  final SharedRefreshController _owner;
  final Set<String> kinds;
  final bool Function() isVisible;
  void dispose() => _owner._demands.remove(this);
}
