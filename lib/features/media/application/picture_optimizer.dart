import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as image;

class OptimizedPicture {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const OptimizedPicture({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

class PictureOptimizationException implements Exception {
  final String message;

  const PictureOptimizationException(this.message);

  @override
  String toString() => 'PictureOptimizationException: $message';
}

abstract interface class PictureCompressor {
  Future<Uint8List> compressToWebP({
    required Uint8List bytes,
    required int targetWidth,
    required int targetHeight,
    required int quality,
  });
}

class FlutterPictureCompressor implements PictureCompressor {
  const FlutterPictureCompressor();

  @override
  Future<Uint8List> compressToWebP({
    required Uint8List bytes,
    required int targetWidth,
    required int targetHeight,
    required int quality,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: quality,
      format: CompressFormat.webp,
      keepExif: false,
      autoCorrectionAngle: false,
    );

    return compressed;
  }
}

abstract interface class PictureOptimizer {
  Future<OptimizedPicture> optimize({
    required Uint8List bytes,
    required String sourceFileName,
  });
}

class WebpPictureOptimizer implements PictureOptimizer {
  static const defaultMaxDimension = 1920;
  static const defaultQuality = 82;
  static const webpMimeType = 'image/webp';

  final PictureCompressor _compressor;
  final int maxDimension;
  final int quality;

  WebpPictureOptimizer({
    PictureCompressor? compressor,
    this.maxDimension = defaultMaxDimension,
    this.quality = defaultQuality,
  }) : assert(maxDimension > 0),
       assert(quality >= 0 && quality <= 100),
       _compressor = compressor ?? const FlutterPictureCompressor();

  @override
  Future<OptimizedPicture> optimize({
    required Uint8List bytes,
    required String sourceFileName,
  }) async {
    if (bytes.isEmpty) {
      throw const PictureOptimizationException('Picture data is empty.');
    }

    late final int sourceWidth;
    late final int sourceHeight;

    try {
      final decoder = image.findDecoderForData(bytes);
      final imageInfo = decoder?.startDecode(bytes);

      if (imageInfo == null) {
        throw const PictureOptimizationException(
          'Picture format could not be decoded.',
        );
      }

      sourceWidth = imageInfo.width;
      sourceHeight = imageInfo.height;
    } on PictureOptimizationException {
      rethrow;
    } catch (_) {
      throw const PictureOptimizationException(
        'Picture format could not be decoded.',
      );
    }

    final targetSize = _targetSize(sourceWidth, sourceHeight);
    final compressed = await _compressor.compressToWebP(
      bytes: bytes,
      targetWidth: targetSize.width,
      targetHeight: targetSize.height,
      quality: quality,
    );

    if (!_hasWebpSignature(compressed)) {
      throw const PictureOptimizationException(
        'Picture could not be encoded as WebP.',
      );
    }

    return OptimizedPicture(
      bytes: compressed,
      fileName: _webpFileName(sourceFileName),
      mimeType: webpMimeType,
    );
  }

  ({int width, int height}) _targetSize(int width, int height) {
    final longestEdge = width > height ? width : height;

    if (longestEdge <= maxDimension) {
      return (width: width, height: height);
    }

    final scale = maxDimension / longestEdge;

    if (width >= height) {
      return (
        width: maxDimension,
        height: (height * scale).floor().clamp(1, maxDimension).toInt(),
      );
    }

    return (
      width: (width * scale).floor().clamp(1, maxDimension).toInt(),
      height: maxDimension,
    );
  }

  static String _webpFileName(String sourceFileName) {
    final normalized = sourceFileName.trim().replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final safeBaseName = baseName.trim().isEmpty ? 'image' : baseName.trim();

    return '$safeBaseName.webp';
  }

  static bool _hasWebpSignature(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }
}
