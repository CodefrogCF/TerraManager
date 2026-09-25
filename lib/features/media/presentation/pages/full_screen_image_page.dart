import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations_context.dart';

class FullScreenImagePage extends StatelessWidget {
  static const double minimumScale = 1;
  static const double maximumScale = 5;

  final ImageProvider<Object> imageProvider;
  final String title;

  FullScreenImagePage({
    super.key,
    required Uint8List imageBytes,
    required this.title,
  }) : imageProvider = MemoryImage(imageBytes);

  FullScreenImagePage.network({
    super.key,
    required Uri imageUrl,
    required this.title,
  }) : imageProvider = NetworkImage(imageUrl.toString());

  static Future<void> open(
    BuildContext context, {
    required Uint8List imageBytes,
    required String title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            FullScreenImagePage(imageBytes: imageBytes, title: title),
      ),
    );
  }

  static Future<void> openNetwork(
    BuildContext context, {
    required Uri imageUrl,
    required String title,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          FullScreenImagePage.network(imageUrl: imageUrl, title: title),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('full-screen-image-page'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        leading: IconButton(
          key: const Key('close-full-screen-image-button'),
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close),
          tooltip: context.l10n.closePicture,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              key: const Key('full-screen-image-viewer'),
              minScale: minimumScale,
              maxScale: maximumScale,
              panEnabled: true,
              scaleEnabled: true,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Image(
                  image: imageProvider,
                  key: const Key('full-screen-image'),
                  fit: BoxFit.contain,
                  semanticLabel: title,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
