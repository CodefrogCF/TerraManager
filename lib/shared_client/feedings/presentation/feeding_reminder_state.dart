import 'package:terramanager/features/feedings/domain/animal_rest_period.dart';

FeedingPauseWindow? sharedReminderPause(Map<String, dynamic> reminder) {
  final start = DateTime.tryParse(reminder['pauseStartsAt'] as String? ?? '');
  final end = DateTime.tryParse(reminder['pauseEndsAt'] as String? ?? '');
  return start != null && end != null && start.isBefore(end)
      ? FeedingPauseWindow(start, end)
      : null;
}

bool hasDueSharedFeedings(
  Iterable<Map<String, dynamic>> animals,
  Iterable<Map<String, dynamic>> reminders, {
  DateTime? now,
}) {
  final activeIds = {
    for (final animal in animals)
      if (animal['status'] == 'active') animal['id'],
  };
  final current = now ?? DateTime.now();
  return reminders.any((reminder) {
    if (!activeIds.contains(reminder['animalId'])) return false;
    if (sharedReminderPause(reminder)?.contains(current) ?? false) return false;
    final dueAt = DateTime.tryParse(reminder['dueAt'] as String? ?? '');
    return dueAt != null && !dueAt.isAfter(current);
  });
}
