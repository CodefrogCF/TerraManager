import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/box_care_reminder_repository.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/care_event_type_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/features/boxes/domain/box_care_reminder.dart';

void main() {
  late AppDatabase database;
  late BoxRepository boxes;
  late BoxCareRepository care;
  late BoxCareReminderRepository reminders;
  late int box;
  const custom = '11111111-1111-4111-8111-111111111111';

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    boxes = BoxRepository(database);
    care = BoxCareRepository(database);
    reminders = BoxCareReminderRepository(database);
    box = await boxes.createBoxWithGeneratedQrId();
  });
  tearDown(() => database.close());

  test(
    'only a newly recorded matching task changes its Box schedule',
    () async {
      final other = await boxes.createBoxWithGeneratedQrId();
      final date = DateTime.utc(2024, 4, 5);
      await reminders.save(boxId: box, typeKey: 'cleaning', dueOn: date);
      await reminders.save(boxId: other, typeKey: 'cleaning', dueOn: date);
      await reminders.save(
        boxId: box,
        typeKey: 'waterChange',
        dueOn: date,
        intervalDays: 4,
      );

      final at = DateTime.utc(2024, 3, 30, 23, 30);
      await care.add(
        boxId: box,
        type: BoxCareEventType.substrateChange,
        occurredAt: at,
      );
      expect(await reminders.forBox(box), hasLength(2));
      await care.add(
        boxId: box,
        type: BoxCareEventType.cleaning,
        occurredAt: at,
      );
      expect((await reminders.forBox(box)).single.typeKey, 'waterChange');
      expect((await reminders.forBox(other)).single.dueOn, date);

      final occurredOn = DateTime.utc(2024, 3, 31);
      Future<({int id, bool replayed, bool reminderChanged})> record() =>
          care.addWithResult(
            boxId: box,
            type: BoxCareEventType.waterChange,
            occurredAt: at,
            occurredOn: occurredOn,
            requestId: 'water-retry',
          );
      expect((await record()).reminderChanged, isTrue);
      final scheduled = (await reminders.forBox(box)).single;
      expect(scheduled.dueOn, DateTime.utc(2024, 4, 4));
      expect(scheduled.lastCompletedOn, occurredOn);
      expect(scheduled.isDue(DateTime(2024, 4, 3, 23, 59)), isFalse);
      expect(scheduled.isDue(DateTime(2024, 4, 4)), isTrue);
      expect((await record()).replayed, isTrue);
      await care.add(
        boxId: box,
        type: BoxCareEventType.waterChange,
        occurredAt: at,
      );
      expect((await reminders.forBox(box)).single.revision, scheduled.revision);
      expect(await care.history(box), hasLength(4));
    },
  );

  test(
    'archive suppresses reminders and edits use current revisions',
    () async {
      final types = CareEventTypeRepository(database);
      var type = await types.create(custom, 'Check ventilation');
      final date = DateTime.utc(2024, 5, 1);
      await reminders.save(boxId: box, typeKey: custom, dueOn: date);
      final initial = (await reminders.forBox(box)).single;
      await expectLater(
        reminders.save(boxId: box, typeKey: custom, dueOn: null),
        throwsStateError,
      );
      type = await types.update(
        id: custom,
        expectedRevision: type.revision,
        label: 'Ventilation',
        archived: true,
      );
      expect(await reminders.nextDueDates(), isEmpty);
      await expectLater(
        reminders.save(
          boxId: box,
          typeKey: custom,
          dueOn: date,
          expectedRevision: initial.revision,
        ),
        throwsArgumentError,
      );
      await types.update(
        id: custom,
        expectedRevision: type.revision,
        label: type.label,
        archived: false,
      );
      expect(await reminders.nextDueDates(), {box: date});
      await boxes.archiveBox(
        boxId: box,
        reason: BoxArchiveReason.stored,
        archivedAt: date,
      );
      expect(await reminders.nextDueDates(), isEmpty);
      expect((await reminders.forBox(box)).single.revision, initial.revision);
      await boxes.restoreBox(box);
      final edited = DateTime.utc(2024, 5, 2);
      await reminders.save(
        boxId: box,
        typeKey: custom,
        dueOn: edited,
        intervalDays: 7,
        expectedRevision: initial.revision,
      );
      expect(await reminders.nextDueDates(), {box: edited});
      await care.add(
        boxId: box,
        type: BoxCareEventType.custom,
        customTypeId: custom,
        occurredAt: DateTime.utc(2024, 5, 2, 15),
      );
      final next = (await reminders.forBox(box)).single;
      expect(next.dueOn, DateTime.utc(2024, 5, 9));
      await reminders.save(
        boxId: box,
        typeKey: custom,
        dueOn: null,
        expectedRevision: next.revision,
      );
      expect(await reminders.nextDueDates(), isEmpty);
    },
  );

  test('validates dates and interval limits', () async {
    expect(() => BoxCareReminder.parseDay('2024-02-30'), throwsFormatException);
    expect(
      () => BoxCareReminder.parseDay('2024-02-29T00:00:00Z'),
      throwsFormatException,
    );
    for (final interval in [0, -1, 36501]) {
      await expectLater(
        reminders.save(
          boxId: box,
          typeKey: 'cleaning',
          dueOn: DateTime.utc(2024),
          intervalDays: interval,
        ),
        throwsArgumentError,
      );
    }
    expect(await reminders.forBox(box), isEmpty);
  });
}
