import 'package:flutter/foundation.dart';

class SharedBackupFile {
  const SharedBackupFile(this.bytes, this.fileName, this.safetyToken);

  final Uint8List bytes;
  final String fileName;
  final String safetyToken;
}
