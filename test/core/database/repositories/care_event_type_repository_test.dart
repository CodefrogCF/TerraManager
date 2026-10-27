import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/care_event_type_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';

const first = '12345678-1234-4123-8123-123456789abc';
const second = '22345678-1234-4123-8123-123456789abc';
void main() {
  late AppDatabase db;
  late CareEventTypeRepository types;
  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    types = CareEventTypeRepository(db);
  });
  tearDown(() => db.close());
  test('labels normalize whitespace and reject controls, reserved names and duplicates including archived', () async {
    final type = await types.create(first, '  Lüftung   prüfen  ');
    expect(type.label, 'Lüftung prüfen');
    for (final invalid in [
      '',
      'Reinigung',
      'CLEANING',
      'line\nbreak',
      '\u200b',
      '\u2028',
      'x' * 81,
    ]) {
      await expectLater(types.create(second, invalid), throwsArgumentError);
    }
    await expectLater(types.create(second, 'LÜFTUNG prüfen'), throwsStateError);
    await types.update(
      id: type.id,
      expectedRevision: type.revision,
      label: type.label,
      archived: true,
    );
    await expectLater(types.create(second, type.label), throwsStateError);
    await expectLater(
      types.create('not-an-id', 'Valid label'),
      throwsArgumentError,
    );
    expect(await types.all(), hasLength(1));
  });
  test(
    'create retries are idempotent and conflicting UUID reuse is rejected',
    () async {
      final type = await types.create(first, 'Ventilation');
      expect(
        (await types.create(first, 'Ventilation')).toJson(),
        type.toJson(),
      );
      await expectLater(types.create(first, 'Different'), throwsStateError);
      expect(await types.all(), hasLength(1));
    },
  );
  test('rename and archive preserve entry identity; archived type can only be retained on an existing event', () async {
    final box = await BoxRepository(db).createBoxWithGeneratedQrId();
    final care = BoxCareRepository(db);
    final type = await types.create(first, 'Ventilation');
    final id = await care.add(
      boxId: box,
      type: BoxCareEventType.custom,
      customTypeId: first,
      occurredAt: DateTime.utc(2026),
      notes: 'Before rename',
      requestId: 'care-retry',
    );
    final renamed = await types.update(
      id: first,
      expectedRevision: type.revision,
      label: 'Check ventilation',
      archived: false,
    );
    await expectLater(
      types.update(
        id: first,
        expectedRevision: type.revision,
        label: 'Stale',
        archived: false,
      ),
      throwsStateError,
    );
    final archived = await types.update(
      id: first,
      expectedRevision: renamed.revision,
      label: renamed.label,
      archived: true,
    );
    var event = (await care.history(box)).single;
    expect(event.id, id);
    expect(event.customTypeId, first);
    expect(event.notes, 'Before rename');
    expect(
      await care.add(
        boxId: box,
        type: BoxCareEventType.custom,
        customTypeId: first,
        occurredAt: DateTime.utc(2026),
        notes: 'Before rename',
        requestId: 'care-retry',
      ),
      id,
    );
    await expectLater(
      care.add(
        boxId: box,
        type: BoxCareEventType.custom,
        customTypeId: first,
        occurredAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      await care.update(
        boxId: box,
        id: event.id,
        expectedRevision: event.revision,
        expectedRequestId: event.requestId,
        type: event.type,
        customTypeId: first,
        occurredAt: event.occurredAt,
        notes: 'After archive',
      ),
      true,
    );
    event = (await care.history(box)).single;
    expect(event.customTypeId, first);
    expect(event.notes, 'After archive');
    await types.update(
      id: first,
      expectedRevision: archived.revision,
      label: archived.label,
      archived: false,
    );
    await care.add(
      boxId: box,
      type: BoxCareEventType.custom,
      customTypeId: first,
      occurredAt: DateTime.utc(2026),
    );
    expect(await care.history(box), hasLength(2));
  });
  test(
    'unknown types and mixed built-in/custom references never enter history',
    () async {
      final box = await BoxRepository(db).createBoxWithGeneratedQrId();
      final care = BoxCareRepository(db);
      await expectLater(
        care.add(
          boxId: box,
          type: BoxCareEventType.custom,
          occurredAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      await expectLater(
        care.add(
          boxId: box,
          type: BoxCareEventType.custom,
          customTypeId: first,
          occurredAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      await types.create(first, 'Ventilation');
      await expectLater(
        care.add(
          boxId: box,
          type: BoxCareEventType.cleaning,
          customTypeId: first,
          occurredAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      expect(await care.history(box), isEmpty);
      final id = await care.add(
        boxId: box,
        type: BoxCareEventType.custom,
        customTypeId: first,
        occurredAt: DateTime.utc(2026),
      );
      final event = (await care.history(box)).single;
      expect(
        await care.update(
          boxId: box,
          id: id,
          expectedRevision: event.revision,
          expectedRequestId: event.requestId,
          type: BoxCareEventType.cleaning,
          occurredAt: event.occurredAt,
        ),
        true,
      );
      expect((await care.history(box)).single.customTypeId, isNull);
    },
  );
  test(
    'reordering checks complete revision set and never changes event identity',
    () async {
      final a = await types.create(first, 'Ventilation');
      final b = await types.create(second, 'Light check');
      await types.reorder([
        (id: b.id, revision: b.revision),
        (id: a.id, revision: a.revision),
      ]);
      expect((await types.all()).map((t) => t.id), [second, first]);
      await expectLater(
        types.reorder([
          (id: a.id, revision: a.revision),
          (id: b.id, revision: b.revision),
        ]),
        throwsStateError,
      );
      final current = await types.all();
      await expectLater(
        types.reorder([
          (id: current.first.id, revision: current.first.revision),
        ]),
        throwsStateError,
      );
      await expectLater(
        types.reorder([
          (id: current.first.id, revision: current.first.revision),
          (id: current.first.id, revision: current.first.revision),
        ]),
        throwsStateError,
      );
      expect((await types.all()).map((t) => t.id), [second, first]);
    },
  );
  test('SQLite protects custom history from deleting definitions or mixing type references', () async {
    final box = await BoxRepository(db).createBoxWithGeneratedQrId();
    await types.create(first, 'Ventilation');
    await BoxCareRepository(db).add(
      boxId: box,
      type: BoxCareEventType.custom,
      customTypeId: first,
      occurredAt: DateTime.utc(2026),
    );
    await expectLater(
      db.customStatement('DELETE FROM care_event_types WHERE id = ?', [first]),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement("UPDATE box_care_events SET type = 'cleaning'"),
      throwsA(anything),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
