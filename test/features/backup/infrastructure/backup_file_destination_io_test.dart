import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/features/backup/infrastructure/backup_file_destination_io.dart';
import 'package:terramanager/features/settings/app_accent.dart';

void main() {
  late AppDatabase database;
  late Directory testDirectory;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    testDirectory = await Directory.systemTemp.createTemp('tm-spool-test-');
  });

  tearDown(() async {
    await database.close();
    await testDirectory.delete(recursive: true);
  });

  Future<Directory> createSpool() =>
      Directory('${testDirectory.path}${Platform.pathSeparator}spool').create();

  test('native save receives a valid archive and removes the spool', () async {
    final saved = await saveGeneratedBackupToFile(
      (output) => BackupExportService(database).writeBackup(
        appVersion: 'test',
        themeMode: ThemeMode.system,
        accent: AppAccent.green,
        output: output,
      ),
      createTemporaryDirectory: createSpool,
      saveFromPath: (name, path) async {
        expect(name, endsWith('.tmbackup'));
        final validated = BackupValidationService().validate(
          await File(path).readAsBytes(),
        );
        expect(validated.boxCount, 0);
        return 'saved';
      },
    );
    expect(saved, 'saved');
    expect(await Directory('${testDirectory.path}/spool').exists(), isFalse);
  });

  test('protected native save spools only authenticated ciphertext', () async {
    final saved = await saveGeneratedEncryptedBackupToFile(
      (output) => BackupExportService(database).writeBackup(
        appVersion: 'test',
        themeMode: ThemeMode.system,
        accent: AppAccent.green,
        output: output,
      ),
      password: 'private test password',
      createTemporaryDirectory: createSpool,
      saveFromPath: (name, path) async {
        expect(name, endsWith('.tmbackup'));
        final bytes = await File(path).readAsBytes();
        expect(bytes.sublist(0, 8), EncryptedBackupContainer.magic);
        final plain = await EncryptedBackupContainer.decryptBytes(
          bytes,
          password: 'private test password',
        );
        expect(BackupValidationService().validate(plain).boxCount, 0);
        return 'saved';
      },
    );
    expect(saved, 'saved');
    expect(await Directory('${testDirectory.path}/spool').exists(), isFalse);
  });

  test('cancelled save removes the unencrypted spool', () async {
    final saved = await saveGeneratedBackupToFile(
      (output) => BackupExportService(database).writeBackup(
        appVersion: 'test',
        themeMode: ThemeMode.system,
        accent: AppAccent.green,
        output: output,
      ),
      createTemporaryDirectory: createSpool,
      saveFromPath: (_, _) async => null,
    );
    expect(saved, isNull);
    expect(await Directory('${testDirectory.path}/spool').exists(), isFalse);
  });

  test('failed export removes the unencrypted spool', () async {
    await expectLater(
      saveGeneratedBackupToFile(
        (output) async {
          output.writeBytes([1, 2, 3]);
          throw StateError('export failed');
        },
        createTemporaryDirectory: createSpool,
        saveFromPath: (_, _) async => fail('Save As must not open'),
      ),
      throwsStateError,
    );
    expect(await Directory('${testDirectory.path}/spool').exists(), isFalse);
  });
}
