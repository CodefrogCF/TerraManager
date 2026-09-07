import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:terramanager/features/media/application/picture_optimizer.dart';

class FakePictureCompressor implements PictureCompressor {
  final Uint8List result;

  int callCount = 0;
  Uint8List? receivedBytes;
  int? receivedTargetWidth;
  int? receivedTargetHeight;
  int? receivedQuality;

  FakePictureCompressor({Uint8List? result})
    : result =
          result ??
          Uint8List.fromList([
            0x52,
            0x49,
            0x46,
            0x46,
            0,
            0,
            0,
            0,
            0x57,
            0x45,
            0x42,
            0x50,
          ]);

  @override
  Future<Uint8List> compressToWebP({
    required Uint8List bytes,
    required int targetWidth,
    required int targetHeight,
    required int quality,
  }) async {
    callCount++;
    receivedBytes = bytes;
    receivedTargetWidth = targetWidth;
    receivedTargetHeight = targetHeight;
    receivedQuality = quality;

    return result;
  }
}

Uint8List pngBytes({required int width, required int height}) {
  return image.encodePng(image.Image(width: width, height: height));
}

void main() {
  test('converts a wide picture to bounded WebP storage metadata', () async {
    final compressor = FakePictureCompressor();
    final optimizer = WebpPictureOptimizer(
      compressor: compressor,
      maxDimension: 100,
      quality: 82,
    );
    final sourceBytes = pngBytes(width: 240, height: 120);

    final result = await optimizer.optimize(
      bytes: sourceBytes,
      sourceFileName: r'C:\pictures\animal.profile.PNG',
    );

    expect(compressor.callCount, 1);
    expect(compressor.receivedBytes, same(sourceBytes));
    expect(compressor.receivedTargetWidth, 100);
    expect(compressor.receivedTargetHeight, 50);
    expect(compressor.receivedQuality, 82);
    expect(result.bytes, same(compressor.result));
    expect(result.fileName, 'animal.profile.webp');
    expect(result.mimeType, 'image/webp');
  });

  test('preserves aspect ratio for a portrait picture', () async {
    final compressor = FakePictureCompressor();
    final optimizer = WebpPictureOptimizer(
      compressor: compressor,
      maxDimension: 100,
    );

    await optimizer.optimize(
      bytes: pngBytes(width: 100, height: 240),
      sourceFileName: 'animal.jpg',
    );

    expect(compressor.receivedTargetWidth, 41);
    expect(compressor.receivedTargetHeight, 100);
  });

  test('does not upscale a picture below the dimension limit', () async {
    final compressor = FakePictureCompressor();
    final optimizer = WebpPictureOptimizer(
      compressor: compressor,
      maxDimension: 100,
    );

    await optimizer.optimize(
      bytes: pngBytes(width: 80, height: 40),
      sourceFileName: 'box',
    );

    expect(compressor.receivedTargetWidth, 80);
    expect(compressor.receivedTargetHeight, 40);
    expect(compressor.receivedQuality, WebpPictureOptimizer.defaultQuality);
  });

  test('rejects image data that cannot be decoded', () async {
    final compressor = FakePictureCompressor();
    final optimizer = WebpPictureOptimizer(compressor: compressor);

    await expectLater(
      optimizer.optimize(
        bytes: Uint8List.fromList([1, 2, 3]),
        sourceFileName: 'invalid.jpg',
      ),
      throwsA(isA<PictureOptimizationException>()),
    );
    expect(compressor.callCount, 0);
  });

  test('rejects compressor output without a WebP signature', () async {
    final compressor = FakePictureCompressor(
      result: Uint8List.fromList([1, 2, 3]),
    );
    final optimizer = WebpPictureOptimizer(compressor: compressor);

    await expectLater(
      optimizer.optimize(
        bytes: pngBytes(width: 2, height: 2),
        sourceFileName: 'animal.png',
      ),
      throwsA(isA<PictureOptimizationException>()),
    );
    expect(compressor.callCount, 1);
  });
}
