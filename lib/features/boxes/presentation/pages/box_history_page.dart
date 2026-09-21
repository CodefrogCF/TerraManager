import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
import '../../../../core/presentation/widgets/overview_context_menu.dart';
import '../../../../core/sorting/archive_sorting.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import '../../../settings/app_settings_controller.dart';
import '../../../settings/archive_sort_order.dart';
import '../box_quick_action_dialogs.dart';
import 'box_detail_page.dart';

enum _ArchivedBoxAction { duplicate }

class BoxHistoryPage extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onAnimalsChanged;

  const BoxHistoryPage({
    super.key,
    required this.database,
    this.onAnimalsChanged,
  });

  @override
  State<BoxHistoryPage> createState() => _BoxHistoryPageState();
}

class _BoxHistoryPageState extends State<BoxHistoryPage> {
  late Future<List<Box>> _boxesFuture;

  final Map<int, Future<MediaAsset?>> _pictureFutures = {};

  @override
  void initState() {
    super.initState();

    _loadBoxes();
  }

  void _loadBoxes() {
    _pictureFutures.clear();

    _boxesFuture = BoxRepository(widget.database).getArchivedBoxes();
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

  String? _boxName(Box box) {
    final name = box.name?.trim();

    if (name == null || name.isEmpty) {
      return null;
    }

    return name;
  }

  String _displayName(BuildContext context, Box box) {
    return _boxName(box) ?? context.l10n.boxLabel(box.id);
  }

  Future<void> _openBoxDetail(Box box, List<Box> boxes) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
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

    setState(_loadBoxes);
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

      // Mirrors Animal History:
      // leave the archive after creating
      // the new active record.
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToDuplicateBox);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.maybeOf(context);

    final sortOrder =
        settings?.boxArchiveSortOrder ?? ArchiveSortOrder.archivedNewestFirst;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.archivedBoxes),
        actions: [
          PopupMenuButton<ArchiveSortCriterion>(
            key: const Key('box-archive-sort-button'),
            initialValue: sortOrder.criterion,
            onSelected: (criterion) {
              final selectedOrder = criterion == sortOrder.criterion
                  ? sortOrder.reversed
                  : criterion.defaultOrder;

              settings?.setBoxArchiveSortOrder(selectedOrder);
            },
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.sortArchivedBoxes,
            itemBuilder: (context) {
              return ArchiveSortCriterion.values.map((criterion) {
                final isActive = criterion == sortOrder.criterion;

                return CheckedPopupMenuItem<ArchiveSortCriterion>(
                  key: Key(
                    'box-archive-sort-option-'
                    '${criterion.name}',
                  ),
                  value: criterion,
                  checked: isActive,
                  child: Text(
                    context.l10n.archiveSortCriterionMenuLabel(
                      criterion,
                      activeOrder: isActive ? sortOrder : null,
                    ),
                  ),
                );
              }).toList();
            },
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

          final rawBoxes = snapshot.data ?? const <Box>[];

          final boxes = sortArchivedRecords<Box>(
            rawBoxes,
            sortOrder: sortOrder,
            archivedAt: (box) => box.archivedAt,
            displayName: (box) => _displayName(context, box),
            id: (box) => box.id,
          );

          if (boxes.isEmpty) {
            return Center(
              key: const Key('box-history-empty-state'),
              child: Text(context.l10n.noArchivedBoxes),
            );
          }

          return ListView.builder(
            key: const Key('box-history-list'),
            itemCount: boxes.length,
            itemBuilder: (context, index) {
              final box = boxes[index];

              final boxName = _boxName(box);

              final boxLabel = context.l10n.boxLabel(box.id);

              final displayName = boxName ?? boxLabel;

              return OverviewContextMenu<_ArchivedBoxAction>(
                key: Key(
                  'archived-box-context-menu-region-'
                  '${box.id}',
                ),
                menuButtonKey: Key(
                  'archived-box-context-menu-button-'
                  '${box.id}',
                ),
                tooltip: context.l10n.boxActions(displayName),
                onSelected: (_) {
                  _duplicateBox(box);
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_ArchivedBoxAction>(
                    value: _ArchivedBoxAction.duplicate,
                    child: Row(
                      children: [
                        const Icon(Icons.copy_outlined, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(context.l10n.duplicateBox)),
                      ],
                    ),
                  ),
                ],
                builder: (context, menuButton) => ListTile(
                  key: Key(
                    'archived-box-list-item-'
                    '${box.id}',
                  ),
                  leading: FutureBuilder<MediaAsset?>(
                    future: _pictureFutureFor(box.pictureMediaId),
                    builder: (context, pictureSnapshot) {
                      return MediaThumbnail(
                        key: Key(
                          'archived-box-thumbnail-'
                          '${box.id}',
                        ),
                        pictureBytes: pictureSnapshot.data?.data,
                        fallbackIcon: Icons.inventory_2_outlined,
                      );
                    },
                  ),
                  title: Text(
                    displayName,
                    key: boxName == null
                        ? Key(
                            'archived-box-label-'
                            '${box.id}',
                          )
                        : Key(
                            'archived-box-name-'
                            '${box.id}',
                          ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (boxName != null)
                        Text(
                          boxLabel,
                          key: Key(
                            'archived-box-label-'
                            '${box.id}',
                          ),
                        ),
                      if (boxName != null) const SizedBox(height: 4),
                      Text(
                        _archiveSummary(context, box),
                        key: Key(
                          'archived-box-summary-'
                          '${box.id}',
                        ),
                      ),
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
    );
  }

  String _archiveSummary(BuildContext context, Box box) {
    final parts = <String>[];

    if (box.archiveReason != null) {
      parts.add(context.l10n.boxArchiveReasonLabel(box.archiveReason!));
    }

    if (box.archivedAt != null) {
      parts.add(_formatDate(box.archivedAt!));
    }

    return parts.isEmpty ? context.l10n.archived : parts.join(' • ');
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}
