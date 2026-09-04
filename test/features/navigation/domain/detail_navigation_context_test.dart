import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';

void main() {
  test('represents active animals in source order', () {
    final context = DetailNavigationContext.activeAnimals(
      animalIds: [11, 12, 13],
      currentAnimalId: 12,
    );

    expect(context.source, DetailNavigationSource.activeAnimals);
    expect(context.recordIds, [11, 12, 13]);
    expect(context.currentRecordId, 12);
    expect(context.currentIndex, 1);
    expect(context.previousRecordId, 11);
    expect(context.nextRecordId, 13);
    expect(context.sourceBoxId, isNull);
  });

  test('represents archived animals', () {
    final context = DetailNavigationContext.archivedAnimals(
      animalIds: [21, 22],
      currentAnimalId: 21,
    );

    expect(context.source, DetailNavigationSource.archivedAnimals);
    expect(context.currentIndex, 0);
    expect(context.hasPrevious, isFalse);
    expect(context.hasNext, isTrue);
  });

  test('represents animals belonging to one box', () {
    final context = DetailNavigationContext.animalsForBox(
      animalIds: [31, 32],
      currentAnimalId: 32,
      boxId: 7,
    );

    expect(context.source, DetailNavigationSource.boxAnimals);
    expect(context.sourceBoxId, 7);
    expect(context.isAnimalContext, isTrue);
    expect(context.hasNext, isFalse);
  });

  test('represents boxes', () {
    final context = DetailNavigationContext.boxes(
      boxIds: [41, 42, 43],
      currentBoxId: 43,
    );

    expect(context.source, DetailNavigationSource.boxes);
    expect(context.currentRecordId, 43);
    expect(context.currentIndex, 2);
    expect(context.isAnimalContext, isFalse);
  });

  test('keeps the current record identifiable when ids are refreshed', () {
    final context = DetailNavigationContext.activeAnimals(
      animalIds: [51, 52, 53],
      currentAnimalId: 52,
    );

    final refreshed = context.withRecordIds([54, 53, 52, 51]);

    expect(refreshed.currentRecordId, 52);
    expect(refreshed.currentIndex, 2);
    expect(refreshed.source, DetailNavigationSource.activeAnimals);
  });

  test('selects another record without losing the source context', () {
    final context = DetailNavigationContext.animalsForBox(
      animalIds: [61, 62, 63],
      currentAnimalId: 61,
      boxId: 9,
    );

    final selected = context.selectRecord(63);

    expect(selected.currentRecordId, 63);
    expect(selected.currentIndex, 2);
    expect(selected.source, DetailNavigationSource.boxAnimals);
    expect(selected.sourceBoxId, 9);
  });

  test('rejects a context that does not contain the current record', () {
    expect(
      () => DetailNavigationContext.boxes(boxIds: [71, 72], currentBoxId: 73),
      throwsArgumentError,
    );
  });

  test('record ids cannot be changed from outside the context', () {
    final context = DetailNavigationContext.boxes(
      boxIds: [81, 82],
      currentBoxId: 81,
    );

    expect(() => context.recordIds.add(83), throwsUnsupportedError);
  });
}
