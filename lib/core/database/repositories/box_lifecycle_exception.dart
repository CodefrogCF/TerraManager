import '../app_database.dart';

class BoxArchiveBlockedException implements Exception {
  final List<Animal> animals;

  BoxArchiveBlockedException(Iterable<Animal> animals)
    : animals = List<Animal>.unmodifiable(animals);
}

class BoxAssignmentException extends ArgumentError {
  BoxAssignmentException(int boxId)
    : super.value(boxId, 'boxId', 'Box must exist and be active');
}
