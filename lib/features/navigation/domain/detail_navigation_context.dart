enum DetailNavigationSource {
  activeAnimals,
  archivedAnimals,
  boxAnimals,
  boxes,
}

final class DetailNavigationContext {
  factory DetailNavigationContext.activeAnimals({
    required Iterable<int> animalIds,
    required int currentAnimalId,
  }) {
    return DetailNavigationContext._(
      recordIds: animalIds,
      currentRecordId: currentAnimalId,
      source: DetailNavigationSource.activeAnimals,
    );
  }

  factory DetailNavigationContext.archivedAnimals({
    required Iterable<int> animalIds,
    required int currentAnimalId,
  }) {
    return DetailNavigationContext._(
      recordIds: animalIds,
      currentRecordId: currentAnimalId,
      source: DetailNavigationSource.archivedAnimals,
    );
  }

  factory DetailNavigationContext.animalsForBox({
    required Iterable<int> animalIds,
    required int currentAnimalId,
    required int boxId,
  }) {
    return DetailNavigationContext._(
      recordIds: animalIds,
      currentRecordId: currentAnimalId,
      source: DetailNavigationSource.boxAnimals,
      sourceBoxId: boxId,
    );
  }

  factory DetailNavigationContext.boxes({
    required Iterable<int> boxIds,
    required int currentBoxId,
  }) {
    return DetailNavigationContext._(
      recordIds: boxIds,
      currentRecordId: currentBoxId,
      source: DetailNavigationSource.boxes,
    );
  }

  DetailNavigationContext._({
    required Iterable<int> recordIds,
    required this.currentRecordId,
    required this.source,
    this.sourceBoxId,
  }) : recordIds = List<int>.unmodifiable(recordIds) {
    if (this.recordIds.isEmpty) {
      throw ArgumentError.value(recordIds, 'recordIds', 'must not be empty');
    }

    if (this.recordIds.toSet().length != this.recordIds.length) {
      throw ArgumentError.value(
        recordIds,
        'recordIds',
        'must not contain duplicates',
      );
    }

    if (!this.recordIds.contains(currentRecordId)) {
      throw ArgumentError.value(
        currentRecordId,
        'currentRecordId',
        'must be included in recordIds',
      );
    }

    if (source == DetailNavigationSource.boxAnimals && sourceBoxId == null) {
      throw ArgumentError.notNull('sourceBoxId');
    }

    if (source != DetailNavigationSource.boxAnimals && sourceBoxId != null) {
      throw ArgumentError.value(
        sourceBoxId,
        'sourceBoxId',
        'is only valid for a box animal context',
      );
    }
  }

  final List<int> recordIds;
  final int currentRecordId;
  final DetailNavigationSource source;
  final int? sourceBoxId;

  int get currentIndex => recordIds.indexOf(currentRecordId);

  bool get isAnimalContext => source != DetailNavigationSource.boxes;

  bool get hasPrevious => currentIndex > 0;

  bool get hasNext => currentIndex < recordIds.length - 1;

  int? get previousRecordId {
    if (!hasPrevious) {
      return null;
    }

    return recordIds[currentIndex - 1];
  }

  int? get nextRecordId {
    if (!hasNext) {
      return null;
    }

    return recordIds[currentIndex + 1];
  }

  DetailNavigationContext selectRecord(int recordId) {
    return DetailNavigationContext._(
      recordIds: recordIds,
      currentRecordId: recordId,
      source: source,
      sourceBoxId: sourceBoxId,
    );
  }

  DetailNavigationContext withRecordIds(Iterable<int> recordIds) {
    return DetailNavigationContext._(
      recordIds: recordIds,
      currentRecordId: currentRecordId,
      source: source,
      sourceBoxId: sourceBoxId,
    );
  }
}
