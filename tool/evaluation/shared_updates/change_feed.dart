import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

/// Evaluation-only feed. Production writes do not use this class.
class EvaluationChangeFeed {
  EvaluationChangeFeed({this.capacity = 128, String? epoch})
    : epoch = epoch ?? _newEpoch() {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
  }

  final int capacity;
  String epoch;
  int revision = 0;
  final Queue<Map<String, Object>> _events = Queue();
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<void> get changes => _changes.stream;
  String get cursor => '$epoch:$revision';
  String get etag => '"$cursor"';

  static String _newEpoch() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(18, (_) => random.nextInt(256)));
  }

  void publish() {
    revision++;
    _events.add({
      'revision': revision,
      'domains': ['animals', 'reminders', 'feedings'],
    });
    while (_events.length > capacity) {
      _events.removeFirst();
    }
    _changes.add(null);
  }

  void reset() {
    epoch = _newEpoch();
    revision = 0;
    _events.clear();
    _changes.add(null);
  }

  Map<String, Object> since(String? previous) {
    final parts = previous?.split(':');
    final before = parts?.length == 2 ? int.tryParse(parts![1]) : null;
    final reset =
        before == null ||
        parts![0] != epoch ||
        before < 0 ||
        before > revision ||
        (_events.isNotEmpty && before < (_events.first['revision'] as int) - 1);
    return {
      'epoch': epoch,
      'revision': revision,
      'cursor': cursor,
      'reset': reset,
      'events': reset
          ? <Map<String, Object>>[]
          : _events
                .where((event) => (event['revision'] as int) > before)
                .toList(),
    };
  }

  Future<void> close() => _changes.close();
}
