import 'dart:convert';
import 'dart:typed_data';

import 'package:terramanager/shared_server/shared/application/api_input.dart';

ImageUpload decodeImageUpload(ApiInput input) {
  final mime = input.string('mimeType', maxLength: 100);
  if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
    throw const ApiProblem(400, 'invalid_data', 'Unsupported image MIME type.');
  }
  final Uint8List bytes;
  try {
    bytes = base64Decode(
      input.string('dataBase64', maxLength: 12 * 1024 * 1024),
    );
  } on FormatException {
    throw const ApiProblem(400, 'invalid_data', 'Invalid base64 image.');
  }
  if (bytes.isEmpty ||
      bytes.length > 8 * 1024 * 1024 ||
      !validImageSignature(mime, bytes)) {
    throw const ApiProblem(400, 'invalid_data', 'Invalid or oversized image.');
  }
  return (
    fileName: input.string('fileName', maxLength: 255),
    mimeType: mime,
    bytes: bytes,
  );
}

bool validImageSignature(String mime, Uint8List bytes) {
  if (mime == 'image/jpeg') {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }
  if (mime == 'image/png') {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
  }
  if (mime == 'image/webp') {
    return bytes.length >= 12 &&
        utf8.decode(bytes.sublist(0, 4)) == 'RIFF' &&
        utf8.decode(bytes.sublist(8, 12)) == 'WEBP';
  }
  return false;
}

typedef ImageUpload = ({String fileName, String mimeType, Uint8List bytes});
