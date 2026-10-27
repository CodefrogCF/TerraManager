import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/care_event_type_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

import 'generated/schema_v19.dart' as v19;

void main() {
  for (final shared in [false, true]) {
    test(
      'v19 to v20 preserves existing care history and adds custom types; shared=$shared',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'tm240-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/collection.sqlite');
        final old = v19.DatabaseAtV19(NativeDatabase(file));
        final box = await old
            .into(old.boxes)
            .insert(
              v19.BoxesCompanion.insert(
                qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
              ),
            );
        await old.customStatement(
          "INSERT INTO box_care_events (box_id, type, occurred_at, notes, request_id, revision, created_at, updated_at) VALUES (?, 'cleaning', 1710000000, 'Existing note', 'stable-key', 7, 1710000000, 1710000000)",
          [box],
        );
        const columns =
            'id, box_id, type, occurred_at, notes, request_id, revision, created_at, updated_at';
        final before =
            (await old
                    .customSelect('SELECT $columns FROM box_care_events')
                    .get())
                .single
                .data;
        await old.close();
        final current = shared
            ? await openServerDatabase(file)
            : AppDatabase.test(NativeDatabase(file));
        try {
          expect(
            (await current
                    .customSelect('SELECT $columns FROM box_care_events')
                    .get())
                .single
                .data,
            before,
          );
          final existing = (await BoxCareRepository(current).history(box))
              .single;
          expect(existing.type, BoxCareEventType.cleaning);
          expect(existing.customTypeId, isNull);
          expect(existing.revision, 7);
          final types = CareEventTypeRepository(current);
          expect(await types.all(), isEmpty);
          const id = '12345678-1234-4123-8123-123456789abc';
          await types.create(id, 'Ventilation');
          await BoxCareRepository(current).add(
            boxId: box,
            type: BoxCareEventType.custom,
            customTypeId: id,
            occurredAt: DateTime.utc(2026),
          );
          expect(await BoxCareRepository(current).history(box), hasLength(2));
          expect(
            await current.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await current.close();
        }
        final reopened = AppDatabase.test(NativeDatabase(file));
        try {
          expect(await CareEventTypeRepository(reopened).all(), hasLength(1));
          expect(await BoxCareRepository(reopened).history(box), hasLength(2));
        } finally {
          await reopened.close();
        }
      },
    );
  }
}
