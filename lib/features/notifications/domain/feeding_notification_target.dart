import 'dart:convert';

/// Versioned local-only payload. Never contains names, photos or credentials.
class FeedingNotificationTarget {
  const FeedingNotificationTarget({
    required this.animalId,
    required this.createdAt,
    required this.dueAt,
  });

  final int animalId;
  final DateTime createdAt;
  final DateTime dueAt;

  String get identity => '$animalId:${createdAt.millisecondsSinceEpoch}';
  String get appointment => '$identity:${dueAt.millisecondsSinceEpoch}';

  String encode() => jsonEncode({
    'v': 1,
    'collection': 'standalone',
    'animal': animalId,
    'created': createdAt.millisecondsSinceEpoch,
    'due': dueAt.millisecondsSinceEpoch,
  });

  static FeedingNotificationTarget? parse(String? payload) {
    if (payload == null || payload.length > 512) return null;
    try {
      final value = jsonDecode(payload);
      if (value is! Map ||
          value['v'] != 1 ||
          value['collection'] != 'standalone' ||
          value['animal'] is! int ||
          (value['animal'] as int) <= 0 ||
          value['created'] is! int ||
          value['due'] is! int) {
        return null;
      }
      return FeedingNotificationTarget(
        animalId: value['animal'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          value['created'] as int,
          isUtc: true,
        ),
        dueAt: DateTime.fromMillisecondsSinceEpoch(
          value['due'] as int,
          isUtc: true,
        ),
      );
    } on Object {
      return null;
    }
  }
}
