import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/qr/qr_export_service.dart';
import '../../../../core/qr/qr_file_name.dart';
import '../../../../core/qr/qr_print_service.dart';
import '../../../../core/qr/qr_storage_service.dart';
import '../../../animals/presentation/pages/animal_detail_page.dart';
import '../widgets/box_qr_code.dart';

class BoxDetailPage extends StatefulWidget {
  final AppDatabase database;
  final Box box;
  final QrExporter qrExporter;
  final QrStorage qrStorage;
  final QrPrinter qrPrinter;

  const BoxDetailPage({
    super.key,
    required this.database,
    required this.box,
    this.qrExporter = const QrExportService(),
    this.qrStorage = const QrStorageService(),
    this.qrPrinter = const QrPrintService(),
  });

  @override
  State<BoxDetailPage> createState() => _BoxDetailPageState();
}

class _BoxDetailPageState extends State<BoxDetailPage> {
  late Future<List<Animal>> _animalsFuture;

  bool _savingQr = false;
  bool _printingQr = false;
  bool _deleting = false;

  String? _saveError;
  String? _printError;
  String? _deleteError;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  void _loadAnimals() {
    _animalsFuture = AnimalRepository(
      widget.database,
    ).getAnimalsForBox(widget.box.id);
  }

  Future<void> _openAnimalDetail(Animal animal) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalDetailPage(
          database: widget.database,
          animalId: animal.id,
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
    setState(() {
      _savingQr = true;
      _saveError = null;
    });

    try {
      final pngBytes = await widget.qrExporter.exportPng(
        qrId: widget.box.qrId,
      );

      final fileName = buildBoxQrFileName(
        widget.box.qrId,
      );

      await widget.qrStorage.savePng(
        bytes: pngBytes,
        fileName: fileName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _savingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code saved'),
        ),
      );
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
    setState(() {
      _printingQr = true;
      _printError = null;
    });

    try {
      final pngBytes = await widget.qrExporter.exportPng(
        qrId: widget.box.qrId,
      );

      await widget.qrPrinter.printQrCode(
        pngBytes: pngBytes,
        qrId: widget.box.qrId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _printingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code sent to printer'),
        ),
      );
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
    if (_deleting) {
      return;
    }

    setState(() {
      _deleteError = null;
    });

    try {
      // Re-query the database instead of relying on the currently displayed
      // list. This prevents deleting a box based on stale UI state.
      final animals = await AnimalRepository(
        widget.database,
      ).getAnimalsForBox(widget.box.id);

      if (!mounted) {
        return;
      }

      if (animals.isNotEmpty) {
        await _showCannotDeleteDialog(
          animals.length,
        );
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

      final deleted = await BoxRepository(
        widget.database,
      ).deleteBox(widget.box.id);

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

  Future<void> _showCannotDeleteDialog(
    int animalCount,
  ) {
    final animalText = animalCount == 1
        ? '1 animal is assigned to this box.'
        : '$animalCount animals are assigned to this box.';

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Cannot Delete Box',
          ),
          content: Text(
            '$animalText\n\n'
            'Move or delete the assigned animals before deleting the box.',
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

  @override
  Widget build(BuildContext context) {
    final box = widget.box;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Box Details'),
        actions: [
          IconButton(
            key: const Key('save-qr-button'),
            onPressed: _savingQr ? null : _saveQrCode,
            icon: _savingQr
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.download_outlined,
                  ),
            tooltip: 'Save QR Code',
          ),
          IconButton(
            key: const Key('print-qr-button'),
            onPressed: _printingQr ? null : _printQrCode,
            icon: _printingQr
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.print_outlined,
                  ),
            tooltip: 'Print QR Code',
          ),
          IconButton(
            key: const Key('delete-box-button'),
            onPressed: _deleting ? null : _deleteBox,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.delete_outline,
                  ),
            tooltip: 'Delete Box',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_saveError != null) ...[
            Text(
              _saveError!,
              key: const Key('qr-save-error'),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_printError != null) ...[
            Text(
              _printError!,
              key: const Key('qr-print-error'),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_deleteError != null) ...[
            Text(
              _deleteError!,
              key: const Key('box-delete-error'),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
          ],

          Center(
            child: BoxQrCode(
              key: const Key('box-qr-code'),
              qrId: box.qrId,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'QR Identifier',
            style: Theme.of(
              context,
            ).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          SelectableText(
            box.qrId,
            key: const Key('box-qr-id'),
          ),
          const SizedBox(height: 24),

          _DetailRow(
            label: 'Box ID',
            value: box.id.toString(),
          ),

          _DetailRow(
            label: 'Created',
            value: _formatDateTime(
              box.createdAt,
            ),
          ),

          _DetailRow(
            label: 'Updated',
            value: _formatDateTime(
              box.updatedAt,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Assigned Animals',
                  key: const Key(
                    'assigned-animals-heading',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium,
                ),
              ),
              const Icon(
                Icons.pets_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),

          FutureBuilder<List<Animal>>(
            future: _animalsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  child: Text(
                    'Failed to load assigned animals',
                    key: Key(
                      'assigned-animals-error',
                    ),
                  ),
                );
              }

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final animals = snapshot.data ?? [];

              if (animals.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  child: Text(
                    'No animals assigned to this box',
                    key: Key(
                      'no-assigned-animals',
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final animal in animals)
                    Card(
                      child: ListTile(
                        key: Key(
                          'assigned-animal-${animal.id}',
                        ),
                        leading: const Icon(
                          Icons.pets_outlined,
                        ),
                        title: Text(
                          animal.commonName,
                        ),
                        subtitle: Text(
                          animal.latinName,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                        ),
                        onTap: () {
                          _openAnimalDetail(
                            animal,
                          );
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
    );
  }

  String _formatDateTime(
    DateTime dateTime,
  ) {
    final day = dateTime.day
        .toString()
        .padLeft(2, '0');

    final month = dateTime.month
        .toString()
        .padLeft(2, '0');

    final year = dateTime.year.toString();

    final hour = dateTime.hour
        .toString()
        .padLeft(2, '0');

    final minute = dateTime.minute
        .toString()
        .padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}