import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/features/backup/infrastructure/encrypted_backup_file_io.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('encrypted-backup-test-');
    path = '${directory.path}${Platform.pathSeparator}backup.tmbackup';
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'ZIP entries remain random-access readable without plaintext file',
    () async {
      final output = OutputFileStream(path);
      final encrypted = await EncryptedBackupContainer.newOutput(
        output,
        password: 'test-password',
      );
      final picture = Uint8List.fromList(
        List<int>.generate(700000, (index) => index % 251),
      );
      final encoder = ZipEncoder()..startEncode(encrypted);
      encoder.add(ArchiveFile.bytes('media/picture.bin', picture));
      encoder.add(ArchiveFile.string('manifest.json', '{"format":2}'));
      encoder.endEncode();
      encrypted.finish();
      encrypted.dispose();
      await output.close();

      final reader = await EncryptedBackupFile.open(
        path,
        password: 'test-password',
      );
      try {
        final archive = ZipDecoder().decodeStream(reader.openZipStream());
        expect(archive.findFile('media/picture.bin')!.readBytes(), picture);
        expect(
          archive.findFile('manifest.json')!.readBytes(),
          Uint8List.fromList('{"format":2}'.codeUnits),
        );
        expect(
          (await File(path).readAsBytes()).sublist(0, 8),
          EncryptedBackupContainer.magic,
        );
      } finally {
        reader.close();
      }
    },
  );

  test('wrong password and modified frame fail before ZIP access', () async {
    final bytes = await EncryptedBackupContainer.encryptBytes(
      Uint8List.fromList([80, 75, 3, 4]),
      password: 'correct',
    );
    await File(path).writeAsBytes(bytes);
    await expectLater(
      EncryptedBackupFile.open(path, password: 'wrong'),
      throwsA(
        isA<EncryptedBackupException>().having(
          (error) => error.code,
          'code',
          EncryptedBackupError.authenticationFailed,
        ),
      ),
    );
    bytes[50] ^= 1;
    await File(path).writeAsBytes(bytes);
    await expectLater(
      EncryptedBackupFile.open(path, password: 'correct'),
      throwsA(
        isA<EncryptedBackupException>().having(
          (error) => error.code,
          'code',
          EncryptedBackupError.authenticationFailed,
        ),
      ),
    );
  });
}
