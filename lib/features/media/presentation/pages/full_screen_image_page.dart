import 'dart:typed_data';

import 'package:flutter/material.dart';

class FullScreenImagePage extends StatelessWidget {
  static const double minimumScale = 1;
  static const double maximumScale = 5;

  final Uint8List imageBytes;
  final String title;

  const FullScreenImagePage({
    super.key,
    required this.imageBytes,
    required this.title,
  });

  static Future<void> open(
    BuildContext context, {
    required Uint8List imageBytes,
    required String title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullScreenImagePage(
          imageBytes: imageBytes,
          title: title,
        ),
      ),
    );
  }

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
          tooltip: 'Close picture',
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
                child: Image.memory(
                  imageBytes,
                  key: const Key('full-screen-image'),
                  fit: BoxFit.contain,
                  semanticLabel: title,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
