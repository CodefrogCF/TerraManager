import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animalRepository;
  late BoxRepository boxRepository;
  late FeedingRepository feedingRepository;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );

    animalRepository =
        AnimalRepository(database);

    boxRepository =
        BoxRepository(database);

    feedingRepository =
        FeedingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createAnimal() async {
    final boxId =
        await boxRepository.createBox(
      'TM:BOX:11111111-bbbb-4111-8111-111111111111',
    );

    return animalRepository.createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required int animalId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(
          database: database,
          animalId: animalId,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> scrollToLatestFeeding(
    WidgetTester tester,
  ) async {
    await tester.scrollUntilVisible(
      find.byKey(
        const Key(
          'latest-feeding-heading',
        ),
      ),
      300,
      scrollable:
          find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows empty latest feeding state',
    (tester) async {
      final animalId =
          await createAnimal();

      await pumpDetail(
        tester,
        animalId: animalId,
      );

      await scrollToLatestFeeding(
        tester,
      );

      expect(
        find.byKey(
          const Key(
            'latest-feeding-heading',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key(
            'latest-feeding-empty-state',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'No feeding events available',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows newest feeding date and note',
    (tester) async {
      final animalId =
          await createAnimal();

      await feedingRepository.addFeeding(
        animalId,
        DateTime(
          2026,
          8,
          10,
          12,
        ),
        notes: 'Older feeding',
      );

      await feedingRepository.addFeeding(
        animalId,
        DateTime(
          2026,
          8,
          20,
          18,
          30,
        ),
        notes: 'Latest mouse',
      );

      await pumpDetail(
        tester,
        animalId: animalId,
      );

      await scrollToLatestFeeding(
        tester,
      );

      expect(
        find.text(
          '20.08.2026 18:30',
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Latest mouse',
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Older feeding',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'archived animal still shows latest feeding',
    (tester) async {
      final animalId =
          await createAnimal();

      await feedingRepository.addFeeding(
        animalId,
        DateTime(
          2026,
          8,
          25,
          19,
          15,
        ),
        notes: 'Before archive',
      );

      await animalRepository.archiveAnimal(
        animalId: animalId,
        reason:
            AnimalArchiveReason.rehomed,
        archivedAt: DateTime(
          2026,
          9,
          1,
        ),
      );

      await pumpDetail(
        tester,
        animalId: animalId,
      );

      await scrollToLatestFeeding(
        tester,
      );

      expect(
        find.text(
          '25.08.2026 19:15',
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Before archive',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'latest feeding refreshes after returning from feeding history',
    (tester) async {
      final animalId =
          await createAnimal();

      await pumpDetail(
        tester,
        animalId: animalId,
      );

      await tester.tap(
        find.byKey(
          const Key(
            'feeding-history-button',
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key(
            'add-feeding-button',
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(
          const Key(
            'feeding-notes-field',
          ),
        ),
        'New feeding from history',
      );

      await tester.tap(
        find.byKey(
          const Key(
            'save-feeding-button',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'New feeding from history',
        ),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      await scrollToLatestFeeding(
        tester,
      );

      expect(
        find.text(
          'New feeding from history',
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key(
            'latest-feeding-section',
          ),
        ),
        findsOneWidget,
      );
    },
  );
}