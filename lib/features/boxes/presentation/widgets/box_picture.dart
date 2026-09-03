import 'dart:typed_data';

import 'package:flutter/material.dart';

class BoxPicture extends StatelessWidget {
  final Uint8List? pictureBytes;
  final double height;
  final String emptyText;

  const BoxPicture({
    super.key,
    this.pictureBytes,
    this.height = 220,
    this.emptyText = 'No picture',
  });

  @override
  Widget build(BuildContext context) {
    if (pictureBytes == null) {
      return _buildPlaceholder();
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          pictureBytes!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(text: 'Image unavailable');
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder({String? text}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined, size: 48),
              const SizedBox(height: 8),
              Text(text ?? emptyText),
            ],
          ),
        ),
      ),
    );
  }
}
