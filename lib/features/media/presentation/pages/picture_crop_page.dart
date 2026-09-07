import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../../../../l10n/app_localizations_context.dart';

class PictureCropPage extends StatefulWidget {
  static const editorKey = Key('picture-crop-editor');
  static const applyButtonKey = Key('apply-picture-crop-button');
  static const cancelButtonKey = Key('cancel-picture-crop-button');

  final Uint8List imageBytes;

  const PictureCropPage({super.key, required this.imageBytes});

  @override
  State<PictureCropPage> createState() => _PictureCropPageState();
}

class _PictureCropPageState extends State<PictureCropPage> {
  final CropController _cropController = CropController();

  CropStatus _status = CropStatus.nothing;
  bool _applying = false;
  String? _error;

  bool get _canApply => _status == CropStatus.ready && !_applying;

  void _applyCrop() {
    if (!_canApply) {
      return;
    }

    setState(() {
      _applying = true;
      _error = null;
    });

    _cropController.crop();
  }

  void _handleCropResult(CropResult result) {
    if (!mounted) {
      return;
    }

    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() {
          _applying = false;
          _error = context.l10n.failedToCropPicture;
        });
    }
  }

  void _handleStatusChanged(CropStatus status) {
    if (!mounted || _status == status) {
      return;
    }

    setState(() {
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: PictureCropPage.cancelButtonKey,
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: context.l10n.cancel,
        ),
        title: Text(context.l10n.cropPicture),
        actions: [
          TextButton(
            key: PictureCropPage.applyButtonKey,
            onPressed: _canApply ? _applyCrop : null,
            child: Text(context.l10n.applyCrop),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Crop(
                    key: PictureCropPage.editorKey,
                    image: widget.imageBytes,
                    controller: _cropController,
                    onCropped: _handleCropResult,
                    onStatusChanged: _handleStatusChanged,
                    initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                      size: 0.9,
                    ),
                    interactive: true,
                    willUpdateScale: (scale) => scale <= 10,
                    baseColor: colorScheme.surfaceContainerHighest,
                    maskColor: Colors.black.withAlpha(150),
                    cornerDotBuilder: (_, _) =>
                        DotControl(color: colorScheme.primary),
                    progressIndicator: const Center(
                      child: CircularProgressIndicator(),
                    ),
                    filterQuality: FilterQuality.medium,
                    imageParser: _parseOrientedImage,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                context.l10n.cropPictureInstructions,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  _error!,
                  key: const Key('picture-crop-error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

ImageDetail<image.Image> _parseOrientedImage(
  Uint8List data, {
  ImageFormat? inputFormat,
}) {
  final decodedImage = image.decodeImage(data);

  if (decodedImage == null) {
    throw const FormatException('Unsupported image format');
  }

  final orientedImage = image.bakeOrientation(decodedImage);

  return ImageDetail(
    image: orientedImage,
    width: orientedImage.width.toDouble(),
    height: orientedImage.height.toDouble(),
  );
}
