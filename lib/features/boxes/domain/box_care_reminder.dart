import '../../../core/database/date_only.dart';
import '../../../core/database/enums/box_care_event_type.dart';
import 'care_event_type_definition.dart';

class BoxCareReminder {
  const BoxCareReminder({
    required this.typeKey,
    required this.dueOn,
    required this.intervalDays,
    required this.revision,
    this.lastCompletedOn,
  });

  static const maxIntervalDays = 36500;

  final String typeKey;
  final DateTime dueOn;
  final int? intervalDays;
  final String revision;
  final DateTime? lastCompletedOn;

  static bool isBuiltIn(String key) =>
      BoxCareEventType.builtIn.any((type) => type.name == key);

  static DateTime calendarDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static DateTime parseDay(String value) {
    final date = value.length == 10
        ? DateTime.tryParse('${value}T00:00:00Z')
        : null;
    if (date == null || date.year < 1 || dateOnlyString(date) != value) {
      throw const FormatException('Expected YYYY-MM-DD.');
    }
    return date;
  }

  static bool validInterval(int? days) =>
      days == null || (days > 0 && days <= maxIntervalDays);

  static DateTime dueTime(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  bool isDue(DateTime localNow) => !dueTime(dueOn).isAfter(localNow);

  factory BoxCareReminder.fromJson(Map<String, dynamic> json) {
    final typeKey = json['typeKey'] as String;
    final dueOn = parseDay(json['dueOn'] as String);
    final intervalDays = json['intervalDays'] as int?;
    final completed = json['lastCompletedOn'] as String?;
    final lastCompletedOn = completed == null ? null : parseDay(completed);
    final revision = json['revision'] as String;
    if ((!isBuiltIn(typeKey) && !CareEventTypeDefinition.validId(typeKey)) ||
        !CareEventTypeDefinition.validId(revision) ||
        !validInterval(intervalDays) ||
        (lastCompletedOn != null &&
            (intervalDays == null ||
                lastCompletedOn.add(Duration(days: intervalDays)) != dueOn))) {
      throw const FormatException('Invalid Box care reminder.');
    }
    return BoxCareReminder(
      typeKey: typeKey,
      dueOn: dueOn,
      intervalDays: intervalDays,
      revision: revision,
      lastCompletedOn: lastCompletedOn,
    );
  }

  Map<String, dynamic> toJson() => {
    'typeKey': typeKey,
    'dueOn': dateOnlyString(dueOn),
    'intervalDays': intervalDays,
    'lastCompletedOn': dateOnlyString(lastCompletedOn),
    'revision': revision,
  };
}
