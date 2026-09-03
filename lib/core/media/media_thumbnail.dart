import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaThumbnail extends StatelessWidget {
  final Uint8List? pictureBytes;
  final String? picturePath;
  final IconData fallbackIcon;
  final double size;

  const MediaThumbnail({
    super.key,
    this.pictureBytes,
    this.picturePath,
    required this.fallbackIcon,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (pictureBytes != null) {
      return _buildImage(context, pictureBytes!);
    }

    final path = picturePath?.trim();

    if (path == null || path.isEmpty) {
      return _buildPlaceholder(context);
    }

    return FutureBuilder<Uint8List>(
      future: XFile(path).readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _buildImage(context, snapshot.data!);
        }

        return _buildPlaceholder(context);
      },
    );
  }

  Widget _buildImage(BuildContext context, Uint8List bytes) {
    final cacheSize = (size * 2).round();

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(context);
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(fallbackIcon, size: size * 0.5),
      ),
    );
  }
}
