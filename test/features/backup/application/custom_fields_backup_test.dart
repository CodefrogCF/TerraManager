import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/backup/application/portable_backup_exporter.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/domain/backup_settings.dart';

import 'custom_care_types_backup_test.dart' show rewrite;

void main() {
  for (final scope in ['personal', 'collectionOnly']) {
    test(
      '$scope roundtrip keeps all types, hidden/archived values and stable IDs',
      () async {
        final source = AppDatabase.test(NativeDatabase.memory()),
            target = AppDatabase.test(NativeDatabase.memory());
        addTearDown(() async {
          await source.close();
          await target.close();
        });
        final repo = CustomFieldRepository(source);
        final box = await BoxRepository(source).createBoxWithGeneratedQrId();
        for (final kind in CustomFieldType.values) {
          final id = '${kind.index + 1}2345678-1234-4123-8123-123456789abc';
          await repo.create(
            CustomFieldTemplate(
              id: id,
              target: CustomFieldTarget.box,
              type: kind,
              label: kind.name,
            ),
          );
          final state = await repo.snapshot(CustomFieldTarget.box, box);
          final value = switch (kind) {
            CustomFieldType.text => 'Übersicht\nNotes',
            CustomFieldType.number => 0.0,
            CustomFieldType.date => '2024-02-29',
            CustomFieldType.boolean => false,
          };
          await repo.save(
            CustomFieldTarget.box,
            box,
            CustomFieldPatch(
              expectedRevision: state.revision,
              updates: [(id: id, templateRevision: 1, value: value)],
            ),
          );
          await repo.update(
            CustomFieldTemplate(
              id: id,
              target: CustomFieldTarget.box,
              type: kind,
              label: kind.name,
              hidden: kind == CustomFieldType.text,
              archived: kind == CustomFieldType.boolean,
            ),
          );
        }
        final before = await repo.snapshot(CustomFieldTarget.box, box);
        final bytes =
            (await PortableBackupExporter(
                  source,
                  mediaReader: (_) async => Uint8List(0),
                ).createBackup(
                  appVersion: '1.17.0',
                  settings: BackupSettings(
                    scope: scope,
                    themeMode: 'system',
                    accent: 'green',
                  ),
                ))
                .bytes;
        final encrypted = await EncryptedBackupContainer.encryptBytes(
          bytes,
          password: 'local custom-field test password',
        );
        final decrypted = await EncryptedBackupContainer.decryptBytes(
          encrypted,
          password: 'local custom-field test password',
        );
        final validated = BackupValidationService().validate(decrypted);
        await PortableBackupDatabaseRestorer(target).restore(validated);
        expect(
          jsonEncode(
            (await CustomFieldRepository(
              target,
            ).snapshot(CustomFieldTarget.box, box)).toJson(),
          ),
          jsonEncode(before.toJson()),
        );
        for (final mutate in <void Function(Map<String, dynamic>)>[
          (d) => (d['customFieldValues'] as List).first['boxId'] = 99999,
          (d) => (d['customFieldValues'] as List).first['value'] = 123,
          (d) => (d['customFieldTemplates'] as List).add(
            (d['customFieldTemplates'] as List).first,
          ),
        ]) {
          expect(
            () => BackupValidationService().validate(rewrite(bytes, mutate)),
            throwsException,
          );
        }
        final legacy = rewrite(bytes, (d) {
          d.remove('customFieldTemplates');
          d.remove('customFieldValues');
        });
        await PortableBackupDatabaseRestorer(target)
            .restore(BackupValidationService().validate(legacy));
        expect(await CustomFieldRepository(target).templates(), isEmpty);
      },
    );
  }
}
