import 'package:flutter/material.dart';

import '../../../../core/boxes/box_label.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
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

  final Map<int, Future<MediaAsset?>> _pictureFutures = {};

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  void _loadBoxes() {
    _pictureFutures.clear();

    _boxesFuture = BoxRepository(widget.database).getAllBoxes();
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

  String _formatDimensions(Box box) {
    if (box.widthCm == null && box.heightCm == null && box.depthCm == null) {
      return 'Dimensions not specified';
    }

    return '${_formatDimensionValue(box.widthCm)} × '
        '${_formatDimensionValue(box.heightCm)} × '
        '${_formatDimensionValue(box.depthCm)} cm';
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
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewBoxPage(database: widget.database)),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      setState(() {
        _loadBoxes();
      });
    }
  }

  Future<void> _openBoxDetail(Box box) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BoxDetailPage(database: widget.database, box: box),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadBoxes();
    });
  }

  Future<void> _openScannerPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BoxScannerPage(database: widget.database),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadBoxes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boxes'),
        actions: [
          IconButton(
            key: const Key('scan-box-button'),
            onPressed: _openScannerPage,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Box',
          ),
        ],
      ),
      body: FutureBuilder<List<Box>>(
        future: _boxesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load boxes'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final boxes = snapshot.data ?? [];

          if (boxes.isEmpty) {
            return const Center(child: Text('No boxes available'));
          }

          return ListView.builder(
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
                  buildBoxLabel(box.id),
                  key: Key('box-label-${box.id}'),
                ),
                subtitle: Text(_formatDimensions(box)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _openBoxDetail(box);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-box-button'),
        onPressed: _openNewBoxPage,
        tooltip: 'Add Box',
        child: const Icon(Icons.add),
      ),
    );
  }
}
