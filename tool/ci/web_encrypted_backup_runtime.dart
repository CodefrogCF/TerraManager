// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';

/// Runs as dart2js output in a real browser, covering more than one frame.
Future<void> main() async {
  try {
    final source = Uint8List.fromList(
      List<int>.generate(150000, (index) => index % 251),
    );
    const password = 'web runtime probe';
    final encrypted = await EncryptedBackupContainer.encryptBytes(
      source,
      password: password,
    );
    final decoded = await EncryptedBackupContainer.decryptInPlace(
      encrypted,
      password: password,
    );
    if (decoded.length != source.length) throw StateError('length mismatch');
    for (var index = 0; index < source.length; index++) {
      if (decoded[index] != source[index]) {
        throw StateError('byte mismatch at $index');
      }
    }
    print('Web encryption round trip passed');
  } catch (error, stackTrace) {
    print('Web encryption probe failed: $error');
    print(stackTrace);
    rethrow;
  }
}
