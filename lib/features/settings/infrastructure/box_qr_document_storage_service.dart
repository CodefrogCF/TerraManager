import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

enum BoxQrDocumentType {
  zip(fileExtension: 'zip', mimeType: 'application/zip'),
  pdf(fileExtension: 'pdf', mimeType: 'application/pdf');

  final String fileExtension;
  final String mimeType;

  const BoxQrDocumentType({
    required this.fileExtension,
    required this.mimeType,
  });
}

abstract class BoxQrDocumentStorage {
  Future<String?> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required BoxQrDocumentType type,
  });
}

class BoxQrDocumentStorageService implements BoxQrDocumentStorage {
  const BoxQrDocumentStorageService();

  @override
  Future<String?> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required BoxQrDocumentType type,
  }) {
    return FileSaver.instance.saveAs(
      name: fileName,
      bytes: bytes,
      includeExtension: false,
      mimeType: MimeType.custom,
      customMimeType: type.mimeType,
    );
  }
}

const String boxQrZipFileName = 'TerraManager_Box_QR_Codes.zip';
const String boxQrPdfFileName = 'TerraManager_Box_QR_Codes_A4.pdf';
