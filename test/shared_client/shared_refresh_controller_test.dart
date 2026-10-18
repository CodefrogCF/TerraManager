import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/changes/infrastructure/api/shared_changes_api.dart';

SharedChangeQuery changed(
  String cursor,
  Map<String, Object?> resources, {
  bool reset = false,
}) => SharedChangeQuery(
  cursor: cursor,
  body: {
    'reset': reset,
    'preferencesChanged': false,
    'changes': [
      {'resources': resources},
    ],
  },
);
void main() {
  test('dependencies use Animal owners, both Box assignments and conservative reset', () {
    final hints = SharedInvalidation({
      'animals': [7],
      'boxes': [1, 2],
      'feedingHistories': [7],
    });
    expect(hints.affects('boxes', 1), isTrue);
    expect(hints.affects('boxes', 2), isTrue);
    expect(hints.affects('animals', 8), isFalse);
    expect(hints.affects('animalPictures', 7), isFalse);
    expect(
      hints.matching({
        'animals': {8},
      }).isEmpty,
      isTrue,
    );
    expect(
      SharedInvalidation({'collection': null}).affects('animalPictures', 20),
      isTrue,
    );
    expect(SharedInvalidation({}, true).affects('weightHistories', 7), isTrue);
  });
  test(
    'hidden invalidation IDs stay bounded and empty hints have no effect',
    () {
      var hints = SharedInvalidation();
      for (var id = 0; id < 200; id++) {
        hints = hints.merge(
          SharedInvalidation({
            'animals': [id],
          }),
        );
      }
      expect(hints.resources['animals'], isNull);
      expect(SharedInvalidation({'animals': <int>[]}).isEmpty, isTrue);
      final duplicatePrefix = SharedInvalidation({
        'animals': [...List.filled(150, 0), ...List.generate(150, (i) => i)],
      });
      expect(duplicatePrefix.resources['animals'], isNull);
    },
  );
  test(
    'empty ID hints and unchanged revisions do not load or replace data',
    () async {
      var reads = 0;
      var queries = 0;
      final controller = SharedRefreshController(
        queryChanges: ({since}) async {
          queries++;
          return queries == 1
              ? changed('one', {'animals': <int>[]})
              : const SharedChangeQuery(cursor: 'one');
        },
      );
      addTearDown(controller.dispose);
      controller.watch(
        dependencies: () => {'animals': null},
        isVisible: () => true,
        refresh: (_) async {
          reads++;
        },
      );
      await controller.reconcile();
      await controller.reconcile();
      expect(controller.appliedCursor, 'one');
      expect(reads, 0);
    },
  );
  test(
    'bursts coalesce, hidden resources stay dirty, Feeding retains galleries',
    () async {
      var response = changed('zero', {});
      final controller = SharedRefreshController(
        queryChanges: ({since}) async => since == response.cursor
            ? SharedChangeQuery(cursor: since!)
            : response,
      );
      addTearDown(controller.dispose);
      var visible = false;
      var histories = 0;
      var galleries = 0;
      controller.watch(
        dependencies: () => {
          'feedingHistories': {7},
        },
        isVisible: () => visible,
        refresh: (_) async {
          histories++;
        },
      );
      controller.watch(
        dependencies: () => {
          'animalPictures': {7},
        },
        isVisible: () => true,
        refresh: (_) async {
          galleries++;
        },
      );
      await controller.reconcile();
      response = changed('one', {
        'feedingHistories': [7],
      });
      await controller.reconcile();
      response = changed('two', {
        'feedingHistories': [7],
      });
      await controller.reconcile();
      expect(histories, 0);
      expect(controller.appliedCursor, 'two');
      visible = true;
      await controller.refreshVisible();
      expect(histories, 1);
      expect(galleries, 0);
    },
  );
  test(
    'cursor waits for required reads and failures retry without overlap',
    () async {
      var fail = true;
      var calls = 0;
      final controller = SharedRefreshController(
        queryChanges: ({since}) async => since == 'one'
            ? const SharedChangeQuery(cursor: 'one')
            : changed('one', {
                'animals': [7],
              }),
      );
      addTearDown(controller.dispose);
      controller.watch(
        dependencies: () => {
          'animals': {7},
        },
        isVisible: () => true,
        refresh: (_) async {
          calls++;
          if (fail) throw StateError('read failed');
        },
      );
      await expectLater(controller.reconcile(), throwsStateError);
      expect(controller.appliedCursor, isNull);
      fail = false;
      await controller.reconcile();
      expect(controller.appliedCursor, 'one');
      expect(calls, 2);
    },
  );
  test(
    'commit during initial or outstanding read is reconciled before settling',
    () async {
      var cursor = 'one';
      final gate = Completer<void>();
      var reads = 0;
      final controller = SharedRefreshController(
        queryChanges: ({since}) async => since == cursor
            ? SharedChangeQuery(cursor: cursor)
            : changed(cursor, {
                'feedingHistories': [7],
              }),
      );
      addTearDown(controller.dispose);
      controller.watch(
        dependencies: () => {
          'feedingHistories': {7},
        },
        isVisible: () => true,
        refresh: (_) async {
          reads++;
          if (reads == 1) await gate.future;
        },
      );
      final first = controller.reconcile();
      await Future<void>.delayed(Duration.zero);
      expect(controller.appliedCursor, isNull);
      cursor = 'two'; // Another device, even with the same signed-in account.
      final second = controller.reconcile();
      expect(identical(first, second), isTrue);
      gate.complete();
      await first;
      expect(controller.appliedCursor, 'two');
      expect(reads, 2);
    },
  );
  test('invalidations during a refresh are retained and serialized', () async {
    final gate = Completer<void>();
    var reads = 0;
    var active = 0;
    final controller = SharedRefreshController(
      queryChanges: ({since}) async => const SharedChangeQuery(cursor: 'one'),
    );
    addTearDown(controller.dispose);
    controller.watch(
      dependencies: () => {
        'animals': {7},
      },
      isVisible: () => true,
      refresh: (_) async {
        expect(active++, 0);
        reads++;
        if (reads == 1) await gate.future;
        active--;
      },
    );
    controller.invalidate(
      SharedInvalidation({
        'animals': [7],
      }),
    );
    final pending = controller.refreshVisible();
    await Future<void>.delayed(Duration.zero);
    controller.invalidate(
      SharedInvalidation({
        'animals': [7],
      }),
    );
    gate.complete();
    await pending;
    expect(reads, 2);
  });
  test(
    'reset during a pending read cannot acknowledge the previous session',
    () async {
      final gate = Completer<void>();
      final controller = SharedRefreshController(
        queryChanges: ({since}) async => changed('old', {
          'animals': [1],
        }),
      );
      addTearDown(controller.dispose);
      controller.watch(
        dependencies: () => {'animals': null},
        isVisible: () => true,
        refresh: (_) => gate.future,
      );
      final pending = controller.reconcile();
      await Future<void>.delayed(Duration.zero);
      controller.reset();
      gate.complete();
      await pending;
      expect(controller.appliedCursor, isNull);
    },
  );
  test('malformed hints fail without advancing a cursor', () async {
    final controller = SharedRefreshController(
      queryChanges: ({since}) async => changed('bad', {
        'animals': ['wrong'],
      }),
    );
    addTearDown(controller.dispose);
    await expectLater(controller.reconcile(), throwsFormatException);
    expect(controller.appliedCursor, isNull);
  });
  testWidgets(
    'due clock fires at its deadline without querying collection data',
    (tester) async {
      var now = DateTime.utc(2026, 10, 18);
      var queries = 0;
      var ticks = 0;
      final controller = SharedRefreshController(
        now: () => now,
        queryChanges: ({since}) async {
          queries++;
          return const SharedChangeQuery(cursor: 'one');
        },
      );
      controller.clock.addListener(() {
        ticks++;
      });
      controller.scheduleDueTimes([now.add(const Duration(seconds: 10))]);
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(ticks, 1);
      expect(queries, 0);
      controller.dispose();
    },
  );
  test(
    'initial loading is awaited and a failed initial read can recover',
    () async {
      final initial = Completer<void>();
      var reads = 0;
      final controller = SharedRefreshController(
        queryChanges: ({since}) async => since == 'one'
            ? const SharedChangeQuery(cursor: 'one')
            : changed('one', {
                'animals': [1],
              }),
      );
      addTearDown(controller.dispose);
      controller.watch(
        dependencies: () => {
          'animals': {1},
        },
        isVisible: () => true,
        initialLoad: initial.future,
        refresh: (_) async {
          reads++;
        },
      );
      final pending = controller.reconcile();
      await Future<void>.delayed(Duration.zero);
      expect(reads, 0);
      expect(controller.appliedCursor, isNull);
      initial.completeError(StateError('initial read failed'));
      await expectLater(pending, throwsStateError);
      await controller.reconcile();
      expect(reads, 1);
      expect(controller.appliedCursor, 'one');
    },
  );
}
