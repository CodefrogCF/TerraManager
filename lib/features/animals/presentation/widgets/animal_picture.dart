import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../media/presentation/pages/full_screen_image_page.dart';

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
      return _buildImage(context, pictureBytes!);
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

        return _buildImage(context, snapshot.data!);
      },
    );
  }

  Widget _buildImage(BuildContext context, Uint8List imageBytes) {
    return Semantics(
      button: true,
      label: 'Open animal picture',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('open-animal-picture-button'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FullScreenImagePage.open(
              context,
              imageBytes: imageBytes,
              title: 'Animal picture',
            );
          },
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(imageBytes, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
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
