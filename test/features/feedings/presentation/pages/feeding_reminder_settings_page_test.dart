import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_reminder_settings_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase database;
  late int boxId;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    boxId = await BoxRepository(database)
        .createBox('TM:BOX:98989898-9898-4989-8989-989898989898');
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createAnimal({int? intervalDays, DateTime? baseline}) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Reminder Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      feedingReminderIntervalDays: intervalDays,
      feedingReminderBaseline: baseline,
    );
  }

  Widget localizedApp({required Widget home}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required int animalId,
    DateTime Function()? now,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        home: FeedingReminderSettingsPage(
          database: database,
          animalId: animalId,
          now: now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpPageWithNavigation(
    WidgetTester tester, {
    required int animalId,
    DateTime Function()? now,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-feeding-reminder-button'),
                  onPressed: () {
                    Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => FeedingReminderSettingsPage(
                          database: database,
                          animalId: animalId,
                          now: now,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Reminder'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-feeding-reminder-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows reminders disabled by default', (tester) async {
    final animalId = await createAnimal();

    await pumpPage(tester, animalId: animalId);

    expect(
      find.byKey(const Key('feeding-reminder-settings-page')),
      findsOneWidget,
    );
    expect(find.text('Reminder Snake'), findsOneWidget);
    expect(find.text('Pantherophis guttatus'), findsOneWidget);

    final reminderSwitch = tester.widget<SwitchListTile>(
      find.byKey(const Key('feeding-reminder-enabled-switch')),
    );

    expect(reminderSwitch.value, isFalse);
    expect(
      find.byKey(const Key('feeding-reminder-interval-days-field')),
      findsNothing,
    );
  });

  testWidgets('requires a positive interval when reminders are enabled', (
    tester,
  ) async {
    final animalId = await createAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-feeding-reminder-button')));
    await tester.pump();

    expect(
      find.text('Please enter a positive whole number of days'),
      findsOneWidget,
    );

    final animal = await AnimalRepository(database).getAnimalById(animalId);

    expect(animal!.feedingReminderIntervalDays, isNull);
    expect(animal.feedingReminderBaseline, isNull);
  });

  testWidgets('enables a reminder with the injected baseline', (tester) async {
    final animalId = await createAnimal();
    final baseline = DateTime(2026, 9, 12, 15, 30);

    await pumpPageWithNavigation(
      tester,
      animalId: animalId,
      now: () => baseline,
    );

    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('feeding-reminder-interval-days-field')),
      '7',
    );
    await tester.tap(
      find.byKey(const Key('save-feeding-reminder-form-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Reminder'), findsOneWidget);

    final animal = await AnimalRepository(database).getAnimalById(animalId);

    expect(animal!.feedingReminderIntervalDays, 7);
    expect(animal.feedingReminderBaseline, baseline);
  });

  testWidgets('changes an interval without resetting its baseline', (
    tester,
  ) async {
    final baseline = DateTime(2026, 9, 1, 9);
    final animalId = await createAnimal(intervalDays: 7, baseline: baseline);

    await pumpPageWithNavigation(
      tester,
      animalId: animalId,
      now: () => DateTime(2026, 9, 12, 18),
    );

    final reminderSwitch = tester.widget<SwitchListTile>(
      find.byKey(const Key('feeding-reminder-enabled-switch')),
    );
    final intervalField = find.byKey(
      const Key('feeding-reminder-interval-days-field'),
    );

    expect(reminderSwitch.value, isTrue);
    expect(tester.widget<TextFormField>(intervalField).controller!.text, '7');

    await tester.enterText(intervalField, '10');
    await tester.tap(find.byKey(const Key('save-feeding-reminder-button')));
    await tester.pumpAndSettle();

    final animal = await AnimalRepository(database).getAnimalById(animalId);

    expect(animal!.feedingReminderIntervalDays, 10);
    expect(animal.feedingReminderBaseline, baseline);
  });

  testWidgets('disabling a reminder clears its persisted configuration', (
    tester,
  ) async {
    final animalId = await createAnimal(
      intervalDays: 7,
      baseline: DateTime(2026, 9, 1, 9),
    );

    await pumpPageWithNavigation(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pump();

    expect(
      find.byKey(const Key('feeding-reminder-interval-days-field')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('save-feeding-reminder-button')));
    await tester.pumpAndSettle();

    final animal = await AnimalRepository(database).getAnimalById(animalId);

    expect(animal!.feedingReminderIntervalDays, isNull);
    expect(animal.feedingReminderBaseline, isNull);
  });

  testWidgets('does not expose reminder controls for an archived Animal', (
    tester,
  ) async {
    final animalId = await createAnimal(
      intervalDays: 7,
      baseline: DateTime(2026, 9, 1, 9),
    );
    await AnimalRepository(database).archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 12),
    );

    await pumpPage(tester, animalId: animalId);

    expect(find.text('Archived animals cannot be edited'), findsOneWidget);
    expect(
      find.byKey(const Key('feeding-reminder-enabled-switch')),
      findsNothing,
    );
  });
}
