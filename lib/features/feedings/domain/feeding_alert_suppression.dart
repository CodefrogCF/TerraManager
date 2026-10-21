/// Personal overview state, independent of the feeding schedule and history.
const feedingAlertSuppressionsKey = 'feeding_alert_suppressions';
const feedingAlertSuppressionDuration = Duration(hours: 24);

// Creation time prevents an unrelated record with a reused ID inheriting state.
String feedingAlertAnimalKey(int id, DateTime createdAt) =>
    '$id:${createdAt.millisecondsSinceEpoch}';

bool isFeedingAlertKey(String key) =>
    RegExp(r'^[1-9][0-9]{0,18}:[0-9]{1,16}$').hasMatch(key);

bool isFeedingAlertExpiry(Object? value) =>
    value is int && value > 0 && value <= 8640000000000000;

Map<String, int> parseFeedingAlertSuppressions(Object? value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String &&
              isFeedingAlertKey(entry.key as String) &&
              isFeedingAlertExpiry(entry.value))
            entry.key as String: entry.value as int,
      }
    : {};
