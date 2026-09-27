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
    final dueAt = DateTime.tryParse(reminder['dueAt'] as String? ?? '');
    return dueAt != null && !dueAt.isAfter(current);
  });
}
