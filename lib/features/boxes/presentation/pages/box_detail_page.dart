import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
import '../../../../core/qr/qr_export_service.dart';
import '../../../../core/qr/qr_file_name.dart';
import '../../../../core/qr/qr_storage_service.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../animals/presentation/animal_display_names.dart';
import '../../../animals/presentation/pages/animal_detail_page.dart';
import '../../../animals/presentation/pages/new_animal_page.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import 'box_edit_page.dart';
import '../widgets/box_picture.dart';
import '../widgets/box_qr_code.dart';

class BoxDetailPage extends StatefulWidget {
  final AppDatabase database;
  final Box box;
  final DetailNavigationContext? navigationContext;
  final QrExporter qrExporter;
  final QrStorage qrStorage;

  BoxDetailPage({
    super.key,
    required this.database,
    required this.box,
    this.navigationContext,
    this.qrExporter = const QrExportService(),
    this.qrStorage = const QrStorageService(),
  }) : assert(
         navigationContext == null ||
             navigationContext.source == DetailNavigationSource.boxes,
         'Box details require a box navigation context.',
       ),
       assert(
         navigationContext == null ||
             navigationContext.currentRecordId == box.id,
         'The navigation context must identify the displayed box.',
       );

  @override
  State<BoxDetailPage> createState() => _BoxDetailPageState();
}

class _BoxDetailPageState extends State<BoxDetailPage> {
  static const double _minimumSwipeDistance = 72;

  late Box _box;

  DetailNavigationContext? _navigationContext;
  late Future<List<Animal>> _animalsFuture;
  late Future<MediaAsset?> _pictureFuture;

  final Map<int, Future<MediaAsset?>> _animalPictureFutures = {};

  double _horizontalDragDistance = 0;
  bool _switchingBox = false;
  bool _savingQr = false;
  bool _deleting = false;
  bool _openingNewAnimal = false;

  String? _saveError;
  String? _deleteError;
  String? _refreshError;

  @override
  void initState() {
    super.initState();

    _box = widget.box;
    _navigationContext = widget.navigationContext;

    _loadAnimals();
    _loadPicture();
  }

  void _loadAnimals() {
    _animalPictureFutures.clear();

    _animalsFuture = AnimalRepository(widget.database)
        .getAnimalsForBox(_box.id);
  }

  Future<MediaAsset?> _animalPictureFutureFor(int? mediaId) {
    if (mediaId == null) {
      return Future<MediaAsset?>.value(null);
    }

    return _animalPictureFutures.putIfAbsent(
      mediaId,
      () => MediaRepository(widget.database).getMediaById(mediaId),
    );
  }

  void _loadPicture() {
    final pictureMediaId = _box.pictureMediaId;

    if (pictureMediaId == null) {
      _pictureFuture = Future.value(null);
      return;
    }

    _pictureFuture = MediaRepository(widget.database)
        .getMediaById(pictureMediaId);
  }

  Future<void> _refreshBox() async {
    try {
      final box = await BoxRepository(widget.database).getBoxById(_box.id);

      if (!mounted) {
        return;
      }

      if (box == null) {
        setState(() {
          _refreshError = context.l10n.boxNoLongerExists;
        });

        return;
      }

      setState(() {
        _box = box;
        _refreshError = null;

        _loadPicture();
        _loadAnimals();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _refreshError = context.l10n.failedToRefreshBox;
      });
    }
  }

  Future<void> _openEditPage() async {
    if (_switchingBox) {
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BoxEditPage(database: widget.database, boxId: _box.id),
      ),
    );

    if (!mounted || changed != true) {
      return;
    }

    await _refreshBox();
  }

  Future<void> _openAnimalDetail(Animal animal, List<Animal> animals) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalDetailPage(
          database: widget.database,
          animalId: animal.id,
          navigationContext: DetailNavigationContext.animalsForBox(
            animalIds: animals.map((animal) => animal.id),
            currentAnimalId: animal.id,
            boxId: _box.id,
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadAnimals();
    });
  }

  Future<void> _openNewAnimalPage() async {
    if (_switchingBox || _deleting || _openingNewAnimal) {
      return;
    }

    setState(() {
      _openingNewAnimal = true;
    });

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            NewAnimalPage(database: widget.database, initialBoxId: _box.id),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _openingNewAnimal = false;

      if (created == true) {
        _loadAnimals();
      }
    });
  }

  Widget _buildAddAnimalButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        key: const Key('add-animal-to-box-button'),
        onPressed: _switchingBox || _deleting || _openingNewAnimal
            ? null
            : _openNewAnimalPage,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addAnimal),
      ),
    );
  }

  Future<void> _saveQrCode() async {
    if (_switchingBox || _savingQr) {
      return;
    }

    setState(() {
      _savingQr = true;
      _saveError = null;
    });

    try {
      final pngBytes = await widget.qrExporter.exportPng(qrId: _box.qrId);

      final fileName = buildBoxQrFileName(_box.qrId);

      await widget.qrStorage.savePng(bytes: pngBytes, fileName: fileName);

      if (!mounted) {
        return;
      }

      setState(() {
        _savingQr = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.qrCodeSaved)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingQr = false;
        _saveError = context.l10n.failedToSaveQrCode;
      });
    }
  }

  Future<void> _deleteBox() async {
    if (_switchingBox || _deleting) {
      return;
    }

    setState(() {
      _deleteError = null;
    });

    try {
      final animals = await AnimalRepository(widget.database)
          .getAnimalsForBox(_box.id);

      if (!mounted) {
        return;
      }

      if (animals.isNotEmpty) {
        await _showCannotDeleteDialog(animals.length);

        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(context.l10n.deleteBoxQuestion),
            content: Text(context.l10n.deleteBoxWarning),
            actions: [
              TextButton(
                key: const Key('cancel-delete-box-button'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                key: const Key('confirm-delete-box-button'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(context.l10n.delete),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      setState(() {
        _deleting = true;
      });

      final deleted = await BoxRepository(widget.database).deleteBox(_box.id);

      if (!mounted) {
        return;
      }

      if (!deleted) {
        setState(() {
          _deleting = false;
          _deleteError = context.l10n.failedToDeleteBox;
        });

        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deleting = false;
        _deleteError = context.l10n.failedToDeleteBox;
      });
    }
  }

  Future<void> _showCannotDeleteDialog(int animalCount) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.cannotDeleteBox),
          content: Text(context.l10n.assignedAnimalsPreventDelete(animalCount)),
          actions: [
            TextButton(
              key: const Key('close-cannot-delete-button'),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.ok),
            ),
          ],
        );
      },
    );
  }

  void _handleHorizontalDragStart(DragStartDetails _) {
    _horizontalDragDistance = 0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? 0;
  }

  void _handleHorizontalDragEnd(DragEndDetails _) {
    final dragDistance = _horizontalDragDistance;

    _horizontalDragDistance = 0;

    if (_switchingBox || _savingQr || _deleting) {
      return;
    }

    if (dragDistance <= -_minimumSwipeDistance) {
      _showAdjacentBox(next: true);
    } else if (dragDistance >= _minimumSwipeDistance) {
      _showAdjacentBox(next: false);
    }
  }

  void _handleHorizontalDragCancel() {
    _horizontalDragDistance = 0;
  }

  Future<void> _showAdjacentBox({required bool next}) async {
    final navigationContext = _navigationContext;

    if (navigationContext == null || _switchingBox) {
      return;
    }

    final targetBoxId = next
        ? navigationContext.nextRecordId
        : navigationContext.previousRecordId;

    if (targetBoxId == null) {
      return;
    }

    setState(() {
      _switchingBox = true;
      _refreshError = null;
    });

    try {
      final box = await BoxRepository(widget.database).getBoxById(targetBoxId);

      if (!mounted) {
        return;
      }

      if (box == null) {
        final remainingIds = navigationContext.recordIds.where(
          (recordId) => recordId != targetBoxId,
        );

        setState(() {
          _navigationContext = navigationContext.withRecordIds(remainingIds);
          _switchingBox = false;
          _refreshError = context.l10n.boxNoLongerExists;
        });

        return;
      }

      setState(() {
        _box = box;
        _navigationContext = navigationContext.selectRecord(targetBoxId);
        _switchingBox = false;
        _saveError = null;
        _deleteError = null;
        _refreshError = null;

        _loadPicture();
        _loadAnimals();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _switchingBox = false;
        _refreshError = context.l10n.failedToLoadBox;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.boxLabel(box.id),
          key: const Key('box-detail-title'),
        ),
        actions: [
          IconButton(
            key: const Key('edit-box-button'),
            onPressed: _switchingBox || _deleting ? null : _openEditPage,
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.l10n.editBoxTooltip,
          ),
          IconButton(
            key: const Key('delete-box-button'),
            onPressed: _switchingBox || _deleting ? null : _deleteBox,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            tooltip: context.l10n.deleteBox,
          ),
        ],
      ),
      body: GestureDetector(
        key: const Key('box-detail-swipe-area'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _navigationContext == null
            ? null
            : _handleHorizontalDragStart,
        onHorizontalDragUpdate: _navigationContext == null
            ? null
            : _handleHorizontalDragUpdate,
        onHorizontalDragEnd: _navigationContext == null
            ? null
            : _handleHorizontalDragEnd,
        onHorizontalDragCancel: _navigationContext == null
            ? null
            : _handleHorizontalDragCancel,
        child: ListView(
          key: ValueKey<String>('box-detail-list-${box.id}'),
          padding: const EdgeInsets.all(16),
          children: [
            if (_switchingBox) ...[
              const LinearProgressIndicator(
                key: Key('box-switching-indicator'),
              ),
              const SizedBox(height: 16),
            ],

            if (_refreshError != null) ...[
              Text(
                _refreshError!,
                key: const Key('box-refresh-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],

            if (_deleteError != null) ...[
              Text(
                _deleteError!,
                key: const Key('box-delete-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],

            FutureBuilder<MediaAsset?>(
              key: ValueKey<String>('box-picture-${box.id}'),
              future: _pictureFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return BoxPicture(
                  key: const Key('box-detail-picture'),
                  pictureBytes: snapshot.data?.data,
                  emptyText: snapshot.hasError
                      ? context.l10n.imageUnavailable
                      : context.l10n.noPicture,
                );
              },
            ),
            const SizedBox(height: 24),

            Text(
              context.l10n.dimensions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            _DetailRow(
              key: const Key('box-width-row'),
              label: context.l10n.width,
              value: _formatDimension(context, box.widthCm),
            ),

            _DetailRow(
              key: const Key('box-height-row'),
              label: context.l10n.height,
              value: _formatDimension(context, box.heightCm),
            ),

            _DetailRow(
              key: const Key('box-depth-row'),
              label: context.l10n.depth,
              value: _formatDimension(context, box.depthCm),
            ),

            const SizedBox(height: 12),

            _DetailRow(label: context.l10n.boxId, value: box.id.toString()),

            _DetailRow(
              label: context.l10n.created,
              value: _formatDateTime(box.createdAt),
            ),

            _DetailRow(
              label: context.l10n.updated,
              value: _formatDateTime(box.updatedAt),
            ),

            if (box.notes != null && box.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),

              Text(
                context.l10n.notes,
                key: const Key('box-notes-heading'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              Text(box.notes!, key: const Key('box-notes')),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.assignedAnimals,
                    key: const Key('assigned-animals-heading'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.pets_outlined),
              ],
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<Animal>>(
              key: ValueKey<String>('box-animals-${box.id}'),
              future: _animalsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      context.l10n.failedToLoadAssignedAnimals,
                      key: const Key('assigned-animals-error'),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final animals = snapshot.data ?? [];

                if (animals.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          context.l10n.noAnimalsAssigned,
                          key: const Key('no-assigned-animals'),
                        ),
                      ),
                      _buildAddAnimalButton(),
                    ],
                  );
                }

                return Column(
                  children: [
                    for (final animal in animals)
                      Builder(
                        builder: (context) {
                          final displayNames = AnimalDisplayNames.fromContext(
                            context,
                            commonName: animal.commonName,
                            latinName: animal.latinName,
                          );

                          return Card(
                            child: ListTile(
                              key: Key('assigned-animal-${animal.id}'),
                              leading: FutureBuilder<MediaAsset?>(
                                future: _animalPictureFutureFor(
                                  animal.pictureMediaId,
                                ),
                                builder: (context, pictureSnapshot) {
                                  return MediaThumbnail(
                                    key: Key(
                                      'assigned-animal-thumbnail-${animal.id}',
                                    ),
                                    pictureBytes: pictureSnapshot.data?.data,
                                    picturePath: pictureSnapshot.data == null
                                        ? animal.picturePath
                                        : null,
                                    fallbackIcon: Icons.emoji_nature_outlined,
                                  );
                                },
                              ),
                              title: Text(displayNames.primary),
                              subtitle: Text(displayNames.secondary),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                _openAnimalDetail(animal, animals);
                              },
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    _buildAddAnimalButton(),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            Text(
              context.l10n.qrIdentifier,
              key: const Key('box-qr-section-heading'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            Center(
              child: BoxQrCode(key: const Key('box-qr-code'), qrId: box.qrId),
            ),
            const SizedBox(height: 16),

            SelectableText(
              box.qrId,
              key: const Key('box-qr-id'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.center,
              child: FilledButton.tonalIcon(
                key: const Key('save-qr-button'),
                onPressed: _switchingBox || _savingQr ? null : _saveQrCode,
                icon: _savingQr
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(context.l10n.saveQrCode),
              ),
            ),

            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveError!,
                key: const Key('qr-save-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDimension(BuildContext context, double? value) {
    if (value == null) {
      return context.l10n.notSpecified;
    }

    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();

    return context.l10n.centimeterValue(formatted);
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');

    final month = dateTime.month.toString().padLeft(2, '0');

    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
