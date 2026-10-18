import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_server/changes/application/committed_changes.dart';

void main() {
  late CommittedChanges changes;
  Map<String, Object?> query({
    String? since,
    int account = 1,
    String role = 'administrator',
    int preferences = 0,
  }) => changes.query(
    accountKey: 'account-$account',
    role: role,
    preferencesRevision: preferences,
    since: since,
  );
  setUp(() => changes = CommittedChanges(capacity: 2));
  test(
    'initial snapshots reset and bounded replay keeps the exact lower boundary',
    () {
      final initial = query();
      expect(initial['reason'], 'missing_cursor');
      final zero = initial['cursor'] as String;
      changes.publish({
        'animals': [1],
      });
      final one = query(since: zero)['cursor'] as String;
      changes.publish({
        'boxes': [2],
      });
      expect(query(since: zero)['reset'], false);
      changes.publish({
        'animals': [3],
      });
      expect(query(since: zero)['reason'], 'expired_cursor');
      expect((query(since: one)['changes'] as List).length, 2);
    },
  );
  test(
    'foreign, future, invalid and replacement cursors force reconciliation',
    () {
      final zero = query()['cursor'] as String;
      expect(
        query(since: query(account: 2)['cursor'] as String)['reason'],
        'foreign_cursor',
      );
      expect(
        query(since: query(role: 'caregiver')['cursor'] as String)['reason'],
        'foreign_cursor',
      );
      expect(
        query(since: zero.replaceFirst(':0:', ':3:'))['reason'],
        'future_cursor',
      );
      expect(query(since: 'invalid')['reason'], 'invalid_cursor');
      changes.reset();
      expect(query(since: zero)['reason'], 'epoch_changed');
    },
  );
  test(
    'hints are immutable, deduplicated and bounded without losing invalidation',
    () {
      final ids = [3, 1, 3];
      final zero = query()['cursor'] as String;
      changes.publish({
        'animals': ids,
        'boxes': List.generate(129, (i) => i + 1),
      });
      ids.clear();
      final resources =
          ((query(since: zero)['changes'] as List).single as Map)['resources']
              as Map;
      expect(resources['animals'], [1, 3]);
      expect(resources['boxes'], isNull);
    },
  );
  test(
    'private preferences do not advance the collection or another account',
    () {
      final own = query()['cursor'] as String;
      final other = query(account: 2)['cursor'] as String;
      expect(query(since: own, preferences: 4)['preferencesChanged'], true);
      expect(query(since: other, account: 2)['preferencesChanged'], false);
      expect(changes.revision, 0);
    },
  );
  test('administrative resource hints are filtered for caregivers', () {
    final admin = query()['cursor'] as String;
    final caregiver = query(role: 'caregiver')['cursor'] as String;
    changes.publish({
      'animals': [1],
      'audit': null,
    });
    final adminHint = (query(since: admin)['changes'] as List).single as Map;
    final careHint =
        (query(since: caregiver, role: 'caregiver')['changes'] as List).single
            as Map;
    expect((adminHint['resources'] as Map).containsKey('audit'), true);
    expect((careHint['resources'] as Map).containsKey('audit'), false);
  });
}
