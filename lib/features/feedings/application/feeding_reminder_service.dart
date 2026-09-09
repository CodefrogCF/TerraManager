import '../../../core/database/app_database.dart';
import '../../../core/database/enums/animal_status.dart';
import '../../../core/database/repositories/animal_repository.dart';
import '../../../core/database/repositories/feeding_repository.dart';
import '../domain/feeding_reminder_state.dart';

typedef FeedingReminderClock = DateTime Function();

class FeedingReminderService {
  final AnimalRepository _animalRepository;
  final FeedingRepository _feedingRepository;
  final FeedingReminderClock _now;

  FeedingReminderService(AppDatabase database, {FeedingReminderClock? now})
    : _animalRepository = AnimalRepository(database),
      _feedingRepository = FeedingRepository(database),
      _now = now ?? DateTime.now;

  Future<List<FeedingReminderState>> getReminderStates() async {
    final animals = await _animalRepository
        .getActiveAnimalsWithFeedingReminders();

    if (animals.isEmpty) {
      return const [];
    }

    final latestFeedingTimes = await _feedingRepository.getLatestFeedingTimes(
      animals.map((animal) => animal.id),
    );
    return calculateReminderStates(
      animals: animals,
      latestFeedingTimes: latestFeedingTimes,
    );
  }

  List<FeedingReminderState> calculateReminderStates({
    required Iterable<Animal> animals,
    required Map<int, DateTime> latestFeedingTimes,
  }) {
    final evaluatedAt = _now();
    final states = animals
        .where(_hasEnabledReminder)
        .map(
          (animal) => _calculateState(
            animal: animal,
            latestFeedingAt: latestFeedingTimes[animal.id],
            evaluatedAt: evaluatedAt,
          ),
        )
        .toList();

    states.sort((left, right) {
      final dueComparison = left.dueAt.compareTo(right.dueAt);

      if (dueComparison != 0) {
        return dueComparison;
      }

      return left.animalId.compareTo(right.animalId);
    });

    return List<FeedingReminderState>.unmodifiable(states);
  }

  Future<List<FeedingReminderState>> getDueReminderStates() async {
    final states = await getReminderStates();

    return List<FeedingReminderState>.unmodifiable(
      states.where((state) => state.isDue),
    );
  }

  Future<FeedingReminderState?> getReminderStateForAnimal(int animalId) async {
    final animal = await _animalRepository.getAnimalById(animalId);

    if (animal == null || !_hasEnabledReminder(animal)) {
      return null;
    }

    final latestFeedingAt = await _feedingRepository.getLastFeeding(animalId);

    return _calculateState(
      animal: animal,
      latestFeedingAt: latestFeedingAt,
      evaluatedAt: _now(),
    );
  }

  FeedingReminderState _calculateState({
    required Animal animal,
    required DateTime? latestFeedingAt,
    required DateTime evaluatedAt,
  }) {
    final intervalDays = animal.feedingReminderIntervalDays;
    final baseline = animal.feedingReminderBaseline;

    if (intervalDays == null || intervalDays <= 0 || baseline == null) {
      throw StateError(
        'Cannot calculate a feeding reminder without a valid configuration.',
      );
    }

    // Drift can restore timestamps in the platform's local time zone even when
    // they were originally written as UTC. Keep all values exposed by one
    // reminder state in the same representation as the injected clock while
    // preserving their actual moments in time.
    final normalizedBaseline = _inClockTimeZone(baseline, evaluatedAt);
    final normalizedLatestFeedingAt = latestFeedingAt == null
        ? null
        : _inClockTimeZone(latestFeedingAt, evaluatedAt);

    // Feeding history is authoritative whenever it exists. The baseline only
    // gives Animals without any FeedingEvent a defined starting point.
    final referenceAt = normalizedLatestFeedingAt ?? normalizedBaseline;
    final dueAt = referenceAt.add(Duration(days: intervalDays));

    return FeedingReminderState(
      animal: animal,
      intervalDays: intervalDays,
      baseline: normalizedBaseline,
      latestFeedingAt: normalizedLatestFeedingAt,
      referenceAt: referenceAt,
      dueAt: dueAt,
      evaluatedAt: evaluatedAt,
      isDue: !evaluatedAt.isBefore(dueAt),
    );
  }

  DateTime _inClockTimeZone(DateTime timestamp, DateTime evaluatedAt) {
    return evaluatedAt.isUtc ? timestamp.toUtc() : timestamp.toLocal();
  }

  bool _hasEnabledReminder(Animal animal) {
    final intervalDays = animal.feedingReminderIntervalDays;

    return animal.status == AnimalStatus.active &&
        intervalDays != null &&
        intervalDays > 0 &&
        animal.feedingReminderBaseline != null;
  }
}
