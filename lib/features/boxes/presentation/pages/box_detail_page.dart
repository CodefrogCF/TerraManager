import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/qr/qr_export_service.dart';
import '../../../../core/qr/qr_file_name.dart';
import '../../../../core/qr/qr_print_service.dart';
import '../../../../core/qr/qr_storage_service.dart';
import '../../../../core/boxes/box_label.dart';
import '../../../animals/presentation/pages/animal_detail_page.dart';
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
  final QrPrinter qrPrinter;

  BoxDetailPage({
    super.key,
    required this.database,
    required this.box,
    this.navigationContext,
    this.qrExporter = const QrExportService(),
    this.qrStorage = const QrStorageService(),
    this.qrPrinter = const QrPrintService(),
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

  double _horizontalDragDistance = 0;
  bool _switchingBox = false;
  bool _savingQr = false;
  bool _printingQr = false;
  bool _deleting = false;

  String? _saveError;
  String? _printError;
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
    _animalsFuture = AnimalRepository(widget.database)
        .getAnimalsForBox(_box.id);
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
          _refreshError = 'Box no longer exists';
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
        _refreshError = 'Failed to refresh box';
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
          .showSnackBar(const SnackBar(content: Text('QR code saved')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingQr = false;
        _saveError = 'Failed to save QR code';
      });
    }
  }

  Future<void> _printQrCode() async {
    if (_switchingBox || _printingQr) {
      return;
    }

    setState(() {
      _printingQr = true;
      _printError = null;
    });

    try {
      final pngBytes = await widget.qrExporter.exportPng(qrId: _box.qrId);

      await widget.qrPrinter.printQrCode(pngBytes: pngBytes, qrId: _box.qrId);

      if (!mounted) {
        return;
      }

      setState(() {
        _printingQr = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR code sent to printer')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _printingQr = false;
        _printError = 'Failed to print QR code';
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
            title: const Text('Delete Box?'),
            content: const Text(
              'Delete this box permanently?\n\n'
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                key: const Key('cancel-delete-box-button'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-delete-box-button'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Delete'),
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
          _deleteError = 'Failed to delete box';
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
        _deleteError = 'Failed to delete box';
      });
    }
  }

  Future<void> _showCannotDeleteDialog(int animalCount) {
    final animalText = animalCount == 1
        ? '1 animal is assigned to this box.'
        : '$animalCount animals are assigned to this box.';

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cannot Delete Box'),
          content: Text(
            '$animalText\n\n'
            'Move or delete the assigned animals '
            'before deleting the box.',
          ),
          actions: [
            TextButton(
              key: const Key('close-cannot-delete-button'),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
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

    if (_switchingBox || _savingQr || _printingQr || _deleting) {
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
          _refreshError = 'Box no longer exists';
        });

        return;
      }

      setState(() {
        _box = box;
        _navigationContext = navigationContext.selectRecord(targetBoxId);
        _switchingBox = false;
        _saveError = null;
        _printError = null;
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
        _refreshError = 'Failed to load box';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;

    return Scaffold(
      appBar: AppBar(
        title: Text(buildBoxLabel(box.id), key: const Key('box-detail-title')),
        actions: [
          IconButton(
            key: const Key('edit-box-button'),
            onPressed: _switchingBox || _deleting ? null : _openEditPage,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Box',
          ),
          IconButton(
            key: const Key('save-qr-button'),
            onPressed: _switchingBox || _savingQr ? null : _saveQrCode,
            icon: _savingQr
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: 'Save QR Code',
          ),
          IconButton(
            key: const Key('print-qr-button'),
            onPressed: _switchingBox || _printingQr ? null : _printQrCode,
            icon: _printingQr
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: 'Print QR Code',
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
            tooltip: 'Delete Box',
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

            if (_saveError != null) ...[
              Text(
                _saveError!,
                key: const Key('qr-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],

            if (_printError != null) ...[
              Text(
                _printError!,
                key: const Key('qr-print-error'),
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
                      ? 'Image unavailable'
                      : 'No picture',
                );
              },
            ),
            const SizedBox(height: 24),

            Text('Dimensions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            _DetailRow(
              key: const Key('box-width-row'),
              label: 'Width',
              value: _formatDimension(box.widthCm),
            ),

            _DetailRow(
              key: const Key('box-height-row'),
              label: 'Height',
              value: _formatDimension(box.heightCm),
            ),

            _DetailRow(
              key: const Key('box-depth-row'),
              label: 'Depth',
              value: _formatDimension(box.depthCm),
            ),

            const SizedBox(height: 12),

            Center(
              child: BoxQrCode(key: const Key('box-qr-code'), qrId: box.qrId),
            ),
            const SizedBox(height: 24),

            Text(
              'QR Identifier',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            SelectableText(box.qrId, key: const Key('box-qr-id')),
            const SizedBox(height: 24),

            _DetailRow(label: 'Box ID', value: box.id.toString()),

            _DetailRow(label: 'Created', value: _formatDateTime(box.createdAt)),

            _DetailRow(label: 'Updated', value: _formatDateTime(box.updatedAt)),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Assigned Animals',
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
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Failed to load assigned animals',
                      key: Key('assigned-animals-error'),
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
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No animals assigned to this box',
                      key: Key('no-assigned-animals'),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final animal in animals)
                      Card(
                        child: ListTile(
                          key: Key('assigned-animal-${animal.id}'),
                          leading: const Icon(Icons.pets_outlined),
                          title: Text(animal.commonName),
                          subtitle: Text(animal.latinName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _openAnimalDetail(animal, animals);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDimension(double? value) {
    if (value == null) {
      return 'Not specified';
    }

    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();

    return '$formatted cm';
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
