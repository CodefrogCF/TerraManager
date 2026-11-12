import 'dart:convert';

import '../../feedings/domain/animal_rest_period.dart';

/// Versioned local-only payload. Never contains names, photos or credentials.
class FeedingNotificationTarget {
  const FeedingNotificationTarget({
    required this.animalId,
    required this.createdAt,
    required this.dueAt,
    this.pause,
  });

  final int animalId;
  final DateTime createdAt;
  final DateTime dueAt;
  final FeedingPauseWindow? pause;

  String get identity => '$animalId:${createdAt.millisecondsSinceEpoch}';
  String get appointment => '$identity:${dueAt.millisecondsSinceEpoch}';

  String encode() => jsonEncode({
    'v': 1,
    'collection': 'standalone',
    'animal': animalId,
    'created': createdAt.millisecondsSinceEpoch,
    'due': dueAt.millisecondsSinceEpoch,
    if (pause case final window?) ...{
      'pauseFrom': window.startsAt.millisecondsSinceEpoch,
      'pauseUntil': window.endsAt.millisecondsSinceEpoch,
    },
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
      final start = value['pauseFrom'];
      final end = value['pauseUntil'];
      if ((start != null || end != null) &&
          (start is! int || end is! int || start >= end)) {
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
        pause: start is int && end is int
            ? FeedingPauseWindow(
                DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
                DateTime.fromMillisecondsSinceEpoch(end, isUtc: true),
              )
            : null,
      );
    } on Object {
      return null;
    }
  }
}
