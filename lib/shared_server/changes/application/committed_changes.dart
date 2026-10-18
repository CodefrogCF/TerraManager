import 'dart:collection';

import 'package:uuid/uuid.dart';

/// Process-local invalidations. Values are IDs, never collection contents.
class CommittedChange {
  CommittedChange(this.revision, Map<String, Iterable<int>?> resources)
    : resources = Map.unmodifiable({
        for (final entry in resources.entries)
          entry.key: entry.value == null ? null : _boundedIds(entry.value!),
      });

  static List<int>? _boundedIds(Iterable<int> ids) {
    final values = <int>{};
    for (final id in ids) {
      values.add(id);
      if (values.length > 128) return null;
    }
    return List.unmodifiable(values.toList()..sort());
  }

  final int revision;
  final Map<String, List<int>?> resources;

  Map<String, Object?> json({required bool administrator}) => {
    'revision': revision,
    'resources': {
      for (final entry in resources.entries)
        if (entry.key != 'audit' || administrator) entry.key: entry.value,
    },
  };
}

/// A cursor describes advertised commits, separately from backup admission.
/// Private preferences use their account-store revision, not this global log.
class CommittedChanges {
  CommittedChanges({this.capacity = 128}) {
    if (capacity < 1 || capacity > 1024) {
      throw ArgumentError.value(capacity, 'capacity');
    }
  }

  static const cursorHeader = 'X-Shared-Care-Cursor';
  static const beforeHeader = 'X-Shared-Care-Cursor-Before';
  final int capacity;
  final Queue<CommittedChange> _history = Queue();
  String _epoch = const Uuid().v4();
  int _revision = 0;
  String get epoch => _epoch;
  int get revision => _revision;

  void publish(Map<String, Iterable<int>?> resources) {
    if (resources.isEmpty) return;
    _history.add(CommittedChange(++_revision, resources));
    while (_history.length > capacity) {
      _history.removeFirst();
    }
  }

  /// Called once after successful collection replacement, before its reply.
  void reset() {
    _epoch = const Uuid().v4();
    _revision = 0;
    _history.clear();
  }

  String cursor({
    required String accountKey,
    required String role,
    required int preferencesRevision,
  }) => '$_epoch:$_revision:$accountKey:$role:$preferencesRevision';

  Map<String, Object?> query({
    required String accountKey,
    required String role,
    required int preferencesRevision,
    String? since,
  }) {
    String? reason;
    var collectionFrom = 0;
    var preferencesFrom = 0;
    if (since == null) {
      reason = 'missing_cursor';
    } else {
      final parts = since.length <= 200 ? since.split(':') : <String>[];
      final revision = parts.length == 5 ? int.tryParse(parts[1]) : null;
      final preferences = parts.length == 5 ? int.tryParse(parts[4]) : null;
      if (parts.length != 5 ||
          revision == null ||
          preferences == null ||
          revision < 0 ||
          preferences < 0) {
        reason = 'invalid_cursor';
      } else if (parts[0] != _epoch) {
        reason = 'epoch_changed';
      } else if (parts[2] != accountKey || parts[3] != role) {
        reason = 'foreign_cursor';
      } else if (revision > _revision || preferences > preferencesRevision) {
        reason = 'future_cursor';
      } else if (_history.isNotEmpty &&
          revision < _history.first.revision - 1) {
        reason = 'expired_cursor';
      } else {
        collectionFrom = revision;
        preferencesFrom = preferences;
      }
    }
    return {
      'epoch': _epoch,
      'revision': _revision,
      'preferencesRevision': preferencesRevision,
      'cursor': cursor(
        accountKey: accountKey,
        role: role,
        preferencesRevision: preferencesRevision,
      ),
      'reset': reason != null,
      'reason': ?reason,
      'preferencesChanged':
          reason != null || preferencesFrom != preferencesRevision,
      'changes': [
        if (reason == null)
          for (final change in _history)
            if (change.revision > collectionFrom)
              change.json(administrator: role == 'administrator'),
      ],
    };
  }
}
