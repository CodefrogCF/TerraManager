import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/feedings/domain/feeding_alert_suppression.dart';
import 'package:terramanager/features/notifications/application/feeding_notification_controller.dart';
import 'package:terramanager/features/notifications/application/local_notification_gateway.dart';
import 'package:terramanager/features/notifications/domain/feeding_notification_target.dart';
import 'package:terramanager/features/notifications/infrastructure/local_notification_store.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

class MemoryNotificationStore implements LocalNotificationStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('storage unavailable');
    this.value = value;
  }
}

class ScheduledAlert {
  ScheduledAlert(this.id, this.at, this.language, this.target);
  final int id;
  final DateTime at;
  final String language;
  final FeedingNotificationTarget target;
}

class FakeNotificationGateway implements LocalNotificationGateway {
  bool supported = true;
  bool allowed = true;
  bool failScheduling = false;
  int permissionRequests = 0;
  int initializations = 0;
  int scheduleCalls = 0;
  int settingsOpened = 0;
  final Map<int, ScheduledAlert> pending = {};
  final Set<int> cancelled = {};
  void Function(String?)? onTap;
  String? launchPayload;
  void Function()? afterSchedule;
  @override
  bool get isSupported => supported;
  @override
  Future<void> initialize(void Function(String?) onTap) async {
    initializations++;
    this.onTap = onTap;
    if (launchPayload != null) onTap(launchPayload);
  }

  @override
  Future<bool> isAllowed() async => allowed;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelled.addAll(pending.keys);
    pending.clear();
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String languageCode,
    required FeedingNotificationTarget target,
  }) async {
    if (failScheduling) throw StateError('OS alarm limit');
    scheduleCalls++;
    pending[id] = ScheduledAlert(id, at, languageCode, target);
    afterSchedule?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late MemoryNotificationStore store;
  late FakeNotificationGateway gateway;
  late FeedingNotificationController controller;
  late DateTime now;
  final created = DateTime.utc(2026, 1, 1);
  final opened = <int>[];
  var unavailable = 0;

  FeedingNotificationController makeController() =>
      FeedingNotificationController(
        database: database,
        gateway: gateway,
        store: store,
        now: () => now,
        onOpenAnimal: opened.add,
        onUnavailableTarget: () => unavailable++,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
    store = MemoryNotificationStore();
    gateway = FakeNotificationGateway();
    now = DateTime.utc(2026, 10, 20, 12);
    opened.clear();
    unavailable = 0;
    controller = makeController();
  });
  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  Future<int> animal({
    DateTime? baseline,
    int? weekdays,
    int minute = 18 * 60,
    String zone = 'Europe/Berlin',
  }) => database
      .into(database.animals)
      .insert(
        AnimalsCompanion.insert(
          commonName: 'Private Animal',
          latinName: 'Private species',
          tempMin: 20,
          tempMax: 30,
          humidityMin: 50,
          humidityMax: 70,
          createdAt: Value(created),
          feedingReminderIntervalDays: weekdays == null
              ? const Value(2)
              : const Value(null),
          feedingReminderBaseline: Value(baseline ?? now),
          feedingReminderWeekdays: Value(weekdays),
          feedingReminderMinuteOfDay: weekdays == null
              ? const Value(null)
              : Value(minute),
          feedingReminderTimeZone: weekdays == null
              ? const Value(null)
              : Value(zone),
        ),
      );

  Future<void> updateAnimal(int id, AnimalsCompanion value) => (database.update(
    database.animals,
  )..where((row) => row.id.equals(id))).write(value);

  Future<void> eventually(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(condition(), isTrue);
    await controller.refresh();
  }

  test(
    'default off and unsupported clients never request permission',
    () async {
      await animal();
      await controller.start();
      expect(controller.enabled, isFalse);
      expect(gateway.permissionRequests, 0);
      expect(gateway.pending, isEmpty);
      controller.dispose();
      gateway = FakeNotificationGateway()..supported = false;
      controller = makeController();
      await controller.start();
      await controller.setEnabled(true);
      expect(gateway.initializations, 0);
      expect(gateway.permissionRequests, 0);
      expect(store.value, isNotNull);
      expect(jsonDecode(store.value!)['enabled'], false);
    },
  );

  test(
    'permission denial leaves in-app reminder configuration unchanged',
    () async {
      final id = await animal();
      gateway.allowed = false;
      await controller.start();
      await controller.setEnabled(true);
      expect(controller.enabled, false);
      expect(controller.permissionBlocked, true);
      expect(gateway.permissionRequests, 1);
      expect(gateway.pending, isEmpty);
      expect(
        (await database.select(database.animals).getSingle())
            .feedingReminderIntervalDays,
        2,
      );
      await controller.openSettings();
      expect(gateway.settingsOpened, 1);
      gateway.allowed = true;
      await controller.setEnabled(true);
      expect(gateway.pending.values.single.target.animalId, id);
    },
  );

  test('interval schedules once; restart and resume renew pending without prompting', () async {
    await animal();
    await controller.start();
    await controller.setEnabled(true);
    expect(gateway.pending.values.single.at, now.add(const Duration(days: 2)));
    await controller.refresh();
    expect(gateway.scheduleCalls, 1);
    controller.dispose();
    controller = makeController();
    await controller.start();
    expect(controller.enabled, true);
    expect(gateway.permissionRequests, 1);
    expect(gateway.pending, hasLength(1));
    expect(gateway.scheduleCalls, 2);
  });

  test('delivered overdue appointment stays consumed across restart language and clock changes', () async {
    await animal(baseline: now.subtract(const Duration(days: 3)));
    await controller.start();
    await controller.setEnabled(true);
    expect(
      gateway.pending.values.single.at,
      now.add(const Duration(seconds: 5)),
    );
    gateway.pending
        .clear(); // Android delivered and removed the one-shot alarm.
    controller.dispose();
    controller = makeController();
    await controller.start();
    await controller.setLanguage('de');
    now = now.subtract(const Duration(days: 10));
    await controller.refresh(renew: true);
    expect(gateway.pending, isEmpty);
    expect(gateway.scheduleCalls, 1);
  });

  test(
    'feeding create edit and delete automatically reconcile after commit',
    () async {
      final id = await animal();
      await controller.start();
      await controller.setEnabled(true);
      final feedings = FeedingRepository(database);
      final fedAt = now.add(const Duration(hours: 1));
      final feeding = await feedings.addFeeding(id, fedAt);
      await eventually(
        () =>
            gateway.pending.values.single.at ==
            fedAt.add(const Duration(days: 2)),
      );
      await feedings.updateFeeding(
        feedingId: feeding,
        fedAt: now.add(const Duration(hours: 2)),
      );
      await eventually(
        () =>
            gateway.pending.values.single.at ==
            now.add(const Duration(days: 2, hours: 2)),
      );
      await feedings.deleteFeeding(feeding);
      await eventually(
        () =>
            gateway.pending.values.single.at ==
            now.add(const Duration(days: 2)),
      );
    },
  );

  test('rolled back feeding cannot change a scheduled appointment', () async {
    final id = await animal();
    await controller.start();
    await controller.setEnabled(true);
    final before = gateway.scheduleCalls;
    await expectLater(
      database.transaction(() async {
        await FeedingRepository(database)
            .addFeeding(id, now.add(const Duration(hours: 1)));
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    await controller.refresh();
    expect(gateway.scheduleCalls, before);
    expect(gateway.pending.values.single.at, now.add(const Duration(days: 2)));
  });

  test(
    'reminder edit cancellation archive restore and deletion update alarms',
    () async {
      final id = await animal();
      await controller.start();
      await controller.setEnabled(true);
      await updateAnimal(
        id,
        const AnimalsCompanion(feedingReminderIntervalDays: Value(3)),
      );
      await eventually(
        () =>
            gateway.pending.values.single.at ==
            now.add(const Duration(days: 3)),
      );
      await updateAnimal(
        id,
        const AnimalsCompanion(status: Value(AnimalStatus.archived)),
      );
      await eventually(() => gateway.pending.isEmpty);
      await updateAnimal(
        id,
        const AnimalsCompanion(status: Value(AnimalStatus.active)),
      );
      await eventually(() => gateway.pending.isNotEmpty);
      await updateAnimal(
        id,
        const AnimalsCompanion(
          feedingReminderIntervalDays: Value(null),
          feedingReminderBaseline: Value(null),
        ),
      );
      await eventually(() => gateway.pending.isEmpty);
      await updateAnimal(
        id,
        AnimalsCompanion(
          feedingReminderIntervalDays: const Value(2),
          feedingReminderBaseline: Value(now),
        ),
      );
      await eventually(() => gateway.pending.isNotEmpty);
      await (database.delete(
        database.animals,
      )..where((row) => row.id.equals(id))).go();
      await eventually(() => gateway.pending.isEmpty);
    },
  );

  test('device opt-out cancels everything; OS revocation is recovered without a prompt', () async {
    await animal();
    await controller.start();
    await controller.setEnabled(true);
    gateway.allowed = false;
    await controller.refresh();
    expect(controller.enabled, true);
    expect(controller.permissionBlocked, true);
    expect(gateway.pending, isEmpty);
    gateway.allowed = true;
    await controller.refresh();
    expect(gateway.pending, hasLength(1));
    expect(gateway.permissionRequests, 1);
    await controller.setEnabled(false);
    expect(gateway.pending, isEmpty);
    expect(jsonDecode(store.value!)['deliveries'], isEmpty);
  });

  test(
    '24 hour in-app suppression does not mute or cancel device notifications',
    () async {
      final id = await animal(baseline: now.subtract(const Duration(days: 3)));
      await controller.start();
      await controller.setEnabled(true);
      final settings = AppSettingsController(now: () => now);
      addTearDown(settings.dispose);
      await settings.load();
      await settings.suppressFeedingAlertFor24Hours(
        feedingAlertAnimalKey(id, created),
      );
      await controller.refresh();
      expect(gateway.pending, hasLength(1));
      expect(gateway.scheduleCalls, 1);
    },
  );

  test(
    'pending alerts are relocalized without duplicating consumed appointments',
    () async {
      await animal();
      await controller.start();
      await controller.setEnabled(true);
      await controller.setLanguage('de');
      expect(gateway.pending, hasLength(1));
      expect(gateway.pending.values.single.language, 'de');
      expect(gateway.permissionRequests, 1);
    },
  );

  for (final (baseline, weekdays, due) in [
    (DateTime.utc(2026, 3, 28, 12), 64, DateTime.utc(2026, 3, 29, 16)),
    (DateTime.utc(2026, 10, 24, 12), 64, DateTime.utc(2026, 10, 25, 17)),
  ]) {
    test(
      'weekday timezone survives DST and host clock representation: $due',
      () async {
        now = baseline;
        final id = await animal(baseline: baseline, weekdays: weekdays);
        await controller.start();
        await controller.setEnabled(true);
        expect(gateway.pending.values.single.at, due);
        now = now.toLocal();
        await controller.refresh(renew: true);
        expect(gateway.pending.values.single.at, due);
        await FeedingRepository(database)
            .addFeeding(id, due.subtract(const Duration(hours: 1)));
        await eventually(
          () =>
              gateway.pending.length == 1 &&
              gateway.pending.values.single.at.isAfter(due),
        );
        expect(
          gateway.pending.values.single.at,
          due.add(const Duration(days: 7)),
        );
      },
    );
  }

  test(
    'tap validates appointment and record identity before opening local Animal',
    () async {
      final id = await animal();
      await controller.start();
      await controller.setEnabled(true);
      final target = gateway.pending.values.single.target;
      await controller.openPayload(target.encode());
      expect(opened, [id]);
      await controller.openPayload('{"collection":"shared"}');
      expect(unavailable, 1);
      await updateAnimal(
        id,
        AnimalsCompanion(
          createdAt: Value(created.add(const Duration(days: 1))),
        ),
      );
      await controller.openPayload(target.encode());
      expect(opened, [id]);
      expect(unavailable, 2);
      await controller.openPayload('x' * 513);
      expect(unavailable, 3);
    },
  );

  test('scheduling failures remain visible and retryable, including multiple Animals', () async {
    await animal();
    await animal();
    gateway.failScheduling = true;
    await controller.start();
    await controller.setEnabled(true);
    expect(controller.failed, true);
    expect(gateway.pending, isEmpty);
    gateway.failScheduling = false;
    await controller.refresh();
    expect(controller.failed, false);
    expect(gateway.pending, hasLength(2));
    expect(gateway.pending.keys.toSet(), hasLength(2));
  });

  test('failed delivery persistence cancels the unrecorded alarm and permits retry', () async {
    await animal();
    await controller.start();
    gateway.afterSchedule = () => store.fail = true;
    await controller.setEnabled(true);
    expect(controller.failed, true);
    expect(gateway.pending, isEmpty);
    gateway.afterSchedule = null;
    store.fail = false;
    await controller.refresh();
    expect(controller.failed, false);
    expect(gateway.pending, hasLength(1));
  });

  test('failed opt-in persistence never schedules alarms or pretends to be enabled', () async {
    await animal();
    await controller.start();
    store.fail = true;
    await controller.setEnabled(true);
    expect(controller.failed, true);
    expect(controller.enabled, false);
    expect(gateway.pending, isEmpty);
  });
}
