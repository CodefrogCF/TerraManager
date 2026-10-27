import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

import 'generated/schema_v20.dart' as v20;

void main() {
  for (final shared in [false, true]) {
    test(
      'v20 adds optional fields without changing existing rows; shared=$shared',
      () async {
        final dir = await Directory.systemTemp.createTemp('tm241-migration-');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/data.sqlite');
        final old = v20.DatabaseAtV20(NativeDatabase(file));
        await old
            .into(old.boxes)
            .insert(
              v20.BoxesCompanion.insert(
                qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
              ),
            );
        final before =
            (await old.customSelect('SELECT * FROM boxes').get()).single.data;
        await old.close();
        final current = shared
            ? await openServerDatabase(file)
            : AppDatabase.test(NativeDatabase(file));
        try {
          expect(
            (await current.customSelect('SELECT * FROM boxes').get())
                .single
                .data,
            before,
          );
          expect(await CustomFieldRepository(current).templates(), isEmpty);
          await CustomFieldRepository(current).create(
            const CustomFieldTemplate(
              id: '12345678-1234-4123-8123-123456789abc',
              target: CustomFieldTarget.box,
              type: CustomFieldType.text,
              label: 'Ventilation',
            ),
          );
          expect(
            await current.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await current.close();
        }
        final reopened = AppDatabase.test(NativeDatabase(file));
        try {
          expect(
            await CustomFieldRepository(reopened).templates(),
            hasLength(1),
          );
        } finally {
          await reopened.close();
        }
      },
    );
  }
}
