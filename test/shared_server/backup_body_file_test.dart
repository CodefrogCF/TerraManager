import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tm-upload-test-');
    file = File('${directory.path}${Platform.pathSeparator}backup.tmbackup');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('writes a chunked backup up to the configured limit', () async {
    await writeBoundedBackupStreamToFile(
      Stream<List<int>>.fromIterable([
        [1, 2],
        [3, 4],
      ]),
      file,
      maxBytes: 4,
    );

    expect(await file.readAsBytes(), [1, 2, 3, 4]);
  });

  test(
    'rejects a later chunk that exceeds the limit and closes the file',
    () async {
      await expectLater(
        writeBoundedBackupStreamToFile(
          Stream<List<int>>.fromIterable([
            [1, 2, 3],
            [4, 5],
          ]),
          file,
          maxBytes: 4,
        ),
        throwsA(
          isA<ApiProblem>()
              .having((error) => error.status, 'status', 413)
              .having((error) => error.code, 'code', 'too_large'),
        ),
      );

      expect(await file.readAsBytes(), [1, 2, 3]);
      await file.delete();
      expect(await file.exists(), isFalse);
    },
  );

  test('read failures release the partial file', () async {
    await expectLater(
      writeBoundedBackupStreamToFile(
        Stream<List<int>>.multi((controller) {
          controller.add([1, 2]);
          controller.addError(StateError('upload stopped'));
          controller.close();
        }),
        file,
        maxBytes: 4,
      ),
      throwsStateError,
    );

    await file.delete();
    expect(await file.exists(), isFalse);
  });
}
