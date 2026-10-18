import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_client/changes/application/shared_change_stream.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/changes/application/shared_sync_controller.dart';
import 'package:terramanager/shared_client/changes/domain/shared_event_source_port.dart';
import 'package:terramanager/shared_client/changes/infrastructure/api/shared_changes_api.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';

Future<void> flush() async {
  for (var i = 0; i < 60; i++) {
    await Future<void>.value();
  }
}

class _Alarm implements Timer {
  _Alarm(this.at, this.callback);
  final DateTime at;
  final void Function() callback;
  bool _active = true;
  @override
  bool get isActive => _active;
  @override
  int get tick => _active ? 0 : 1;
  @override
  void cancel() => _active = false;
  void fire() {
    if (_active) {
      _active = false;
      callback();
    }
  }
}

class _Time {
  DateTime now = DateTime.utc(2026, 10, 18);
  final alarms = <_Alarm>[];
  Timer schedule(Duration delay, void Function() callback) {
    final alarm = _Alarm(now.add(delay), callback);
    alarms.add(alarm);
    return alarm;
  }

  int get pending => alarms.where((a) => a.isActive).length;
  Future<void> elapse(Duration duration) async {
    final end = now.add(duration);
    for (var i = 0; i < 2000; i++) {
      await flush();
      final active =
          alarms.where((a) => a.isActive && !a.at.isAfter(end)).toList()
            ..sort((a, b) => a.at.compareTo(b.at));
      if (active.isEmpty) {
        now = end;
        await flush();
        return;
      }
      now = active.first.at;
      active.first.fire();
    }
    fail('Timer loop failed to make progress');
  }
}

class _Source implements SharedEventSourcePort {
  _Source({this.supported = true});
  @override
  final bool supported;
  int opens = 0, active = 0;
  late void Function() onOpen, onError;
  late void Function(String, String, String) onMessage;
  @override
  void open(
    Uri url, {
    required void Function() onOpen,
    required void Function(String, String, String) onMessage,
    required void Function() onError,
  }) {
    expect(active, 0);
    opens++;
    active = 1;
    this.onOpen = onOpen;
    this.onMessage = onMessage;
    this.onError = onError;
  }

  @override
  void close() {
    active = 0;
  }

  void opened() => onOpen();
  void error() => onError();
  void beat() => onMessage('keepalive', '{}', '');
  void hint(Map<String, dynamic> body) =>
      onMessage('changes', jsonEncode(body), body['cursor'] as String);
}

class _Backend {
  String epoch = 'epoch';
  int revision = 0, queries = 0, reads = 0, activeReads = 0, maxReads = 0;
  Object? failure;
  bool forceReset = false;
  final since = <String?>[];
  Completer<void>? readGate, queryGate;
  String value = 'initial', appliedValue = '';
  String get cursor => '$epoch:$revision:account:caregiver:0';
  Map<String, dynamic> body() => {
    'cursor': cursor,
    'epoch': epoch,
    'revision': revision,
    'preferencesRevision': 0,
    'reset': forceReset,
    'preferencesChanged': false,
    'changes': [
      {
        'resources': {
          'animals': [1],
          'animalPictures': [1],
        },
      },
    ],
  };
  Future<SharedChangeQuery> query({String? since}) async {
    queries++;
    this.since.add(since);
    final gate = queryGate;
    queryGate = null;
    final result = body()
      ..['reset'] = forceReset || since == null || !since.startsWith('$epoch:');
    if (gate != null) await gate.future;
    if (failure != null) throw failure!;
    return since == result['cursor'] && !forceReset
        ? SharedChangeQuery(cursor: since!)
        : SharedChangeQuery(cursor: result['cursor'] as String, body: result);
  }

  Future<void> read(SharedRefreshController refresh) async {
    reads++;
    maxReads = maxReads < ++activeReads ? activeReads : maxReads;
    final generation = refresh.generation;
    final result = value;
    final gate = readGate;
    readGate = null;
    try {
      if (gate != null) await gate.future;
      if (generation == refresh.generation) appliedValue = result;
    } finally {
      activeReads--;
    }
  }

  void change(String value) {
    revision++;
    this.value = value;
  }
}

class _Harness {
  _Harness({bool supported = true, double jitter = 0}) {
    source = _Source(supported: supported);
    refresh = SharedRefreshController(
      queryChanges: backend.query,
      now: () => time.now,
    );
    stream = SharedChangeStream(
      Uri.parse('https://localhost/api/v1/changes/events'),
      source,
    );
    sync = SharedSyncController(
      refresh: refresh,
      stream: stream,
      onAuthenticationRequired: () => expired++,
      now: () => time.now,
      random: () => jitter,
      schedule: time.schedule,
    );
    refresh.watch(
      dependencies: () => {'animals': null, 'animalPictures': null},
      isVisible: () => true,
      refresh: (_) => backend.read(refresh),
    );
  }
  final time = _Time();
  final backend = _Backend();
  late final _Source source;
  late final SharedRefreshController refresh;
  late final SharedChangeStream stream;
  late final SharedSyncController sync;
  int expired = 0;
  Future<void> start() async {
    sync.setSession(Object());
    await flush();
  }

  Future<void> open() async {
    source.opened();
    await flush();
  }

  void dispose() {
    sync.dispose();
    stream.dispose();
    refresh.dispose();
  }
}

void main() {
  test('initial snapshot and writes crossing an outstanding read converge without overlapping reads', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final gate = Completer<void>();
    h.backend.readGate = gate;
    await h.start();
    expect(h.refresh.appliedCursor, isNull);
    h.backend.change('during initial read');
    gate.complete();
    await flush();
    expect(h.backend.appliedValue, 'during initial read');
    expect(h.backend.reads, 2);
    expect(h.refresh.appliedCursor, h.backend.cursor);
    expect(h.backend.maxReads, 1);
    expect(h.source.active, 1);
    expect(h.time.pending, 1);
  });
  test(
    'connection setup reconciles from applied state even before the first hint',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.start();
      final applied = h.refresh.appliedCursor;
      h.backend.change('during connection');
      await h.open();
      expect(h.backend.since, contains(applied));
      expect(h.backend.appliedValue, 'during connection');
      expect(h.stream.lastReceivedId, isNull);
      expect(h.refresh.appliedCursor, h.backend.cursor);
    },
  );
  test(
    'duplicate and out-of-order received IDs never acknowledge or regress data',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.start();
      await h.open();
      final old = h.backend.body();
      h.backend.change('new');
      final next = h.backend.body();
      h.source.hint(next);
      await flush();
      final reads = h.backend.reads, queries = h.backend.queries;
      for (var i = 0; i < 50; i++) {
        h.source.hint(next);
      }
      await flush();
      expect(h.backend.queries, queries);
      h.source.hint(old);
      await flush();
      expect(h.refresh.appliedCursor, next['cursor']);
      expect(h.backend.reads, reads);
      expect(h.stream.lastReceivedId, old['cursor']);
    },
  );
  test('epoch and history reset clear media identity while keeping authoritative cursor ownership', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.open();
    final generation = h.refresh.mediaGeneration;
    h.backend.epoch = 'restored';
    h.backend.change('reused media id');
    h.source.hint(h.backend.body());
    await flush();
    expect(h.refresh.mediaGeneration, greaterThan(generation));
    expect(h.backend.appliedValue, 'reused media id');
    final resetGeneration = h.refresh.mediaGeneration;
    h.backend.change('history gap');
    h.backend.forceReset = true;
    h.source.hint(h.backend.body());
    await flush();
    expect(h.refresh.mediaGeneration, greaterThan(resetGeneration));
  });
  test(
    'unchanged unsupported fallback has four queries per minute and one timer',
    () async {
      final h = _Harness(supported: false);
      addTearDown(h.dispose);
      await h.start();
      final queries = h.backend.queries, reads = h.backend.reads;
      await h.time.elapse(const Duration(seconds: 60));
      expect(h.backend.queries - queries, 4);
      expect(h.backend.reads, reads);
      expect(h.source.opens, 0);
      expect(h.time.pending, 1);
    },
  );
  test(
    'offline fallback stays bounded and does not overlap requests',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.start();
      await h.open();
      await h.time.elapse(const Duration(seconds: 16));
      h.backend.failure = const SharedConnectionException();
      h.source.error();
      await flush();
      await h.time.elapse(Duration.zero);
      expect(h.sync.connected, false);
      final queries = h.backend.queries;
      await h.time.elapse(const Duration(seconds: 60));
      expect(h.backend.queries - queries, 4);
      expect(h.source.opens, 1);
      expect(h.source.active, 0);
      expect(h.time.pending, 1);
    },
  );
  test('fallback queries permit jittered exponential SSE probes without duplicate schedules', () async {
    final h = _Harness(jitter: 0);
    addTearDown(h.dispose);
    await h.start();
    await h.open();
    h.source.error();
    await flush();
    await h.time.elapse(const Duration(seconds: 15));
    expect(h.source.opens, 1);
    await h.time.elapse(const Duration(milliseconds: 7500));
    expect(h.source.opens, 2);
    expect(h.source.active, 1);
    expect(h.time.pending, 1);
    h.source.error();
    await flush();
    await h.time.elapse(const Duration(seconds: 44));
    expect(h.source.opens, 2);
    await h.time.elapse(const Duration(seconds: 1));
    expect(h.source.opens, 3);
  });
  test(
    'flapping connections reach a capped backoff and stable activity resets it',
    () async {
      final h = _Harness(jitter: 1);
      addTearDown(h.dispose);
      await h.start();
      await h.open();
      for (var failure = 0; failure < 6; failure++) {
        final opens = h.source.opens;
        h.source.error();
        await flush();
        final before = h.time.now;
        for (
          var second = 0;
          second < 121 && h.source.opens == opens;
          second++
        ) {
          await h.time.elapse(const Duration(seconds: 1));
        }
        final delay = h.time.now.difference(before).inSeconds;
        expect(delay, [30, 60, 120, 120, 120, 120][failure]);
        await h.open();
      }
      for (var i = 0; i < 3; i++) {
        await h.time.elapse(const Duration(seconds: 15));
        h.source.beat();
        await flush();
      }
      final opens = h.source.opens;
      h.source.error();
      await flush();
      await h.time.elapse(const Duration(seconds: 29));
      expect(h.source.opens, opens);
      await h.time.elapse(const Duration(seconds: 1));
      expect(h.source.opens, opens + 1);
    },
  );
  test(
    'no-op route refresh cannot heal a failed command or enable writes',
    () async {
      final h = _Harness(supported: false);
      addTearDown(h.dispose);
      await h.start();
      h.sync.reportConnectionFailure(const SharedConnectionException());
      await h.refresh.refreshVisible();
      await flush();
      expect(h.sync.connected, false);
      expect(h.sync.error, isA<SharedConnectionException>());
      await h.time.elapse(const Duration(seconds: 15));
      expect(h.sync.connected, true);
    },
  );
  test('slow fallback queries have no overlapping request or pending polling timer', () async {
    final h = _Harness(supported: false);
    addTearDown(h.dispose);
    await h.start();
    final gate = Completer<void>();
    h.backend.queryGate = gate;
    final before = h.backend.queries;
    await h.time.elapse(const Duration(seconds: 15));
    await h.time.elapse(const Duration(seconds: 40));
    expect(h.backend.queries, before + 1);
    expect(h.time.pending, 0);
    gate.complete();
    await flush();
    expect(h.time.pending, 1);
  });
  test(
    'stuck connection setup and silent open connections release their source',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.start();
      await h.time.elapse(const Duration(seconds: 8));
      expect(h.source.active, 0);
      await h.time.elapse(const Duration(seconds: 23));
      expect(h.source.opens, 2);
      await h.open();
      final queries = h.backend.queries;
      await h.time.elapse(const Duration(seconds: 45));
      expect(h.source.active, 0);
      expect(h.backend.queries, greaterThanOrEqualTo(queries));
      expect(h.time.pending, 1);
    },
  );
  test('keepalive activity keeps SSE open for ten minutes without idle data queries', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.open();
    final queries = h.backend.queries;
    for (var i = 0; i < 40; i++) {
      await h.time.elapse(const Duration(seconds: 15));
      h.source.beat();
      await flush();
    }
    expect(h.source.opens, 1);
    expect(h.backend.queries, queries);
    expect(h.time.pending, 1);
  });
  test('hidden and backup pauses cancel work; foreground reconciles clock and data', () async {
    final h = _Harness(supported: false);
    addTearDown(h.dispose);
    await h.start();
    final queries = h.backend.queries;
    h.sync.setEnvironment(foreground: false, backupBusy: false);
    expect(h.time.pending, 0);
    h.backend.change('background');
    await h.time.elapse(const Duration(minutes: 5));
    expect(h.backend.queries, queries);
    h.sync.setEnvironment(foreground: true, backupBusy: false);
    await flush();
    expect(h.backend.appliedValue, 'background');
    expect(h.refresh.clock.value, h.time.now);
    h.sync.setEnvironment(foreground: true, backupBusy: true);
    expect(h.time.pending, 0);
  });
  test('late reads across pause resume retain dirty state and cannot apply old values', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.open();
    h.backend.change('stale pending');
    final gate = Completer<void>();
    h.backend.readGate = gate;
    h.source.hint(h.backend.body());
    await flush();
    h.sync.setEnvironment(foreground: false, backupBusy: false);
    h.backend.change('current after resume');
    h.sync.setEnvironment(foreground: true, backupBusy: false);
    gate.complete();
    await flush();
    expect(h.backend.appliedValue, 'current after resume');
    expect(h.backend.maxReads, 1);
    expect(h.refresh.appliedCursor, h.backend.cursor);
  });
  test('logout login while a read is pending isolates the next session and drains old work', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.open();
    h.backend.change('old account');
    final gate = Completer<void>();
    h.backend.readGate = gate;
    h.source.hint(h.backend.body());
    await flush();
    h.sync.setSession(null);
    h.backend.epoch = 'new-account';
    h.backend.change('new account');
    h.sync.setSession(Object());
    gate.complete();
    await flush();
    expect(h.backend.appliedValue, 'new account');
    expect(h.backend.maxReads, 1);
    expect(h.refresh.appliedCursor, h.backend.cursor);
    expect(h.time.pending, 1);
  });
  test(
    'terminal auth event stops all retry and polling until a different login',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.start();
      await h.open();
      h.source.onMessage('auth-required', '{}', '');
      await flush();
      final queries = h.backend.queries, opens = h.source.opens;
      await h.time.elapse(const Duration(minutes: 20));
      h.sync.setEnvironment(foreground: false, backupBusy: false);
      h.sync.setEnvironment(foreground: true, backupBusy: false);
      await flush();
      expect(h.expired, 1);
      expect(h.backend.queries, queries);
      expect(h.source.opens, opens);
      expect(h.time.pending, 0);
      expect(h.sync.phase, SharedSyncPhase.authRequired);
    },
  );
  test('initial unauthorized SSE is checked by HTTP once before any further attempt', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    h.source.error();
    h.backend.failure = const SharedApiException(
      401,
      'unauthorized',
      'Expired',
    );
    await h.time.elapse(const Duration(minutes: 10));
    expect(h.expired, 1);
    expect(h.source.opens, 1);
    expect(h.time.pending, 0);
  });
  test('failed restore retains epoch and success reloads reused IDs after backup releases', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.open();
    final generation = h.refresh.mediaGeneration;
    h.sync.setEnvironment(foreground: true, backupBusy: true);
    h.sync.setEnvironment(foreground: true, backupBusy: false);
    await flush();
    expect(h.refresh.mediaGeneration, generation);
    h.sync.setEnvironment(foreground: true, backupBusy: true);
    h.backend.epoch = 'replacement';
    h.backend.change('same id new contents');
    h.sync.collectionReplaced();
    final queries = h.backend.queries;
    await h.time.elapse(const Duration(seconds: 20));
    expect(h.backend.queries, queries);
    h.sync.setEnvironment(foreground: true, backupBusy: false);
    await flush();
    expect(h.backend.appliedValue, 'same id new contents');
    expect(h.refresh.mediaGeneration, greaterThan(generation));
  });
  test(
    'tabs with one account own independent jitter and converge independently',
    () async {
      final a = _Harness(jitter: 0), b = _Harness(jitter: 1);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.start();
      await b.start();
      await a.open();
      await b.open();
      a.source.error();
      b.source.error();
      await flush();
      await a.time.elapse(const Duration(seconds: 24));
      await b.time.elapse(const Duration(seconds: 24));
      expect(a.source.opens, 2);
      expect(b.source.opens, 1);
      a.backend.change('shared update');
      b.backend.change('shared update');
      await a.open();
      await b.time.elapse(const Duration(seconds: 6));
      await b.open();
      expect(a.backend.appliedValue, 'shared update');
      expect(b.backend.appliedValue, 'shared update');
      expect(a.time.pending, 1);
      expect(b.time.pending, 1);
    },
  );
}
