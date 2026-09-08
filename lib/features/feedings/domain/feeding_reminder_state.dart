import '../../../core/database/app_database.dart';

class FeedingReminderState {
  final Animal animal;
  final int intervalDays;
  final DateTime baseline;
  final DateTime? latestFeedingAt;
  final DateTime referenceAt;
  final DateTime dueAt;
  final DateTime evaluatedAt;
  final bool isDue;

  const FeedingReminderState({
    required this.animal,
    required this.intervalDays,
    required this.baseline,
    required this.latestFeedingAt,
    required this.referenceAt,
    required this.dueAt,
    required this.evaluatedAt,
    required this.isDue,
  });

  int get animalId => animal.id;
}
