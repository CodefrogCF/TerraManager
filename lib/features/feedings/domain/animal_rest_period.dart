import 'package:terramanager/core/database/date_only.dart';
import 'package:timezone/timezone.dart' as tz;

import 'feeding_weekday_schedule.dart';

/// An inclusive range of calendar dates in one saved IANA time zone.
class AnimalRestPeriod {
  factory AnimalRestPeriod({
    required DateTime startDate,
    required DateTime endDate,
    required String timeZone,
  }) => AnimalRestPeriod._fromDates(
    dateOnlyString(startDate)!,
    dateOnlyString(endDate)!,
    timeZone,
  );

  AnimalRestPeriod._(this.startDate, this.endDate, this.timeZone, this.window);

  final DateTime startDate;
  final DateTime endDate;
  final String timeZone;
  final FeedingPauseWindow window;

  static AnimalRestPeriod? fromJson(Object? value) {
    if (value == null) return null;
    if (value is Map &&
        value.length == 3 &&
        value['startDate'] is String &&
        value['endDate'] is String &&
        value['timeZone'] is String) {
      return AnimalRestPeriod._fromDates(
        value['startDate'] as String,
        value['endDate'] as String,
        value['timeZone'] as String,
      );
    }
    throw const FormatException('Invalid Animal rest period.');
  }

  factory AnimalRestPeriod._fromDates(
    String from,
    String through,
    String zone,
  ) {
    final start = _date(from);
    final end = _date(through);
    if (end.isBefore(start) || !FeedingWeekdaySchedule.isValidTimeZone(zone)) {
      throw const FormatException('Invalid Animal rest period.');
    }
    final location = zone == 'UTC' ? tz.UTC : tz.getLocation(zone);
    final startsAt = tz.TZDateTime(
      location,
      start.year,
      start.month,
      start.day,
    );
    final endsAt = tz.TZDateTime(location, end.year, end.month, end.day + 1);
    if (!startsAt.isBefore(endsAt)) {
      throw const FormatException('Invalid Animal rest period.');
    }
    return AnimalRestPeriod._(
      start,
      end,
      zone,
      FeedingPauseWindow(startsAt.toUtc(), endsAt.toUtc()),
    );
  }

  static DateTime _date(String text) {
    final date = DateTime.tryParse('${text}T00:00:00Z');
    if (date == null || date.year < 1 || dateOnlyString(date) != text) {
      throw const FormatException('Expected a valid calendar date.');
    }
    return date;
  }

  Map<String, String> toJson() => {
    'startDate': dateOnlyString(startDate)!,
    'endDate': dateOnlyString(endDate)!,
    'timeZone': timeZone,
  };

  @override
  bool operator ==(Object other) =>
      other is AnimalRestPeriod &&
      startDate == other.startDate &&
      endDate == other.endDate &&
      timeZone == other.timeZone;

  @override
  int get hashCode => Object.hash(startDate, endDate, timeZone);
}

/// UTC bounds shared by UI clocks and one-shot notifications.
class FeedingPauseWindow {
  const FeedingPauseWindow(this.startsAt, this.endsAt);

  final DateTime startsAt;
  final DateTime endsAt;

  bool contains(DateTime time) =>
      !time.isBefore(startsAt) && time.isBefore(endsAt);
  DateTime defer(DateTime time) => contains(time) ? endsAt : time;

  @override
  bool operator ==(Object other) =>
      other is FeedingPauseWindow &&
      startsAt == other.startsAt &&
      endsAt == other.endsAt;

  @override
  int get hashCode => Object.hash(startsAt, endsAt);
}
