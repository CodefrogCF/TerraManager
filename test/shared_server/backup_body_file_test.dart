import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tm-upload-test-');
    file = File('${directory.path}${Platform.pathSeparator}backup.spool');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'encrypted staging round trips without writing the plain body',
    () async {
      final plain = List<int>.generate(8192, (index) => index % 251);
      await writeBoundedBackupStreamToEncryptedFile(
        Stream<List<int>>.fromIterable([
          plain.sublist(0, 2000),
          plain.sublist(2000),
        ]),
        file,
        password: 'temporary server secret',
        maxBytes: plain.length,
      );

      final staged = await file.readAsBytes();
      expect(
        staged.sublist(0, EncryptedBackupContainer.magic.length),
        EncryptedBackupContainer.magic,
      );
      expect(staged.sublist(0, plain.length), isNot(plain));
      final result = BytesBuilder(copy: false);
      await for (final chunk in EncryptedBackupContainer.decryptStream(
        file.openRead(),
        password: 'temporary server secret',
      )) {
        result.add(chunk);
      }
      expect(result.takeBytes(), plain);
    },
  );

  test('encrypted staging removes an oversized partial file', () async {
    await expectLater(
      writeBoundedBackupStreamToEncryptedFile(
        Stream<List<int>>.fromIterable([
          [1, 2, 3],
          [4, 5],
        ]),
        file,
        password: 'temporary server secret',
        maxBytes: 4,
      ),
      throwsA(isA<ApiProblem>().having((error) => error.status, 'status', 413)),
    );
    expect(await file.exists(), isFalse);
  });

  test('encrypted staging removes a failed upload', () async {
    await expectLater(
      writeBoundedBackupStreamToEncryptedFile(
        Stream<List<int>>.multi((controller) {
          controller.add([1, 2]);
          controller.addError(StateError('upload stopped'));
          controller.close();
        }),
        file,
        password: 'temporary server secret',
        maxBytes: 4,
      ),
      throwsStateError,
    );
    expect(await file.exists(), isFalse);
  });
}
