import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';

final normalizedTestPictureBytes = base64Decode(
  'UklGRjYAAABXRUJQVlA4ICoAAACwAQCdASoCAAIAAgA0JaACdLoABGaAAP7u'
  'dn/3BmfV2OH9zcW5+hQAAAA=',
);

SelectedPicture normalizedTestPicture(String fileName) {
  return SelectedPicture(
    bytes: normalizedTestPictureBytes,
    fileName: fileName,
    mimeType: 'image/webp',
  );
}

class FakePictureSelectionFlow implements PictureSelectionFlow {
  final bool cameraSupported;
  final SelectedPicture? result;
  final Future<SelectedPicture?>? pendingResult;
  final Object? error;

  final List<ImageSource> selectedSources = [];

  FakePictureSelectionFlow({
    this.cameraSupported = true,
    this.result,
    this.pendingResult,
    this.error,
  });

  @override
  bool supportsImageSource(ImageSource source) {
    return source != ImageSource.camera || cameraSupported;
  }

  @override
  Future<SelectedPicture?> selectAndCrop({
    required BuildContext context,
    required ImageSource source,
  }) async {
    selectedSources.add(source);

    if (error != null) {
      throw error!;
    }

    if (pendingResult != null) {
      return pendingResult!;
    }

    return result;
  }
}
