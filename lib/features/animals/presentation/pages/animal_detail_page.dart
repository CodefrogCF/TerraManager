import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/animal_archive_reason.dart';
import '../../../../core/database/enums/animal_status.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/feeding_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../feedings/presentation/pages/feeding_history_page.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import '../widgets/animal_picture.dart';
import 'animal_edit_page.dart';

class AnimalDetailPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;
  final DetailNavigationContext? navigationContext;

  AnimalDetailPage({
    super.key,
    required this.database,
    required this.animalId,
    this.navigationContext,
  }) : assert(
         navigationContext == null ||
             navigationContext.source != DetailNavigationSource.boxes,
         'Animal details require an animal navigation context.',
       ),
       assert(
         navigationContext == null ||
             navigationContext.currentRecordId == animalId,
         'The navigation context must identify the displayed animal.',
       );

  @override
  State<AnimalDetailPage> createState() => _AnimalDetailPageState();
}

class _AnimalDetailPageState extends State<AnimalDetailPage> {
  static const double _minimumSwipeDistance = 72;

  late int _animalId;
  DetailNavigationContext? _navigationContext;
  late Future<Animal?> _animalFuture;
  late Future<FeedingEvent?> _latestFeedingFuture;
  late Future<MediaAsset?> _pictureMediaFuture;

  double _horizontalDragDistance = 0;
  bool _lifecycleActionInProgress = false;
  String? _lifecycleError;

  @override
  void initState() {
    super.initState();

    _animalId = widget.animalId;
    _navigationContext = widget.navigationContext;

    _loadAnimal();
    _loadLatestFeeding();
  }

  void _loadAnimal() {
    _animalFuture = AnimalRepository(widget.database).getAnimalById(_animalId);

    _pictureMediaFuture = _animalFuture.then((animal) async {
      final mediaId = animal?.pictureMediaId;

      if (mediaId == null) {
        return null;
      }

      return MediaRepository(widget.database).getMediaById(mediaId);
    });
  }

  void _loadLatestFeeding() {
    _latestFeedingFuture = FeedingRepository(widget.database)
        .getLatestFeeding(_animalId);
  }

  Future<void> _openEditPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AnimalEditPage(database: widget.database, animalId: _animalId),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result != true) {
      return;
    }

    final animal = await AnimalRepository(widget.database)
        .getAnimalById(_animalId);

    if (!mounted) {
      return;
    }

    setState(() {
      _invalidateNavigationContextIfNeeded(animal);
      _loadAnimal();
    });
  }

  Future<void> _openFeedingHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FeedingHistoryPage(database: widget.database, animalId: _animalId),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadLatestFeeding();
    });
  }

  Future<void> _archiveAnimal(Animal animal) async {
    if (_lifecycleActionInProgress || animal.status != AnimalStatus.active) {
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
      final success = await AnimalRepository(widget.database).archiveAnimal(
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
          _lifecycleError = context.l10n.failedToArchiveAnimal;
        });

        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _navigationContext = null;
        _loadAnimal();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.animalArchived)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _lifecycleError = context.l10n.failedToArchiveAnimal;
      });
    }
  }

  Future<void> _restoreAnimal(Animal animal) async {
    if (_lifecycleActionInProgress || animal.status != AnimalStatus.archived) {
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
        _lifecycleError = context.l10n.failedToLoadBoxes;
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
            title: Text(context.l10n.noBoxesAvailableTitle),
            content: Text(context.l10n.createBoxBeforeRestore),
            actions: [
              TextButton(
                key: const Key('close-no-boxes-dialog-button'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(context.l10n.ok),
              ),
            ],
          );
        },
      );

      return;
    }

    final selectedBoxId = await showDialog<int>(
      context: context,
      builder: (_) => _RestoreAnimalDialog(boxes: boxes),
    );

    if (selectedBoxId == null || !mounted) {
      return;
    }

    setState(() {
      _lifecycleActionInProgress = true;
      _lifecycleError = null;
    });

    try {
      final success = await AnimalRepository(widget.database)
          .restoreAnimal(animalId: animal.id, boxId: selectedBoxId);

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _lifecycleActionInProgress = false;
          _lifecycleError = context.l10n.failedToRestoreAnimal;
        });

        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _navigationContext = null;
        _loadAnimal();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.animalRestored)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lifecycleActionInProgress = false;
        _lifecycleError = context.l10n.failedToRestoreAnimal;
      });
    }
  }

  Future<void> _permanentlyDeleteAnimal(Animal animal) async {
    if (_lifecycleActionInProgress || animal.status != AnimalStatus.archived) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('permanent-delete-animal-dialog'),
          title: Text(context.l10n.permanentlyDeleteAnimalQuestion),
          content: Text(context.l10n.permanentlyDeleteAnimalWarning),
          actions: [
            TextButton(
              key: const Key('cancel-permanent-delete-animal-button'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('confirm-permanent-delete-animal-button'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(context.l10n.deletePermanently),
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
      final success = await AnimalRepository(widget.database)
          .permanentlyDeleteArchivedAnimal(animal.id);

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _lifecycleActionInProgress = false;
          _lifecycleError = context.l10n.failedToPermanentlyDeleteAnimal;
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
        _lifecycleError = context.l10n.failedToPermanentlyDeleteAnimal;
      });
    }
  }

  void _invalidateNavigationContextIfNeeded(Animal? animal) {
    final navigationContext = _navigationContext;

    if (navigationContext == null || animal == null) {
      return;
    }

    final remainsInSource = switch (navigationContext.source) {
      DetailNavigationSource.activeAnimals =>
        animal.status == AnimalStatus.active,
      DetailNavigationSource.archivedAnimals =>
        animal.status == AnimalStatus.archived,
      DetailNavigationSource.boxAnimals =>
        animal.status == AnimalStatus.active &&
            animal.boxId == navigationContext.sourceBoxId,
      DetailNavigationSource.boxes => false,
    };

    if (!remainsInSource) {
      _navigationContext = null;
    }
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

    if (_lifecycleActionInProgress) {
      return;
    }

    if (dragDistance <= -_minimumSwipeDistance) {
      _showAdjacentAnimal(next: true);
    } else if (dragDistance >= _minimumSwipeDistance) {
      _showAdjacentAnimal(next: false);
    }
  }

  void _handleHorizontalDragCancel() {
    _horizontalDragDistance = 0;
  }

  void _showAdjacentAnimal({required bool next}) {
    final navigationContext = _navigationContext;

    if (navigationContext == null) {
      return;
    }

    final targetAnimalId = next
        ? navigationContext.nextRecordId
        : navigationContext.previousRecordId;

    if (targetAnimalId == null) {
      return;
    }

    setState(() {
      _animalId = targetAnimalId;
      _navigationContext = navigationContext.selectRecord(targetAnimalId);
      _lifecycleError = null;
      _loadAnimal();
      _loadLatestFeeding();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Animal?>(
      key: ValueKey<int>(_animalId),
      future: _animalFuture,
      builder: (context, snapshot) {
        final animal = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.animalDetails),
            actions: [
              if (animal != null)
                IconButton(
                  key: const Key('feeding-history-button'),
                  onPressed: _openFeedingHistory,
                  icon: const Icon(Icons.restaurant),
                  tooltip: context.l10n.feedingHistory,
                ),
              if (animal != null && animal.status == AnimalStatus.active)
                IconButton(
                  key: const Key('edit-animal-button'),
                  onPressed: _lifecycleActionInProgress ? null : _openEditPage,
                  icon: const Icon(Icons.edit),
                  tooltip: context.l10n.editAnimal,
                ),
            ],
          ),
          body: GestureDetector(
            key: const Key('animal-detail-swipe-area'),
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
            child: _buildBody(context, snapshot),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<Animal?> snapshot) {
    if (snapshot.hasError) {
      return Center(child: Text(context.l10n.failedToLoadAnimal));
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    final animal = snapshot.data;

    if (animal == null) {
      return Center(child: Text(context.l10n.animalNotFound));
    }

    final isArchived = animal.status == AnimalStatus.archived;

    return ListView(
      key: ValueKey<String>('animal-detail-list-$_animalId'),
      padding: const EdgeInsets.all(16),
      children: [
        if (_lifecycleError != null) ...[
          Text(
            _lifecycleError!,
            key: const Key('animal-lifecycle-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
        ],

        FutureBuilder<MediaAsset?>(
          future: _pictureMediaFuture,
          builder: (context, pictureSnapshot) {
            if (animal.pictureMediaId != null &&
                pictureSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return AnimalPicture(
              key: const Key('animal-picture'),
              pictureBytes: pictureSnapshot.data?.data,
              picturePath: animal.picturePath,
            );
          },
        ),
        const SizedBox(height: 24),

        Text(
          animal.commonName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),

        Text(animal.latinName, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),

        _DetailRow(
          label: context.l10n.status,
          value: isArchived ? context.l10n.archived : context.l10n.active,
        ),

        if (!isArchived && animal.boxId != null)
          _DetailRow(
            label: context.l10n.box,
            value: context.l10n.boxLabel(animal.boxId!),
          ),

        if (animal.sex != null)
          _DetailRow(
            label: context.l10n.sex,
            value: context.l10n.animalSexLabel(animal.sex!),
          ),

        if (animal.birthDate != null)
          _DetailRow(
            label: context.l10n.birthDateLowercase,
            value: _formatDate(animal.birthDate!),
          ),

        if (animal.birthDateAccuracy != null)
          _DetailRow(
            label: context.l10n.birthDateAccuracyLowercase,
            value: context.l10n.birthAccuracyLabel(animal.birthDateAccuracy!),
          ),

        _DetailRow(
          label: context.l10n.temperature,
          value: context.l10n.temperatureRange(
            animal.tempMin.toString(),
            animal.tempMax.toString(),
          ),
        ),

        _DetailRow(
          label: context.l10n.humidity,
          value: context.l10n.humidityRange(
            animal.humidityMin.toString(),
            animal.humidityMax.toString(),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          context.l10n.latestFeeding,
          key: const Key('latest-feeding-heading'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),

        FutureBuilder<FeedingEvent?>(
          future: _latestFeedingFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                context.l10n.failedToLoadLatestFeeding,
                key: const Key('latest-feeding-error'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  key: Key('latest-feeding-loading'),
                ),
              );
            }

            final feeding = snapshot.data;

            if (feeding == null) {
              return Text(
                context.l10n.noFeedingEventsAvailable,
                key: const Key('latest-feeding-empty-state'),
              );
            }

            return Card(
              key: const Key('latest-feeding-section'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatDateTime(feeding.fedAt),
                            key: const Key('latest-feeding-date'),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),

                    if (feeding.notes != null &&
                        feeding.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),

                      Text(
                        feeding.notes!,
                        key: const Key('latest-feeding-note'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        if (animal.notes != null && animal.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),

          Text(
            context.l10n.notes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Text(animal.notes!),
        ],

        if (isArchived) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            context.l10n.archiveInformation,
            key: const Key('archive-information-heading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          if (animal.archiveReason != null)
            _DetailRow(
              label: context.l10n.reason,
              value: context.l10n.animalArchiveReasonLabel(
                animal.archiveReason!,
              ),
            ),

          if (animal.archivedAt != null)
            _DetailRow(
              label: context.l10n.archiveDateLowercase,
              value: _formatDate(animal.archivedAt!),
            ),

          if (animal.archiveNotes != null &&
              animal.archiveNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),

            Text(
              context.l10n.archiveNote,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            Text(animal.archiveNotes!, key: const Key('archive-notes')),
          ],

          const SizedBox(height: 24),

          FilledButton.icon(
            key: const Key('restore-animal-button'),
            onPressed: _lifecycleActionInProgress
                ? null
                : () => _restoreAnimal(animal),
            icon: _lifecycleActionInProgress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore),
            label: Text(context.l10n.restoreAnimal),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            key: const Key('permanent-delete-animal-button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _lifecycleActionInProgress
                ? null
                : () => _permanentlyDeleteAnimal(animal),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(context.l10n.deletePermanently),
          ),
        ] else ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            key: const Key('archive-animal-button'),
            onPressed: _lifecycleActionInProgress
                ? null
                : () => _archiveAnimal(animal),
            icon: _lifecycleActionInProgress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.archive_outlined),
            label: Text(context.l10n.archiveAnimal),
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
  State<_ArchiveAnimalDialog> createState() => _ArchiveAnimalDialogState();
}

class _ArchiveAnimalDialogState extends State<_ArchiveAnimalDialog> {
  final TextEditingController _notesController = TextEditingController();

  AnimalArchiveReason? _reason;
  late DateTime _archiveDate;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _archiveDate = DateTime(now.year, now.month, now.day);
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

    final notes = _notesController.text.trim();

    Navigator.of(context).pop(
      _ArchiveAnimalResult(
        reason: reason,
        archivedAt: _archiveDate,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('archive-animal-dialog'),
      scrollable: true,
      title: Text(context.l10n.archiveAnimal),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.archiveAnimalQuestion),
          const SizedBox(height: 20),

          DropdownButtonFormField<AnimalArchiveReason>(
            key: const Key('archive-reason-field'),
            initialValue: _reason,
            decoration: InputDecoration(labelText: context.l10n.reason),
            items: AnimalArchiveReason.values
                .map(
                  (reason) => DropdownMenuItem<AnimalArchiveReason>(
                    value: reason,
                    child: Text(context.l10n.animalArchiveReasonLabel(reason)),
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
            key: const Key('archive-date-field'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.archiveDate),
            subtitle: Text(_formatDate(_archiveDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _selectDate,
          ),
          const SizedBox(height: 16),

          TextField(
            key: const Key('archive-notes-field'),
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.note,
              hintText: context.l10n.optional,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancel-archive-animal-button'),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-archive-animal-button'),
          onPressed: _reason == null ? null : _confirm,
          child: Text(context.l10n.archive),
        ),
      ],
    );
  }
}

class _RestoreAnimalDialog extends StatefulWidget {
  final List<Box> boxes;

  const _RestoreAnimalDialog({required this.boxes});

  @override
  State<_RestoreAnimalDialog> createState() => _RestoreAnimalDialogState();
}

class _RestoreAnimalDialogState extends State<_RestoreAnimalDialog> {
  int? _boxId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('restore-animal-dialog'),
      title: Text(context.l10n.restoreAnimal),
      content: DropdownButtonFormField<int>(
        key: const Key('restore-box-field'),
        initialValue: _boxId,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.l10n.assignToBox),
        items: widget.boxes
            .map(
              (box) => DropdownMenuItem<int>(
                value: box.id,
                child: Text(
                  context.l10n.boxLabel(box.id),
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
          key: const Key('cancel-restore-animal-button'),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-restore-animal-button'),
          onPressed: _boxId == null
              ? null
              : () {
                  Navigator.of(context).pop(_boxId);
                },
          child: Text(context.l10n.restore),
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

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
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

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');

  final month = dateTime.month.toString().padLeft(2, '0');

  final year = dateTime.year.toString();

  final hour = dateTime.hour.toString().padLeft(2, '0');

  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}
