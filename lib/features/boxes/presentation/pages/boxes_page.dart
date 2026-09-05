import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../feedings/presentation/pages/feeding_scanner_page.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import 'box_detail_page.dart';
import 'box_scanner_page.dart';
import 'new_box_page.dart';

class BoxesPage extends StatefulWidget {
  final AppDatabase database;

  const BoxesPage({super.key, required this.database});

  @override
  State<BoxesPage> createState() => _BoxesPageState();
}

class _BoxesPageState extends State<BoxesPage> {
  late Future<List<Box>> _boxesFuture;

  final ScrollController _scrollController = ScrollController();

  final Map<int, Future<MediaAsset?>> _pictureFutures = {};

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  void _loadBoxes() {
    _pictureFutures.clear();

    _boxesFuture = BoxRepository(widget.database).getAllBoxes();
  }

  double _currentScrollOffset() {
    if (!_scrollController.hasClients) {
      return 0.0;
    }

    return _scrollController.offset;
  }

  Future<void> _reloadBoxesPreservingScroll(double previousOffset) async {
    setState(() {
      _loadBoxes();
    });

    try {
      await _boxesFuture;
    } catch (_) {
      return;
    }

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final maxOffset = _scrollController.position.maxScrollExtent;

      final targetOffset = previousOffset.clamp(0.0, maxOffset).toDouble();

      _scrollController.jumpTo(targetOffset);
    });
  }

  Future<MediaAsset?> _pictureFutureFor(int? mediaId) {
    if (mediaId == null) {
      return Future<MediaAsset?>.value(null);
    }

    return _pictureFutures.putIfAbsent(
      mediaId,
      () => MediaRepository(widget.database).getMediaById(mediaId),
    );
  }

  String _formatDimensions(BuildContext context, Box box) {
    if (box.widthCm == null && box.heightCm == null && box.depthCm == null) {
      return context.l10n.dimensionsNotSpecified;
    }

    return context.l10n.boxDimensions(
      _formatDimensionValue(box.widthCm),
      _formatDimensionValue(box.heightCm),
      _formatDimensionValue(box.depthCm),
    );
  }

  String _formatDimensionValue(double? value) {
    if (value == null) {
      return '—';
    }

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  Future<void> _openNewBoxPage() async {
    final previousOffset = _currentScrollOffset();

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewBoxPage(database: widget.database)),
    );

    if (!mounted || created != true) {
      return;
    }

    await _reloadBoxesPreservingScroll(previousOffset);
  }

  Future<void> _openBoxDetail(Box box, List<Box> boxes) async {
    final previousOffset = _currentScrollOffset();

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BoxDetailPage(
          database: widget.database,
          box: box,
          navigationContext: DetailNavigationContext.boxes(
            boxIds: boxes.map((box) => box.id),
            currentBoxId: box.id,
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadBoxesPreservingScroll(previousOffset);
  }

  Future<void> _openScannerPage() async {
    final previousOffset = _currentScrollOffset();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BoxScannerPage(database: widget.database),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadBoxesPreservingScroll(previousOffset);
  }

  Future<void> _openFeedingMode() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FeedingScannerPage(database: widget.database),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navigationBoxes),
        actions: [
          IconButton(
            key: const Key('scan-box-button'),
            onPressed: _openScannerPage,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: context.l10n.scanBoxTitle,
          ),
          IconButton(
            key: const Key('feeding-mode-button'),
            onPressed: _openFeedingMode,
            icon: const Icon(Icons.restaurant_menu),
            tooltip: context.l10n.feedingModeTitle,
          ),
        ],
      ),
      body: FutureBuilder<List<Box>>(
        future: _boxesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.failedToLoadBoxes));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final boxes = snapshot.data ?? [];

          if (boxes.isEmpty) {
            return Center(child: Text(context.l10n.noBoxesAvailable));
          }

          return ListView.builder(
            key: const PageStorageKey<String>('boxes-overview-list'),
            controller: _scrollController,
            itemCount: boxes.length,
            itemBuilder: (context, index) {
              final box = boxes[index];

              return ListTile(
                key: Key('box-list-item-${box.id}'),
                leading: FutureBuilder<MediaAsset?>(
                  future: _pictureFutureFor(box.pictureMediaId),
                  builder: (context, pictureSnapshot) {
                    return MediaThumbnail(
                      key: Key('box-thumbnail-${box.id}'),
                      pictureBytes: pictureSnapshot.data?.data,
                      fallbackIcon: Icons.home_outlined,
                    );
                  },
                ),
                title: Text(
                  context.l10n.boxLabel(box.id),
                  key: Key('box-label-${box.id}'),
                ),
                subtitle: Text(_formatDimensions(context, box)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _openBoxDetail(box, boxes);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-box-button'),
        onPressed: _openNewBoxPage,
        tooltip: context.l10n.addBox,
        child: const Icon(Icons.add),
      ),
    );
  }
}
