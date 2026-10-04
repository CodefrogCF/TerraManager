import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/core/presentation/widgets/overview_context_menu.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/shared_client/boxes/presentation/box_overview.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_detail_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_form.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_scanner_page.dart';
import 'package:terramanager/shared_client/feedings/presentation/pages/shared_feeding_box_page.dart';
import 'package:terramanager/shared_client/media/application/shared_overview_image_cache.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_thumbnail.dart';
import 'package:terramanager/shared_client/navigation/application/shared_detail_navigation.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_change_feedback.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_archive_records.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_archive_dialog.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_duplicate_dialog.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_menu_item.dart';

enum _BoxAction { details, edit, duplicate, archive, restore }

String? _boxDimensions(Map<String, dynamic> box) {
  final values = [box['widthCm'], box['heightCm'], box['depthCm']];
  if (values.every((value) => value == null)) return null;
  return '${values.map((value) => value?.toString() ?? '–').join(' × ')} cm';
}

class SharedBoxesPage extends StatefulWidget {
  const SharedBoxesPage({
    super.key,
    required this.api,
    required this.boxes,
    required this.animals,
    required this.connected,
    required this.change,
    required this.onReload,
    this.archived = false,
  });

  final bool archived;
  final SharedApiClient api;
  final List<Map<String, dynamic>> boxes;
  final List<Map<String, dynamic>> animals;
  final bool connected;
  final SharedChange change;
  final Future<void> Function() onReload;

  @override
  State<SharedBoxesPage> createState() => _SharedBoxesPageState();
}

class _SharedBoxesPageState extends State<SharedBoxesPage> {
  late SharedOverviewImageCache _images;

  @override
  void initState() {
    super.initState();
    _images = SharedOverviewImageCache(loadBytes: widget.api.mediaBytes);
  }

  @override
  void didUpdateWidget(covariant SharedBoxesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _archiveData?.value = _archiveSnapshot;
    if (oldWidget.api != widget.api) {
      _images.dispose();
      _images = SharedOverviewImageCache(loadBytes: widget.api.mediaBytes);
    } else {
      _images.retain(
        widget.boxes.map((record) => record['pictureMediaId']).whereType<int>(),
      );
    }
  }

  @override
  void dispose() {
    _images.dispose();
    _archiveData?.dispose();
    _archiveData = null;
    super.dispose();
  }

  Future<void> _reload() async {
    await widget.onReload();
    if (mounted) setState(_images.clear);
  }

  bool get _archived => widget.archived;
  ValueNotifier<SharedArchiveSnapshot>? _archiveData;
  SharedArchiveSnapshot get _archiveSnapshot => (
    boxes: widget.boxes,
    animals: widget.animals,
    connected: widget.connected,
  );

  Future<void> _openArchive() async {
    final data = _archiveData = ValueNotifier(_archiveSnapshot);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ValueListenableBuilder<SharedArchiveSnapshot>(
          valueListenable: data,
          builder: (context, snapshot, _) => SharedBoxesPage(
            api: widget.api,
            boxes: snapshot.boxes,
            animals: snapshot.animals,
            connected: snapshot.connected,
            change: widget.change,
            onReload: _reload,
            archived: true,
          ),
        ),
      ),
    );
    if (identical(_archiveData, data)) {
      _archiveData = null;
      data.dispose();
    }
  }

  Future<void> _openFeedingMode() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedBoxScannerPage(
          api: widget.api,
          boxes: widget.boxes,
          animals: widget.animals,
          change: widget.change,
          title: context.l10n.feedingModeTitle,
          allowBoxSelection: true,
          onBoxResolved: (scannerContext, box) =>
              Navigator.of(scannerContext).push<bool>(
                MaterialPageRoute(
                  builder: (_) => SharedFeedingBoxPage(
                    api: widget.api,
                    box: box,
                    change: widget.change,
                    onReload: _reload,
                  ),
                ),
              ),
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openBox(Map<String, dynamic> box) async {
    final settings = AppSettingsScope.of(context);
    final order = _archived
        ? sortSharedArchiveRecords(
            widget.boxes,
            order: settings.boxArchiveSortOrder,
            displayName: boxLabel,
          )
        : sortSharedBoxesForOverview(
            widget.boxes.where(
              (item) => (item['status'] == 'archived') == _archived,
            ),
            settings.boxSortOrder,
          );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedBoxDetailPage(
          api: widget.api,
          id: recordId(box),
          boxes: widget.boxes,
          animals: widget.animals,
          connected: widget.connected,
          change: widget.change,
          navigationContext: SharedDetailNavigationContext.boxes(
            recordIds: order.map(recordId),
            currentRecordId: recordId(box),
            archived: _archived,
            sortOrder: settings.boxSortOrder,
            archiveSortOrder: _archived ? settings.boxArchiveSortOrder : null,
          ),
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _boxAction(_BoxAction action, Map<String, dynamic> box) async {
    if (action == _BoxAction.details) {
      await _openBox(box);
      return;
    }
    if (!widget.connected || !widget.api.connected) return;
    final id = recordId(box);
    switch (action) {
      case _BoxAction.details:
        return;
      case _BoxAction.edit:
        try {
          final current = await widget.api.box(id);
          if (!mounted) return;
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => SharedBoxForm(
                api: widget.api,
                change: widget.change,
                initial: current,
              ),
            ),
          );
          if (mounted) await _reload();
        } catch (_) {
          if (mounted) showSharedChangeFailure(context);
        }
      case _BoxAction.duplicate:
        final saved = await showSharedDuplicateDialog(
          context,
          api: widget.api,
          change: widget.change,
          source: box,
        );
        if (saved == true && mounted) await _reload();
      case _BoxAction.archive:
        final choice = await showArchiveDialog(
          context,
          reasons: const ['sold', 'replaced', 'damaged', 'stored', 'other'],
        );
        if (choice == null) return;
        final saved = await widget.change(() async {
          await widget.api.archiveBox(id, choice.$1, choice.$2);
        });
        if (!saved && mounted) showSharedChangeFailure(context);
      case _BoxAction.restore:
        final saved = await widget.change(() async {
          await widget.api.restoreBox(id);
        });
        if (!saved && mounted) showSharedChangeFailure(context);
    }
  }

  List<PopupMenuEntry<_BoxAction>> _boxMenu(BuildContext context) => [
    sharedMenuItem(
      _BoxAction.details,
      Icons.open_in_new_outlined,
      sharedText(context, 'Open details', 'Details öffnen'),
    ),
    sharedMenuItem(_BoxAction.edit, Icons.edit_outlined, context.l10n.editBox),
    sharedMenuItem(
      _BoxAction.duplicate,
      Icons.copy_outlined,
      context.l10n.duplicateBox,
    ),
    sharedMenuItem(
      _BoxAction.archive,
      Icons.archive_outlined,
      context.l10n.archiveBox,
    ),
  ];

  List<PopupMenuEntry<_BoxAction>> _archivedBoxMenu(BuildContext context) => [
    sharedMenuItem(
      _BoxAction.details,
      Icons.open_in_new_outlined,
      sharedText(context, 'Open details', 'Details öffnen'),
    ),
    sharedMenuItem(
      _BoxAction.restore,
      Icons.unarchive_outlined,
      context.l10n.restoreBox,
    ),
  ];

  Widget _bigPictureBoxCard(Map<String, dynamic> box, bool archived) {
    final id = recordId(box);
    final name = (box['name'] as String?)?.trim();
    final hasName = name != null && name.isNotEmpty;
    final dimensions = _boxDimensions(box);
    Widget card(Widget? menuButton) => Card(
      key: Key('box-list-item-$id'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openBox(box),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SharedThumbnail(
                key: Key('box-big-picture-$id'),
                api: widget.api,
                images: _images,
                mediaId: box['pictureMediaId'] as int?,
                fallback: Icons.inventory_2_outlined,
                width: double.infinity,
                height: double.infinity,
                iconSize: 72,
                borderRadius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasName ? name : 'Box $id',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (hasName) Text('Box $id'),
                        if (dimensions != null)
                          Text(
                            dimensions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ?menuButton,
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return OverviewContextMenu<_BoxAction>(
      key: Key('box-context-menu-region-$id'),
      menuButtonKey: Key('box-context-menu-button-$id'),
      tooltip: context.l10n.boxActions(hasName ? name : 'Box $id'),
      onSelected: (action) => _boxAction(action, box),
      itemBuilder: archived ? _archivedBoxMenu : _boxMenu,
      builder: (context, button) => card(button),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final values = _archived
        ? sortSharedArchiveRecords(
            widget.boxes,
            order: settings.boxArchiveSortOrder,
            displayName: boxLabel,
          )
        : sortSharedBoxesForOverview(
            widget.boxes.where(
              (box) => (box['status'] == 'archived') == _archived,
            ),
            settings.boxSortOrder,
          );

    return ConstrainedPageWidth(
      child: Scaffold(
        appBar: AppBar(
          leading: _archived
              ? IconButton(
                  tooltip: sharedText(context, 'Back', 'Zurück'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          title: Text(
            _archived
                ? context.l10n.archivedBoxes
                : context.l10n.navigationBoxes,
          ),
          actions: [
            if (_archived)
              PopupMenuButton<ArchiveSortCriterion>(
                key: const Key('box-archive-sort-button'),
                tooltip: context.l10n.sortArchivedBoxes,
                icon: const Icon(Icons.sort),
                initialValue: settings.boxArchiveSortOrder.criterion,
                onSelected: (criterion) {
                  final current = settings.boxArchiveSortOrder;
                  settings.setBoxArchiveSortOrder(
                    criterion == current.criterion
                        ? current.reversed
                        : criterion.defaultOrder,
                  );
                },
                itemBuilder: (context) => [
                  for (final criterion in ArchiveSortCriterion.values)
                    CheckedPopupMenuItem<ArchiveSortCriterion>(
                      key: Key('box-archive-sort-option-${criterion.name}'),
                      value: criterion,
                      checked:
                          criterion == settings.boxArchiveSortOrder.criterion,
                      child: Text(
                        context.l10n.archiveSortCriterionMenuLabel(
                          criterion,
                          activeOrder:
                              criterion ==
                                  settings.boxArchiveSortOrder.criterion
                              ? settings.boxArchiveSortOrder
                              : null,
                        ),
                      ),
                    ),
                ],
              )
            else
              PopupMenuButton<BoxSortCriterion>(
                key: const Key('box-sort-button'),
                initialValue: settings.boxSortOrder.criterion,
                tooltip: context.l10n.sortBoxes,
                icon: const Icon(Icons.sort),
                onSelected: (criterion) {
                  final current = settings.boxSortOrder;
                  settings.setBoxSortOrder(
                    criterion == current.criterion
                        ? current.reversed
                        : criterion.defaultOrder,
                  );
                },
                itemBuilder: (context) => [
                  for (final criterion in BoxSortCriterion.values)
                    CheckedPopupMenuItem<BoxSortCriterion>(
                      key: Key('box-sort-option-${criterion.name}'),
                      value: criterion,
                      checked: criterion == settings.boxSortOrder.criterion,
                      child: Text(
                        context.l10n.boxSortCriterionMenuLabel(
                          criterion,
                          activeOrder:
                              criterion == settings.boxSortOrder.criterion
                              ? settings.boxSortOrder
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            if (!_archived)
              IconButton(
                key: const Key('box-archive-button'),
                tooltip: context.l10n.archivedBoxes,
                onPressed: _openArchive,
                icon: const Icon(Icons.inventory_2_outlined),
              ),
            if (!_archived)
              IconButton(
                key: const Key('shared-box-scan-button'),
                tooltip: context.l10n.scanBoxTitle,
                onPressed: widget.connected && widget.api.connected
                    ? () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => SharedBoxScannerPage(
                              api: widget.api,
                              boxes: widget.boxes,
                              animals: widget.animals,
                              change: widget.change,
                            ),
                          ),
                        );
                        if (mounted) await _reload();
                      }
                    : null,
                icon: const Icon(Icons.qr_code_scanner),
              ),
            if (!_archived)
              IconButton(
                key: const Key('shared-feeding-mode-button'),
                tooltip: context.l10n.feedingModeTitle,
                onPressed: widget.connected && widget.api.connected
                    ? _openFeedingMode
                    : null,
                icon: const Icon(Icons.restaurant_menu),
              ),
            IconButton(
              key: const Key('shared-refresh'),
              tooltip: sharedText(context, 'Reload', 'Neu laden'),
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: _archived
            ? null
            : FloatingActionButton(
                key: const Key('add-box-button'),
                heroTag: 'shared-box-add',
                tooltip: context.l10n.addBox,
                onPressed: widget.connected
                    ? () => Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SharedBoxForm(
                            api: widget.api,
                            change: widget.change,
                          ),
                        ),
                      )
                    : null,
                child: const Icon(Icons.add),
              ),
        body: values.isEmpty
            ? Center(
                child: Text(
                  _archived
                      ? sharedText(
                          context,
                          'No archived Boxes',
                          'Keine archivierten Boxen',
                        )
                      : context.l10n.noBoxesAvailable,
                ),
              )
            : !_archived && settings.bigPictureModeEnabled
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final columns = switch (constraints.maxWidth) {
                    >= 1000 => 3,
                    >= 600 => 2,
                    _ => 1,
                  };
                  return GridView.builder(
                    key: PageStorageKey<String>(
                      _archived
                          ? 'shared-boxes-archive-grid'
                          : 'shared-boxes-overview-grid',
                    ),
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 1 ? 1.45 : 1.15,
                    ),
                    itemCount: values.length,
                    itemBuilder: (context, index) =>
                        _bigPictureBoxCard(values[index], _archived),
                  );
                },
              )
            : ListView.builder(
                key: PageStorageKey<String>(
                  _archived ? 'shared-boxes-archive' : 'shared-boxes-overview',
                ),
                itemCount: values.length,
                itemBuilder: (context, index) {
                  final box = values[index];
                  final id = recordId(box);
                  final name = (box['name'] as String?)?.trim();
                  final hasName = name != null && name.isNotEmpty;
                  final dimensions = _boxDimensions(box);
                  Widget tile(Widget? menuButton) => ListTile(
                    key: Key('box-list-item-$id'),
                    leading: SharedThumbnail(
                      api: widget.api,
                      images: _images,
                      mediaId: box['pictureMediaId'] as int?,
                      fallback: Icons.inventory_2_outlined,
                    ),
                    title: Text(hasName ? name : 'Box $id'),
                    subtitle: _archived
                        ? Text(sharedArchiveSummary(context, box, box: true))
                        : hasName
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Box $id'),
                              if (dimensions != null) Text(dimensions),
                            ],
                          )
                        : dimensions == null
                        ? null
                        : Text(dimensions),
                    isThreeLine: !_archived && hasName && dimensions != null,
                    trailing: menuButton,
                    onTap: () => _openBox(box),
                  );
                  return OverviewContextMenu<_BoxAction>(
                    key: Key('box-context-menu-region-$id'),
                    menuButtonKey: Key('box-context-menu-button-$id'),
                    tooltip: context.l10n.boxActions(
                      hasName ? name : 'Box $id',
                    ),
                    onSelected: (action) => _boxAction(action, box),
                    itemBuilder: _archived ? _archivedBoxMenu : _boxMenu,
                    builder: (context, button) => tile(button),
                  );
                },
              ),
      ),
    );
  }
}
