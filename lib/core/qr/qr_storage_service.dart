import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:saver_gallery/saver_gallery.dart';

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
  }) async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final result = await SaverGallery.saveImage(
        bytes,
        fileName: '$fileName.png',
        extension: 'png',
        albumPath: 'TerraManager/QR Codes',
        skipIfExists: false,
      );

      if (!result.isSuccess) {
        throw StateError(
          result.errorMessage ?? 'Failed to save QR code to gallery.',
        );
      }

      return result.savedUri ?? '$fileName.png';
    }

    return FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'png',
      mimeType: MimeType.png,
    );
  }
}