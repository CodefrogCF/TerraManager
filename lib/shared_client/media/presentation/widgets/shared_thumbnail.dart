import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/media/application/shared_overview_image_cache.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

class SharedThumbnail extends StatelessWidget {
  const SharedThumbnail({
    super.key,
    required this.api,
    required this.mediaId,
    required this.fallback,
    this.images,
    this.width = 52,
    this.height = 52,
    this.iconSize,
    this.borderRadius = 8,
  });
  final SharedApiClient api;
  final int? mediaId;
  final IconData fallback;
  final SharedOverviewImageCache? images;
  final double width;
  final double height;
  final double? iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(fallback, size: iconSize),
    );
    if (mediaId == null) return placeholder();
    final cache = images;
    if (cache != null) {
      return FutureBuilder<ImageProvider?>(
        future: cache.image(mediaId!),
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image == null) return placeholder();
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image(
              image: image,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder(),
            ),
          );
        },
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        api.mediaUrl(mediaId!).toString(),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
      ),
    );
  }
}
