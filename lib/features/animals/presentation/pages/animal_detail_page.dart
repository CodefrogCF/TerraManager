import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/animal_archive_reason.dart';
import '../../../../core/database/enums/animal_status.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../feedings/presentation/pages/feeding_history_page.dart';
import '../widgets/animal_picture.dart';
import 'animal_edit_page.dart';

class AnimalDetailPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;

  const AnimalDetailPage({
    super.key,
    required this.database,
    required this.animalId,
  });

  @override
  State<AnimalDetailPage> createState() => _AnimalDetailPageState();
}

class _AnimalDetailPageState extends State<AnimalDetailPage> {
  late Future<Animal?> _animalFuture;

  bool _lifecycleActionInProgress = false;
  String? _lifecycleError;

  @override
  void initState() {
    super.initState();
    _loadAnimal();
  }

  void _loadAnimal() {
    _animalFuture =
        AnimalRepository(widget.database).getAnimalById(widget.animalId);
  }

  Future<void> _openEditPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnimalEditPage(
          database: widget.database,
          animalId: widget.animalId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      setState(() {
        _loadAnimal();
      });
    }
  }

  Future<void> _openFeedingHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedingHistoryPage(
          database: widget.database,
          animalId: widget.animalId,
        ),
      ),
    );
  }

  Future<void> _archiveAnimal(
    Animal animal,
  ) async {
    if (_lifecycleActionInProgress ||
        animal.status != AnimalStatus.active) {
      return;
    }

    final result = await showDialog<_ArchiveAnimalResult>(
      context: context,
      builder: (_) => const _ArchiveAnimalDialog(),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _lifecycleActionInProgress = true;
      _lifecycleError = null;
    });

    try {
      final success =
          await AnimalRepository(widget.database).archiveAnimal(
        animalId: animal.id,
        reason: result.reason,
        archivedAt: result.archivedAt,
        archiveNotes: result.notes,
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _lifecycleActionInProgress = false;
          _lifecycleError = 'Failed to archive animal';
        });

        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _loadAnimal();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Animal archived'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _lifecycleError = 'Failed to archive animal';
      });
    }
  }

  Future<void> _restoreAnimal(
    Animal animal,
  ) async {
    if (_lifecycleActionInProgress ||
        animal.status != AnimalStatus.archived) {
      return;
    }

    setState(() {
      _lifecycleError = null;
    });

    List<Box> boxes;

    try {
      boxes = await BoxRepository(widget.database).getAllBoxes();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lifecycleError = 'Failed to load boxes';
      });

      return;
    }

    if (!mounted) {
      return;
    }

    if (boxes.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('No Boxes Available'),
            content: const Text(
              'Create a box before restoring this animal.',
            ),
            actions: [
              TextButton(
                key: const Key(
                  'close-no-boxes-dialog-button',
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return;
    }

    final selectedBoxId = await showDialog<int>(
      context: context,
      builder: (_) => _RestoreAnimalDialog(
        boxes: boxes,
      ),
    );

    if (selectedBoxId == null || !mounted) {
      return;
    }

    setState(() {
      _lifecycleActionInProgress = true;
      _lifecycleError = null;
    });

    try {
      final success =
          await AnimalRepository(widget.database).restoreAnimal(
        animalId: animal.id,
        boxId: selectedBoxId,
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _lifecycleActionInProgress = false;
          _lifecycleError = 'Failed to restore animal';
        });

        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _loadAnimal();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Animal restored'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _lifecycleError = 'Failed to restore animal';
      });
    }
  }

  Future<void> _permanentlyDeleteAnimal(
    Animal animal,
  ) async {
    if (_lifecycleActionInProgress ||
        animal.status != AnimalStatus.archived) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key(
            'permanent-delete-animal-dialog',
          ),
          title: const Text(
            'Permanently Delete Animal?',
          ),
          content: const Text(
            'The animal and all associated feeding history '
            'will be permanently removed. This cannot be undone.',
          ),
          actions: [
            TextButton(
              key: const Key(
                'cancel-permanent-delete-animal-button',
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key(
                'confirm-permanent-delete-animal-button',
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Delete Permanently',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _lifecycleActionInProgress = true;
      _lifecycleError = null;
    });

    try {
      final success =
          await AnimalRepository(widget.database)
              .permanentlyDeleteArchivedAnimal(
        animal.id,
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _lifecycleActionInProgress = false;
          _lifecycleError =
              'Failed to permanently delete animal';
        });

        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _lifecycleError =
            'Failed to permanently delete animal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Animal?>(
      future: _animalFuture,
      builder: (context, snapshot) {
        final animal = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Animal Details'),
            actions: [
              if (animal != null)
                IconButton(
                  key: const Key(
                    'feeding-history-button',
                  ),
                  onPressed: _openFeedingHistory,
                  icon: const Icon(
                    Icons.restaurant,
                  ),
                  tooltip: 'Feeding History',
                ),
              if (animal != null &&
                  animal.status == AnimalStatus.active)
                IconButton(
                  key: const Key(
                    'edit-animal-button',
                  ),
                  onPressed: _lifecycleActionInProgress
                      ? null
                      : _openEditPage,
                  icon: const Icon(
                    Icons.edit,
                  ),
                  tooltip: 'Edit Animal',
                ),
            ],
          ),
          body: _buildBody(
            context,
            snapshot,
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<Animal?> snapshot,
  ) {
    if (snapshot.hasError) {
      return const Center(
        child: Text('Failed to load animal'),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final animal = snapshot.data;

    if (animal == null) {
      return const Center(
        child: Text('Animal not found'),
      );
    }

    final isArchived =
        animal.status == AnimalStatus.archived;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_lifecycleError != null) ...[
          Text(
            _lifecycleError!,
            key: const Key(
              'animal-lifecycle-error',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
        ],

        AnimalPicture(
          key: const Key('animal-picture'),
          picturePath: animal.picturePath,
        ),
        const SizedBox(height: 24),

        Text(
          animal.commonName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),

        Text(
          animal.latinName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),

        _DetailRow(
          label: 'Status',
          value: isArchived
              ? 'Archived'
              : 'Active',
        ),

        if (!isArchived && animal.boxId != null)
          _DetailRow(
            label: 'Box',
            value: 'Box ${animal.boxId}',
          ),

        if (animal.sex != null)
          _DetailRow(
            label: 'Sex',
            value: animal.sex.toString(),
          ),

        if (animal.birthDate != null)
          _DetailRow(
            label: 'Birth date',
            value: _formatDate(
              animal.birthDate!,
            ),
          ),

        if (animal.birthDateAccuracy != null)
          _DetailRow(
            label: 'Birth date accuracy',
            value: animal.birthDateAccuracy.toString(),
          ),

        _DetailRow(
          label: 'Temperature',
          value:
              '${animal.tempMin} °C – ${animal.tempMax} °C',
        ),

        _DetailRow(
          label: 'Humidity',
          value:
              '${animal.humidityMin}% – ${animal.humidityMax}%',
        ),

        if (animal.notes != null &&
            animal.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),

          Text(
            'Notes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Text(
            animal.notes!,
          ),
        ],

        if (isArchived) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            'Archive Information',
            key: const Key(
              'archive-information-heading',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          if (animal.archiveReason != null)
            _DetailRow(
              label: 'Reason',
              value: _archiveReasonLabel(
                animal.archiveReason!,
              ),
            ),

          if (animal.archivedAt != null)
            _DetailRow(
              label: 'Archive date',
              value: _formatDate(
                animal.archivedAt!,
              ),
            ),

          if (animal.archiveNotes != null &&
              animal.archiveNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),

            Text(
              'Archive note',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            Text(
              animal.archiveNotes!,
              key: const Key(
                'archive-notes',
              ),
            ),
          ],

          const SizedBox(height: 24),

          FilledButton.icon(
            key: const Key(
              'restore-animal-button',
            ),
            onPressed: _lifecycleActionInProgress
                ? null
                : () => _restoreAnimal(
                      animal,
                    ),
            icon: _lifecycleActionInProgress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.restore,
                  ),
            label: const Text(
              'Restore Animal',
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            key: const Key(
              'permanent-delete-animal-button',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.error,
            ),
            onPressed: _lifecycleActionInProgress
                ? null
                : () => _permanentlyDeleteAnimal(
                      animal,
                    ),
            icon: const Icon(
              Icons.delete_forever_outlined,
            ),
            label: const Text(
              'Delete Permanently',
            ),
          ),
        ] else ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            key: const Key(
              'archive-animal-button',
            ),
            onPressed: _lifecycleActionInProgress
                ? null
                : () => _archiveAnimal(
                      animal,
                    ),
            icon: _lifecycleActionInProgress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.archive_outlined,
                  ),
            label: const Text(
              'Archive Animal',
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

class _ArchiveAnimalDialog extends StatefulWidget {
  const _ArchiveAnimalDialog();

  @override
  State<_ArchiveAnimalDialog> createState() =>
      _ArchiveAnimalDialogState();
}

class _ArchiveAnimalDialogState
    extends State<_ArchiveAnimalDialog> {
  final TextEditingController _notesController =
      TextEditingController();

  AnimalArchiveReason? _reason;
  late DateTime _archiveDate;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _archiveDate = DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _archiveDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _archiveDate = selected;
    });
  }

  void _confirm() {
    final reason = _reason;

    if (reason == null) {
      return;
    }

    final notes =
        _notesController.text.trim();

    Navigator.of(context).pop(
      _ArchiveAnimalResult(
        reason: reason,
        archivedAt: _archiveDate,
        notes: notes.isEmpty
            ? null
            : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key(
        'archive-animal-dialog',
      ),
      scrollable: true,
      title: const Text(
        'Archive Animal',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Archive this animal and remove it from its current box?',
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<AnimalArchiveReason>(
            key: const Key(
              'archive-reason-field',
            ),
            initialValue: _reason,
            decoration: const InputDecoration(
              labelText: 'Reason',
            ),
            items: AnimalArchiveReason.values
                .map(
                  (reason) => DropdownMenuItem<
                      AnimalArchiveReason>(
                    value: reason,
                    child: Text(
                      _archiveReasonLabel(
                        reason,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _reason = value;
              });
            },
          ),
          const SizedBox(height: 16),

          ListTile(
            key: const Key(
              'archive-date-field',
            ),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Archive Date',
            ),
            subtitle: Text(
              _formatDate(
                _archiveDate,
              ),
            ),
            trailing: const Icon(
              Icons.calendar_today,
            ),
            onTap: _selectDate,
          ),
          const SizedBox(height: 16),

          TextField(
            key: const Key(
              'archive-notes-field',
            ),
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Optional',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key(
            'cancel-archive-animal-button',
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          key: const Key(
            'confirm-archive-animal-button',
          ),
          onPressed: _reason == null
              ? null
              : _confirm,
          child: const Text(
            'Archive',
          ),
        ),
      ],
    );
  }
}

class _RestoreAnimalDialog extends StatefulWidget {
  final List<Box> boxes;

  const _RestoreAnimalDialog({
    required this.boxes,
  });

  @override
  State<_RestoreAnimalDialog> createState() =>
      _RestoreAnimalDialogState();
}

class _RestoreAnimalDialogState
    extends State<_RestoreAnimalDialog> {
  int? _boxId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key(
        'restore-animal-dialog',
      ),
      title: const Text(
        'Restore Animal',
      ),
      content: DropdownButtonFormField<int>(
        key: const Key(
          'restore-box-field',
        ),
        initialValue: _boxId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Assign to Box',
        ),
        items: widget.boxes
            .map(
              (box) => DropdownMenuItem<int>(
                value: box.id,
                child: Text(
                  box.qrId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _boxId = value;
          });
        },
      ),
      actions: [
        TextButton(
          key: const Key(
            'cancel-restore-animal-button',
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          key: const Key(
            'confirm-restore-animal-button',
          ),
          onPressed: _boxId == null
              ? null
              : () {
                  Navigator.of(context).pop(
                    _boxId,
                  );
                },
          child: const Text(
            'Restore',
          ),
        ),
      ],
    );
  }
}

class _ArchiveAnimalResult {
  final AnimalArchiveReason reason;
  final DateTime archivedAt;
  final String? notes;

  const _ArchiveAnimalResult({
    required this.reason,
    required this.archivedAt,
    this.notes,
  });
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}

String _archiveReasonLabel(
  AnimalArchiveReason reason,
) {
  switch (reason) {
    case AnimalArchiveReason.sold:
      return 'Sold';

    case AnimalArchiveReason.traded:
      return 'Traded';

    case AnimalArchiveReason.deceased:
      return 'Deceased';

    case AnimalArchiveReason.rehomed:
      return 'Rehomed';

    case AnimalArchiveReason.other:
      return 'Other';
  }
}

String _formatDate(
  DateTime date,
) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}