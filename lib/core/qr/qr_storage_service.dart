import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

abstract class QrStorage {
  Future<String> savePng({
    required Uint8List bytes,
    required String fileName,
  });
}

class QrStorageService implements QrStorage {
  const QrStorageService();

  @override
  Future<String> savePng({
    required Uint8List bytes,
    required String fileName,
  }) {
    return FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'png',
      mimeType: MimeType.png,
    );
  }
}