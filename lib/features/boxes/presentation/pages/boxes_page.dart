import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_lifecycle_exception.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
import '../../../../core/presentation/widgets/overview_context_menu.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../feedings/presentation/pages/feeding_scanner_page.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import '../../../settings/app_settings_controller.dart';
import '../../../settings/box_sort_order.dart';
import '../box_lifecycle_dialogs.dart';
import '../box_overview_sorting.dart';
import '../box_quick_action_dialogs.dart';
import 'box_detail_page.dart';
import 'box_edit_page.dart';
import 'box_scanner_page.dart';
import 'new_box_page.dart';

enum _BoxOverviewAction { rename, edit, duplicate, archive }

class BoxesPage extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onFeedingChanged;
  final VoidCallback? onAnimalsChanged;
  final bool showArchived;

  const BoxesPage({
    super.key,
    required this.database,
    this.onFeedingChanged,
    this.onAnimalsChanged,
    this.showArchived = false,
  });

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

    final repository = BoxRepository(widget.database);
    _boxesFuture = widget.showArchived
        ? repository.getArchivedBoxes()
        : repository.getActiveBoxes();
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

  String? _boxName(Box box) {
    final name = box.name?.trim();

    if (name == null || name.isEmpty) {
      return null;
    }

    return name;
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
          onAnimalsChanged: widget.onAnimalsChanged,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadBoxesPreservingScroll(previousOffset);
  }

  Future<void> _handleBoxAction(_BoxOverviewAction action, Box box) async {
    switch (action) {
      case _BoxOverviewAction.rename:
        await _renameBox(box);
        return;
      case _BoxOverviewAction.edit:
        await _editBox(box);
        return;
      case _BoxOverviewAction.duplicate:
        await _duplicateBox(box);
        return;
      case _BoxOverviewAction.archive:
        await _archiveBox(box);
        return;
    }
  }

  Future<void> _renameBox(Box box) async {
    final input = await showDialog<BoxNameInput>(
      context: context,
      builder: (_) => RenameBoxDialog(initialName: box.name),
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      final renamed = await BoxRepository(widget.database)
          .renameBox(boxId: box.id, name: input.name);
      if (!mounted) {
        return;
      }
      if (!renamed) {
        _showMessage(context.l10n.failedToRenameBox);
        return;
      }

      await _reloadBoxesPreservingScroll(_currentScrollOffset());
      if (mounted) {
        _showMessage(context.l10n.boxRenamed);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToRenameBox);
      }
    }
  }

  Future<void> _editBox(Box box) async {
    final previousOffset = _currentScrollOffset();
    await Navigator.of(context).push<BoxEditResult>(
      MaterialPageRoute(
        builder: (_) => BoxEditPage(database: widget.database, boxId: box.id),
      ),
    );
    if (mounted) {
      await _reloadBoxesPreservingScroll(previousOffset);
    }
  }

  Future<void> _duplicateBox(Box box) async {
    final sourceName = _boxName(box);
    final input = await showDialog<BoxNameInput>(
      context: context,
      builder: (_) => DuplicateBoxDialog(
        initialName: sourceName == null
            ? null
            : context.l10n.copyName(sourceName),
      ),
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      await BoxRepository(widget.database)
          .duplicateBox(sourceBoxId: box.id, name: input.name);
      if (!mounted) {
        return;
      }

      if (widget.showArchived && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
        return;
      }

      await _reloadBoxesPreservingScroll(_currentScrollOffset());
      if (mounted) {
        _showMessage(context.l10n.boxDuplicated);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToDuplicateBox);
      }
    }
  }

  Future<void> _archiveBox(Box box) async {
    try {
      final animals = await AnimalRepository(widget.database)
          .getAnimalsForBox(box.id);
      if (!mounted) {
        return;
      }
      if (animals.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (_) => CannotArchiveBoxDialog(animals: animals),
        );
        return;
      }

      final input = await showDialog<ArchiveBoxInput>(
        context: context,
        builder: (_) => const ArchiveBoxDialog(hasUnsavedChanges: false),
      );
      if (!mounted || input == null) {
        return;
      }

      final archived = await BoxRepository(widget.database).archiveBox(
        boxId: box.id,
        reason: input.reason,
        archivedAt: DateTime.now(),
        archiveNotes: input.notes,
      );
      if (!mounted) {
        return;
      }
      if (!archived) {
        _showMessage(context.l10n.failedToArchiveBox);
        return;
      }

      await _reloadBoxesPreservingScroll(_currentScrollOffset());
      if (mounted) {
        _showMessage(context.l10n.boxArchived);
      }
    } on BoxArchiveBlockedException catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => CannotArchiveBoxDialog(animals: error.animals),
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToArchiveBox);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _openArchive() async {
    final previousOffset = _currentScrollOffset();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BoxesPage(
          database: widget.database,
          onFeedingChanged: widget.onFeedingChanged,
          onAnimalsChanged: widget.onAnimalsChanged,
          showArchived: true,
        ),
      ),
    );
    if (mounted) {
      await _reloadBoxesPreservingScroll(previousOffset);
    }
  }

  Future<void> _openFeedingMode() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FeedingScannerPage(
          database: widget.database,
          onFeedingChanged: widget.onFeedingChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.maybeOf(context);
    final boxSortOrder = settings?.boxSortOrder ?? BoxSortOrder.labelAscending;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showArchived
              ? context.l10n.archivedBoxes
              : context.l10n.navigationBoxes,
        ),
        actions: [
          PopupMenuButton<BoxSortOrder>(
            key: const Key('box-sort-button'),
            initialValue: boxSortOrder,
            onSelected: (sortOrder) {
              settings?.setBoxSortOrder(sortOrder);
            },
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.sortBoxes,
            itemBuilder: (context) {
              return BoxSortOrder.values.map((sortOrder) {
                return CheckedPopupMenuItem<BoxSortOrder>(
                  key: Key('box-sort-option-${sortOrder.name}'),
                  value: sortOrder,
                  checked: sortOrder == boxSortOrder,
                  child: Text(context.l10n.boxSortOrderLabel(sortOrder)),
                );
              }).toList();
            },
          ),
          if (!widget.showArchived) ...[
            IconButton(
              key: const Key('box-archive-button'),
              onPressed: _openArchive,
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: context.l10n.archivedBoxes,
            ),
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

          final boxes = sortBoxesForOverview(
            snapshot.data ?? const <Box>[],
            boxSortOrder,
          );

          if (boxes.isEmpty) {
            return Center(
              child: Text(
                widget.showArchived
                    ? context.l10n.noArchivedBoxes
                    : context.l10n.noBoxesAvailable,
              ),
            );
          }

          return ListView.builder(
            key: const PageStorageKey<String>('boxes-overview-list'),
            controller: _scrollController,
            itemCount: boxes.length,
            itemBuilder: (context, index) {
              final box = boxes[index];
              final boxName = _boxName(box);
              final boxLabel = context.l10n.boxLabel(box.id);
              final dimensions = _formatDimensions(context, box);

              return OverviewContextMenu<_BoxOverviewAction>(
                key: Key('box-context-menu-region-${box.id}'),
                menuButtonKey: Key('box-context-menu-button-${box.id}'),
                tooltip: context.l10n.boxActions(boxName ?? boxLabel),
                onSelected: (action) {
                  _handleBoxAction(action, box);
                },
                itemBuilder: (context) => [
                  if (!widget.showArchived) ...[
                    _boxMenuItem(
                      action: _BoxOverviewAction.rename,
                      icon: Icons.drive_file_rename_outline,
                      label: context.l10n.renameBox,
                    ),
                    _boxMenuItem(
                      action: _BoxOverviewAction.edit,
                      icon: Icons.edit_outlined,
                      label: context.l10n.editBox,
                    ),
                  ],
                  _boxMenuItem(
                    action: _BoxOverviewAction.duplicate,
                    icon: Icons.copy_outlined,
                    label: context.l10n.duplicateBox,
                  ),
                  if (!widget.showArchived)
                    _boxMenuItem(
                      action: _BoxOverviewAction.archive,
                      icon: Icons.archive_outlined,
                      label: context.l10n.archiveBox,
                    ),
                ],
                builder: (context, menuButton) => ListTile(
                  key: Key('box-list-item-${box.id}'),
                  leading: FutureBuilder<MediaAsset?>(
                    future: _pictureFutureFor(box.pictureMediaId),
                    builder: (context, pictureSnapshot) {
                      return MediaThumbnail(
                        key: Key('box-thumbnail-${box.id}'),
                        pictureBytes: pictureSnapshot.data?.data,
                        fallbackIcon: Icons.inventory_2_outlined,
                      );
                    },
                  ),
                  title: Text(
                    boxName ?? boxLabel,
                    key: boxName == null
                        ? Key('box-label-${box.id}')
                        : Key('box-name-${box.id}'),
                  ),
                  subtitle: boxName == null
                      ? Text(dimensions)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(boxLabel, key: Key('box-label-${box.id}')),
                            Text(dimensions),
                          ],
                        ),
                  isThreeLine: boxName != null,
                  trailing: menuButton,
                  onTap: () {
                    _openBoxDetail(box, boxes);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.showArchived
          ? null
          : FloatingActionButton(
              heroTag: 'boxes-add-fab',
              key: const Key('add-box-button'),
              onPressed: _openNewBoxPage,
              tooltip: context.l10n.addBox,
              child: const Icon(Icons.add),
            ),
    );
  }
}

PopupMenuItem<_BoxOverviewAction> _boxMenuItem({
  required _BoxOverviewAction action,
  required IconData icon,
  required String label,
}) {
  return PopupMenuItem<_BoxOverviewAction>(
    value: action,
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(label)),
      ],
    ),
  );
}
