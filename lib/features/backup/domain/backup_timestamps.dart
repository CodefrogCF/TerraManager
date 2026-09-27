import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class BackupTimestamps {
  static bool _initialized = false;
  static void _initialize() {
    if (!_initialized) {
      data.initializeTimeZones();
      _initialized = true;
    }
  }

  static List<String> get zones {
    _initialize();
    return tz.timeZoneDatabase.locations.keys.toList()..sort();
  }

  static const _instantKeys = {
    'createdAt',
    'updatedAt',
    'archivedAt',
    'fedAt',
    'measuredAt',
    'shedAt',
    'capturedAt',
    'feedingReminderBaseline',
  };
  static bool hasZone(String value) =>
      RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(value);

  /// Rewrite only known instant fields, never notes or date-only birth dates.
  /// Missing zones in legacy files are interpreted in the selected source zone.
  /// Standalone keeps its historical device-local interpretation when omitted.
  static bool normalize(
    Object? json, {
    String? legacyTimeZone,
    bool requireZone = false,
  }) {
    tz.Location? location;
    if (legacyTimeZone != null) {
      _initialize();
      location = tz.getLocation(legacyTimeZone);
    }
    var legacy = false;
    void visit(Object? node) {
      if (node is Map<String, dynamic>) {
        for (final key in node.keys.toList()) {
          final value = node[key];
          if (_instantKeys.contains(key) && value is String) {
            if (hasZone(value)) continue;
            legacy = true;
            if (requireZone && location == null) {
              throw const FormatException(
                'This legacy backup contains times without a time zone. Select the original device time zone before restoring.',
              );
            }
            if (location != null) {
              // Parse components as UTC first so the server/device zone has no influence.
              final wall = DateTime.parse('${value}Z');
              final candidates = <DateTime>[];
              for (final offset
                  in location.zones
                      .map((zone) => zone.offset.inMicroseconds)
                      .toSet()) {
                final utc = DateTime.fromMicrosecondsSinceEpoch(
                  wall.microsecondsSinceEpoch - offset,
                  isUtc: true,
                );
                final local = tz.TZDateTime.from(utc, location);
                if (local.year == wall.year &&
                    local.month == wall.month &&
                    local.day == wall.day &&
                    local.hour == wall.hour &&
                    local.minute == wall.minute &&
                    local.second == wall.second) {
                  candidates.add(utc);
                }
              }
              // Reject skipped hours; for a repeated autumn hour use the earlier instant.
              // A legacy wall clock cannot tell which occurrence was intended.
              if (candidates.isEmpty) {
                throw FormatException(
                  'Legacy time $value does not exist in $legacyTimeZone (daylight saving transition).',
                );
              }
              candidates.sort();
              node[key] = candidates.first.toIso8601String();
            }
          } else {
            visit(value);
          }
        }
      } else if (node is List) {
        for (final entry in node) {
          visit(entry);
        }
      }
    }

    visit(json);
    return legacy;
  }
}
