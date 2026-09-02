import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AnimalPicture extends StatelessWidget {
  final String? picturePath;
  final Uint8List? pictureBytes;
  final double height;

  const AnimalPicture({
    super.key,
    this.picturePath,
    this.pictureBytes,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (pictureBytes != null) {
      return _buildImage(Image.memory(pictureBytes!, fit: BoxFit.cover));
    }

    if (picturePath == null || picturePath!.trim().isEmpty) {
      return _buildPlaceholder();
    }

    return FutureBuilder<Uint8List>(
      future: XFile(picturePath!).readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildPlaceholder(text: 'Image unavailable');
        }

        return _buildImage(Image.memory(snapshot.data!, fit: BoxFit.cover));
      },
    );
  }

  Widget _buildImage(Widget image) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
    );
  }

  Widget _buildPlaceholder({String text = 'No picture'}) {
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
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}
