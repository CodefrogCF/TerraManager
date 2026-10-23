import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/app.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/feedings/application/feeding_reminder_service.dart';
import 'package:terramanager/features/notifications/domain/feeding_notification_target.dart';

import 'feeding_notification_controller_test.dart' show FakeNotificationGateway;

void main() {
  late AppDatabase database;
  late FakeNotificationGateway gateway;
  late FeedingNotificationTarget target;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'standalone_tutorial_seen': true});
    database = AppDatabase.test(NativeDatabase.memory());
    gateway = FakeNotificationGateway();
    final boxId = await BoxRepository(database)
        .createBox('TM:BOX:72727272-7272-4272-8272-727272727272');
    final id = await database
        .into(database.animals)
        .insert(
          AnimalsCompanion.insert(
            boxId: Value(boxId),
            commonName: 'Notification Animal',
            latinName: 'Species',
            tempMin: 20,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 70,
            feedingReminderIntervalDays: const Value(3),
            feedingReminderBaseline: Value(DateTime.utc(2026, 1, 1)),
          ),
        );
    final state = (await FeedingReminderService(database)
        .getReminderStateForAnimal(id))!;
    target = FeedingNotificationTarget(
      animalId: id,
      createdAt: state.animal.createdAt,
      dueAt: state.dueAt,
    );
  });
  tearDown(() => database.close());

  testWidgets('cold tap opens Animal; later tap preserves an unsaved route', (
    tester,
  ) async {
    gateway.launchPayload = target.encode();
    await tester.pumpWidget(
      TerraManagerApp(
        database: database,
        locale: const Locale('en'),
        notificationGateway: gateway,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimalDetailPage), findsOneWidget);
    expect(gateway.permissionRequests, 0);
    gateway.onTap!(target.encode());
    await tester.pumpAndSettle();
    expect(find.byType(AnimalDetailPage, skipOffstage: false), findsOneWidget);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await (database.update(
      database.animals,
    )..where((animal) => animal.id.equals(target.animalId))).write(
      const AnimalsCompanion(commonName: Value('Updated from reminder')),
    );
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Animals').last);
    await tester.pumpAndSettle();
    expect(find.text('Updated from reminder'), findsWidgets);
    expect(find.text('Notification Animal'), findsNothing);
    final draft = TextEditingController(text: 'Keep this draft');
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Draft')),
          body: TextField(
            key: const Key('notification-draft'),
            controller: draft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    gateway.onTap!(target.encode());
    await tester.pumpAndSettle();
    expect(find.byType(AnimalDetailPage), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification-draft')), findsOneWidget);
    expect(draft.text, 'Keep this draft');
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Updated from reminder'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    draft.dispose();
  });

  testWidgets(
    'stale cold tap keeps the collection open and explains the fallback',
    (tester) async {
      gateway.launchPayload = FeedingNotificationTarget(
        animalId: 999,
        createdAt: target.createdAt,
        dueAt: target.dueAt,
      ).encode();
      await tester.pumpWidget(
        TerraManagerApp(
          database: database,
          locale: const Locale('en'),
          notificationGateway: gateway,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimalDetailPage), findsNothing);
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(gateway.permissionRequests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
