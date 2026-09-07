import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/image_media_info.dart';
import '../application/picture_optimizer.dart';
import 'pages/picture_crop_page.dart';

class SelectedPicture {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const SelectedPicture({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

abstract interface class PictureSelectionFlow {
  bool supportsImageSource(ImageSource source);

  Future<SelectedPicture?> selectAndCrop({
    required BuildContext context,
    required ImageSource source,
  });
}

class DefaultPictureSelectionFlow implements PictureSelectionFlow {
  final ImagePicker _imagePicker;
  final PictureOptimizer _pictureOptimizer;

  DefaultPictureSelectionFlow({
    ImagePicker? imagePicker,
    PictureOptimizer? pictureOptimizer,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _pictureOptimizer = pictureOptimizer ?? WebpPictureOptimizer();

  @override
  bool supportsImageSource(ImageSource source) {
    return _imagePicker.supportsImageSource(source);
  }

  @override
  Future<SelectedPicture?> selectAndCrop({
    required BuildContext context,
    required ImageSource source,
  }) async {
    final image = await _imagePicker.pickImage(source: source);

    if (image == null) {
      return null;
    }

    final originalBytes = await image.readAsBytes();

    if (!context.mounted) {
      return null;
    }

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => PictureCropPage(imageBytes: originalBytes),
      ),
    );

    if (croppedBytes == null) {
      return null;
    }

    final info = ImageMediaInfo.fromXFile(image);
    final optimized = await _pictureOptimizer.optimize(
      bytes: croppedBytes,
      sourceFileName: info.fileName,
    );

    return SelectedPicture(
      bytes: optimized.bytes,
      fileName: optimized.fileName,
      mimeType: optimized.mimeType,
    );
  }
}
