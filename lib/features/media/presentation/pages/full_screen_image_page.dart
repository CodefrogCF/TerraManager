import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations_context.dart';

class FullScreenImagePage extends StatefulWidget {
  static const double minimumScale = 1;
  static const double maximumScale = 5;

  final List<ImageProvider<Object>> imageProviders;
  final int initialIndex;
  final String title;

  FullScreenImagePage({
    super.key,
    required Uint8List imageBytes,
    required this.title,
  }) : imageProviders = [MemoryImage(imageBytes)],
       initialIndex = 0;

  FullScreenImagePage.network({
    super.key,
    required Uri imageUrl,
    required this.title,
  }) : imageProviders = [NetworkImage(imageUrl.toString())],
       initialIndex = 0;

  FullScreenImagePage.gallery({
    super.key,
    required List<ImageProvider<Object>> imageProviders,
    required this.title,
    this.initialIndex = 0,
  }) : assert(imageProviders.isNotEmpty),
       assert(initialIndex >= 0 && initialIndex < imageProviders.length),
       imageProviders = List.unmodifiable(imageProviders);

  ImageProvider<Object> get imageProvider => imageProviders[initialIndex];

  static Future<void> open(
    BuildContext context, {
    required Uint8List imageBytes,
    required String title,
  }) => openGallery(
    context,
    imageProviders: [MemoryImage(imageBytes)],
    title: title,
  );

  static Future<void> openNetwork(
    BuildContext context, {
    required Uri imageUrl,
    required String title,
  }) => openGallery(
    context,
    imageProviders: [NetworkImage(imageUrl.toString())],
    title: title,
  );

  static Future<void> openGallery(
    BuildContext context, {
    required List<ImageProvider<Object>> imageProviders,
    required String title,
    int initialIndex = 0,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => FullScreenImagePage.gallery(
        imageProviders: imageProviders,
        initialIndex: initialIndex,
        title: title,
      ),
    ),
  );

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  final _transformation = TransformationController();
  late int _index;
  Offset? _startFocalPoint;
  Offset? _lastFocalPoint;
  bool _startedUnzoomed = false;
  bool _multiplePointers = false;

  bool get _unzoomed => _transformation.value.getMaxScaleOnAxis() <= 1.01;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  void didUpdateWidget(FullScreenImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex ||
        !listEquals(oldWidget.imageProviders, widget.imageProviders)) {
      _index = widget.initialIndex;
      _transformation.value = Matrix4.identity();
      _startFocalPoint = _lastFocalPoint = null;
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _navigate(int direction) {
    final next = _index + direction;
    if (next < 0 || next >= widget.imageProviders.length) return;
    setState(() {
      _index = next;
      _transformation.value = Matrix4.identity();
      _startFocalPoint = null;
      _lastFocalPoint = null;
    });
  }

  void _interactionStart(ScaleStartDetails details) {
    _startedUnzoomed = _unzoomed;
    _multiplePointers = details.pointerCount > 1;
    _startFocalPoint = _lastFocalPoint = details.localFocalPoint;
  }

  void _interactionUpdate(ScaleUpdateDetails details) {
    _multiplePointers |= details.pointerCount > 1;
    _lastFocalPoint = details.localFocalPoint;
  }

  void _interactionEnd(ScaleEndDetails details) {
    final start = _startFocalPoint;
    final end = _lastFocalPoint;
    // InteractiveViewer owns the gestures. Only a one-finger horizontal drag
    // at normal scale changes pictures; pinch and zoomed panning stay within
    // the current picture.
    if (!_startedUnzoomed ||
        !_unzoomed ||
        _multiplePointers ||
        start == null ||
        end == null) {
      return;
    }
    final delta = end - start;
    if (delta.dx.abs() >= 60 && delta.dx.abs() > delta.dy.abs()) {
      _navigate(delta.dx < 0 ? 1 : -1);
    }
  }

  KeyEventResult _keyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _navigate(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _navigate(1);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _keyEvent,
    child: Scaffold(
      key: const Key('full-screen-image-page'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        leading: IconButton(
          key: const Key('close-full-screen-image-button'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: context.l10n.closePicture,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: LayoutBuilder(
                  builder: (context, constraints) => InteractiveViewer(
                    key: const Key('full-screen-image-viewer'),
                    transformationController: _transformation,
                    minScale: FullScreenImagePage.minimumScale,
                    maxScale: FullScreenImagePage.maximumScale,
                    panEnabled: true,
                    scaleEnabled: true,
                    onInteractionStart: _interactionStart,
                    onInteractionUpdate: _interactionUpdate,
                    onInteractionEnd: _interactionEnd,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Image(
                        image: widget.imageProviders[_index],
                        key: const Key('full-screen-image'),
                        fit: BoxFit.contain,
                        semanticLabel: widget.title,
                        errorBuilder: (_, _, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.imageUnavailable,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('previous-full-screen-picture'),
                    color: Colors.white,
                    disabledColor: Colors.white38,
                    tooltip: context.l10n.previousPicture,
                    onPressed: _index > 0 ? () => _navigate(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.picturePosition(
                        _index + 1,
                        widget.imageProviders.length,
                      ),
                      key: const Key('full-screen-picture-position'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    key: const Key('next-full-screen-picture'),
                    color: Colors.white,
                    disabledColor: Colors.white38,
                    tooltip: context.l10n.nextPicture,
                    onPressed: _index + 1 < widget.imageProviders.length
                        ? () => _navigate(1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
