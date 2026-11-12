import '../../../core/database/app_database.dart';
import 'animal_rest_period.dart';

class FeedingReminderState {
  final Animal animal;
  final int? intervalDays;
  final int? weekdays;
  final DateTime baseline;
  final DateTime? latestFeedingAt;
  final DateTime referenceAt;
  final DateTime dueAt;
  final DateTime evaluatedAt;

  const FeedingReminderState({
    required this.animal,
    required this.intervalDays,
    this.weekdays,
    required this.baseline,
    required this.latestFeedingAt,
    required this.referenceAt,
    required this.dueAt,
    required this.evaluatedAt,
  });

  int get animalId => animal.id;
  FeedingPauseWindow? get pause => animal.restPeriod?.window;
  bool get isDue => isDueAt(evaluatedAt);
  bool isDueAt(DateTime time) =>
      !time.isBefore(dueAt) && !(pause?.contains(time) ?? false);
  Iterable<DateTime> get transitions => [
    dueAt,
    ?pause?.startsAt,
    ?pause?.endsAt,
  ];
}
