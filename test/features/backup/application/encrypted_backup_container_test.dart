import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';

void main() {
  final password = 'a long local test password';

  test(
    'round trips across chunk boundaries and uses fresh salt and nonce',
    () async {
      final source = Uint8List.fromList(
        List<int>.generate(600000, (index) => index % 251),
      );
      final first = await EncryptedBackupContainer.encryptBytes(
        source,
        password: password,
      );
      final second = await EncryptedBackupContainer.encryptBytes(
        source,
        password: password,
      );
      expect(first.sublist(22, 42), isNot(second.sublist(22, 42)));
      expect(
        await EncryptedBackupContainer.decryptBytes(first, password: password),
        source,
      );
    },
  );

  test(
    'stream encryption emits bounded chunks and a complete envelope',
    () async {
      final plain = Uint8List.fromList(
        List<int>.generate(900000, (index) => index % 253),
      );
      final chunks = await EncryptedBackupContainer.encryptStream(
        Stream<List<int>>.fromIterable([
          plain.sublist(0, 400000),
          plain.sublist(400000),
        ]),
        password: password,
      ).toList();
      expect(chunks.first, hasLength(EncryptedBackupContainer.headerLength));
      expect(chunks.every((chunk) => chunk.length < 300000), isTrue);
      expect(
        await EncryptedBackupContainer.decryptBytes(
          Uint8List.fromList(chunks.expand((chunk) => chunk).toList()),
          password: password,
        ),
        plain,
      );
    },
  );

  test(
    'in-place decryption reuses the encrypted buffer across frames',
    () async {
      final source = Uint8List.fromList(
        List<int>.generate(600000, (index) => index % 251),
      );
      final encrypted = await EncryptedBackupContainer.encryptBytes(
        source,
        password: password,
      );
      final result = await EncryptedBackupContainer.decryptInPlace(
        encrypted,
        password: password,
      );
      expect(result, source);
      final first = result.first;
      result[0] ^= 1;
      expect(encrypted[0], result[0]);
      result[0] = first;
      expect(encrypted.skip(result.length).every((byte) => byte == 0), isTrue);
    },
  );

  test('in-place decryption rejects tampering and truncation', () async {
    final encrypted = await EncryptedBackupContainer.encryptBytes(
      Uint8List.fromList(List<int>.generate(320000, (i) => i % 251)),
      password: password,
    );
    // Damage the second frame, after the first has already been decrypted.
    final tampered = Uint8List.fromList(encrypted)
      ..[EncryptedBackupContainer.headerLength +
              4 +
              EncryptedBackupContainer.chunkSize +
              EncryptedBackupContainer.tagLength +
              8] ^=
          1;
    await expectLater(
      EncryptedBackupContainer.decryptInPlace(tampered, password: password),
      throwsA(
        isA<EncryptedBackupException>().having(
          (error) => error.code,
          'code',
          EncryptedBackupError.authenticationFailed,
        ),
      ),
    );
    expect(tampered.every((byte) => byte == 0), isTrue);
    final truncated = Uint8List.fromList(
      encrypted.sublist(0, encrypted.length - 1),
    );
    await expectLater(
      EncryptedBackupContainer.decryptInPlace(truncated, password: password),
      throwsA(
        isA<EncryptedBackupException>().having(
          (error) => error.code,
          'code',
          EncryptedBackupError.truncated,
        ),
      ),
    );
    expect(truncated.every((byte) => byte == 0), isTrue);
  });

  test(
    'wrong password and changed ciphertext use one authentication error',
    () async {
      final encrypted = await EncryptedBackupContainer.encryptBytes(
        Uint8List.fromList(List<int>.generate(320000, (i) => i % 251)),
        password: password,
      );
      await expectLater(
        EncryptedBackupContainer.decryptBytes(encrypted, password: 'wrong'),
        throwsA(
          isA<EncryptedBackupException>().having(
            (error) => error.code,
            'code',
            EncryptedBackupError.authenticationFailed,
          ),
        ),
      );
      final changed = Uint8List.fromList(encrypted);
      changed[60 + Random(1).nextInt(100)] ^= 1;
      await expectLater(
        EncryptedBackupContainer.decryptBytes(changed, password: password),
        throwsA(
          isA<EncryptedBackupException>().having(
            (error) => error.code,
            'code',
            EncryptedBackupError.authenticationFailed,
          ),
        ),
      );
    },
  );

  test(
    'truncation, unsupported version and appended data are rejected',
    () async {
      final encrypted = await EncryptedBackupContainer.encryptBytes(
        Uint8List.fromList([1, 2, 3]),
        password: password,
      );
      final truncated = Uint8List.sublistView(
        encrypted,
        0,
        encrypted.length - 1,
      );
      await expectLater(
        EncryptedBackupContainer.decryptBytes(truncated, password: password),
        throwsA(
          isA<EncryptedBackupException>().having(
            (error) => error.code,
            'code',
            EncryptedBackupError.truncated,
          ),
        ),
      );
      final version = Uint8List.fromList(encrypted)..[8] = 99;
      await expectLater(
        EncryptedBackupContainer.decryptBytes(version, password: password),
        throwsA(
          isA<EncryptedBackupException>().having(
            (error) => error.code,
            'code',
            EncryptedBackupError.unsupportedVersion,
          ),
        ),
      );
      final extra = Uint8List.fromList([...encrypted, 0]);
      await expectLater(
        EncryptedBackupContainer.decryptBytes(extra, password: password),
        throwsA(isA<EncryptedBackupException>()),
      );
    },
  );

  test('legacy ZIP does not match the encrypted magic', () {
    expect(
      EncryptedBackupContainer.hasEncryptedHeader([0x50, 0x4b, 0x03, 0x04]),
      isFalse,
    );
    expect(
      () => EncryptedBackupContainer.hasEncryptedHeader(
        EncryptedBackupContainer.magic.sublist(0, 4),
      ),
      throwsA(isA<EncryptedBackupException>()),
    );
  });
}
