import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as tz;

/// A fixed weekly reminder in a named time zone.
///
/// Weekday bits follow DateTime.weekday: Monday is bit 0, Sunday bit 6.
class FeedingWeekdaySchedule {
  static bool _zonesInitialized = false;

  static void _initializeZones() {
    if (_zonesInitialized) return;
    time_zone_data.initializeTimeZones();
    _zonesInitialized = true;
  }

  static List<String> get availableTimeZones {
    _initializeZones();
    return {...tz.timeZoneDatabase.locations.keys, 'UTC'}.toList()..sort();
  }

  static bool isValidTimeZone(String value) {
    _initializeZones();
    return value == 'UTC' || tz.timeZoneDatabase.locations.containsKey(value);
  }

  static bool hasWeekday(int mask, int weekday) =>
      mask & (1 << (weekday - DateTime.monday)) != 0;

  static void validate({
    required int? intervalDays,
    required DateTime? baseline,
    required int? weekdays,
    required int? minuteOfDay,
    required String? timeZone,
  }) {
    final weeklyFieldsPresent =
        weekdays != null || minuteOfDay != null || timeZone != null;
    if (intervalDays == null && baseline == null && !weeklyFieldsPresent) {
      return;
    }
    if (baseline == null) {
      throw ArgumentError('A feeding reminder requires a baseline.');
    }
    if (weeklyFieldsPresent) {
      if (intervalDays != null ||
          weekdays == null ||
          weekdays < 1 ||
          weekdays > 127 ||
          minuteOfDay == null ||
          minuteOfDay < 0 ||
          minuteOfDay >= 1440 ||
          timeZone == null ||
          !isValidTimeZone(timeZone)) {
        throw ArgumentError('Invalid weekday feeding reminder configuration.');
      }
      return;
    }
    if (intervalDays == null || intervalDays <= 0) {
      throw ArgumentError('A positive interval is required.');
    }
  }

  static bool isConfigured({
    required int? intervalDays,
    required DateTime? baseline,
    required int? weekdays,
    required int? minuteOfDay,
    required String? timeZone,
  }) {
    if (baseline == null) return false;
    if (weekdays != null) {
      return weekdays > 0 &&
          weekdays <= 127 &&
          intervalDays == null &&
          minuteOfDay != null &&
          minuteOfDay >= 0 &&
          minuteOfDay < 1440 &&
          timeZone != null &&
          isValidTimeZone(timeZone);
    }
    return intervalDays != null &&
        intervalDays > 0 &&
        minuteOfDay == null &&
        timeZone == null;
  }

  /// Returns the first scheduled appointment after activation or feeding.
  ///
  /// A feeding on a scheduled calendar day completes that day's appointment,
  /// even if it was recorded before the selected time. Missed appointments
  /// remain overdue until a new FeedingEvent is recorded.
  static DateTime nextDueAt({
    required int weekdays,
    required int minuteOfDay,
    required String timeZone,
    required DateTime baseline,
    DateTime? latestFeedingAt,
  }) {
    validate(
      intervalDays: null,
      baseline: baseline,
      weekdays: weekdays,
      minuteOfDay: minuteOfDay,
      timeZone: timeZone,
    );
    final location = timeZone == 'UTC' ? tz.UTC : tz.getLocation(timeZone);
    final reference = latestFeedingAt ?? baseline;
    final localReference = tz.TZDateTime.from(reference, location);
    for (var offset = 0; offset <= 7; offset++) {
      final calendarDay = DateTime.utc(
        localReference.year,
        localReference.month,
        localReference.day + offset,
      );
      if (!hasWeekday(weekdays, calendarDay.weekday)) continue;
      if (latestFeedingAt != null && offset == 0) continue;
      final due = tz.TZDateTime(
        location,
        calendarDay.year,
        calendarDay.month,
        calendarDay.day,
        minuteOfDay ~/ 60,
        minuteOfDay % 60,
      );
      if (due.isAfter(reference)) return due.toUtc();
    }
    throw StateError('No weekly feeding appointment could be calculated.');
  }
}
