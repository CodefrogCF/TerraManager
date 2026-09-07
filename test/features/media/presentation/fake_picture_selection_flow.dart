import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';

class FakePictureSelectionFlow implements PictureSelectionFlow {
  final bool cameraSupported;
  final SelectedPicture? result;
  final Object? error;

  final List<ImageSource> selectedSources = [];

  FakePictureSelectionFlow({
    this.cameraSupported = true,
    this.result,
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

    return result;
  }
}
