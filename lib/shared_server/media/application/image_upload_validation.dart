import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:terramanager/shared_server/shared/application/api_input.dart';

const maxUploadImageBytes = 8 * 1024 * 1024;
const maxUploadImageDimension = 8192;
const maxUploadImagePixels = 20 * 1024 * 1024;

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
  if (bytes.isEmpty || bytes.length > maxUploadImageBytes) {
    throw const ApiProblem(400, 'invalid_data', 'Invalid or oversized image.');
  }
  _validateDecodedImage(mime, bytes);
  return (
    fileName: input.string('fileName', maxLength: 255),
    mimeType: mime,
    bytes: bytes,
  );
}

void _validateDecodedImage(String mime, Uint8List bytes) {
  try {
    final image.Decoder decoder = switch (mime) {
      'image/jpeg' => image.JpegDecoder(),
      'image/png' => image.PngDecoder(),
      'image/webp' => image.WebPDecoder(),
      _ => throw const FormatException('Unsupported image type'),
    };
    // Read dimensions before allocating the decoded pixel buffer. Use the
    // declared format's decoder so a mislabeled file cannot pass validation.
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width > maxUploadImageDimension ||
        info.height > maxUploadImageDimension ||
        info.width * info.height > maxUploadImagePixels ||
        decoder.numFrames() > 1 ||
        (info is image.WebPInfo && info.hasAnimation)) {
      throw const FormatException('Invalid image dimensions or frames');
    }
    final decoded = decoder.decodeFrame(0);
    final matchesCanvas =
        decoded != null &&
        decoded.width == info.width &&
        decoded.height == info.height;
    final matchesExifRotation =
        mime == 'image/jpeg' &&
        decoded != null &&
        decoded.width == info.height &&
        decoded.height == info.width;
    if (!matchesCanvas && !matchesExifRotation) {
      throw const FormatException('Image could not be decoded');
    }
    // Keep the original bytes; re-encoding could discard EXIF orientation.
  } catch (_) {
    throw const ApiProblem(400, 'invalid_data', 'Invalid or oversized image.');
  }
}

typedef ImageUpload = ({String fileName, String mimeType, Uint8List bytes});
