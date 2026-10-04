import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/feeding_weekday_schedule.dart';

/// Formats a weekly due instant in its saved schedule zone, regardless of the
/// viewing device's zone. Interval reminders retain the viewer's local time.
String feedingDueDateLabel(
  BuildContext context,
  DateTime dueAt, {
  String? timeZone,
}) {
  final DateTime displayTime;
  if (timeZone == null) {
    displayTime = dueAt.toLocal();
  } else if (FeedingWeekdaySchedule.isValidTimeZone(timeZone)) {
    displayTime = tz.TZDateTime.from(
      dueAt,
      timeZone == 'UTC' ? tz.UTC : tz.getLocation(timeZone),
    );
  } else {
    // Invalid persisted data must not be presented as the viewer's local time.
    displayTime = dueAt.toUtc();
  }

  final material = MaterialLocalizations.of(context);
  final dateTime =
      '${material.formatMediumDate(displayTime)} '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(displayTime))}';
  return dateTime;
}
