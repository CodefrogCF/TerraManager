import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/feedings/domain/feeding_weekday_schedule.dart';

void main() {
  const mondayWednesdayFriday = 1 | 4 | 16;

  test('accepts UTC as a schedule time zone', () {
    expect(FeedingWeekdaySchedule.isValidTimeZone('UTC'), isTrue);
  });

  test('keeps fixed weekdays when a feeding happens early', () {
    final due = FeedingWeekdaySchedule.nextDueAt(
      weekdays: mondayWednesdayFriday,
      minuteOfDay: 10 * 60,
      timeZone: 'Europe/Berlin',
      baseline: DateTime.utc(2026, 10, 4, 12),
      latestFeedingAt: DateTime.utc(2026, 10, 5, 6),
    );
    expect(due, DateTime.utc(2026, 10, 7, 8));
  });

  test('leaves a missed appointment overdue until a feeding', () {
    final due = FeedingWeekdaySchedule.nextDueAt(
      weekdays: mondayWednesdayFriday,
      minuteOfDay: 10 * 60,
      timeZone: 'Europe/Berlin',
      baseline: DateTime.utc(2026, 10, 4, 12),
    );
    expect(due, DateTime.utc(2026, 10, 5, 8));
  });

  test('uses local wall time across daylight saving changes', () {
    final before = FeedingWeekdaySchedule.nextDueAt(
      weekdays: 1 << (DateTime.sunday - 1),
      minuteOfDay: 10 * 60,
      timeZone: 'Europe/Berlin',
      baseline: DateTime.utc(2026, 3, 28, 12),
    );
    final after = FeedingWeekdaySchedule.nextDueAt(
      weekdays: 1 << (DateTime.sunday - 1),
      minuteOfDay: 10 * 60,
      timeZone: 'Europe/Berlin',
      baseline: DateTime.utc(2026, 10, 24, 12),
    );
    expect(before, DateTime.utc(2026, 3, 29, 8));
    expect(after, DateTime.utc(2026, 10, 25, 9));
  });

  test('rejects partial and conflicting reminder configurations', () {
    expect(
      () => FeedingWeekdaySchedule.validate(
        intervalDays: 2,
        baseline: DateTime.utc(2026),
        weekdays: 1,
        minuteOfDay: 720,
        timeZone: 'UTC',
      ),
      throwsArgumentError,
    );
    expect(
      () => FeedingWeekdaySchedule.validate(
        intervalDays: null,
        baseline: DateTime.utc(2026),
        weekdays: 0,
        minuteOfDay: 720,
        timeZone: 'UTC',
      ),
      throwsArgumentError,
    );
  });
}
