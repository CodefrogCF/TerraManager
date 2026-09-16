import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/picture_gallery_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../picture_selection_flow.dart';
import '../widgets/picture_selection_controls.dart';
import 'full_screen_image_page.dart';

enum PictureGalleryOwner { animal, box }

class PictureGalleryPage extends StatefulWidget {
  const PictureGalleryPage({
    super.key,
    required this.database,
    required this.owner,
    required this.ownerId,
    this.pictureSelectionFlow,
  });

  final AppDatabase database;
  final PictureGalleryOwner owner;
  final int ownerId;
  final PictureSelectionFlow? pictureSelectionFlow;

  @override
  State<PictureGalleryPage> createState() => _PictureGalleryPageState();
}

class _PictureGalleryPageState extends State<PictureGalleryPage> {
  late final PictureGalleryRepository _repository;
  late final PictureSelectionFlow _pictureSelectionFlow;
  late Future<List<PictureGalleryEntry>> _picturesFuture;

  bool _processing = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = PictureGalleryRepository(widget.database);
    _pictureSelectionFlow =
        widget.pictureSelectionFlow ?? DefaultPictureSelectionFlow();
    _loadPictures();
  }

  void _loadPictures() {
    _picturesFuture = switch (widget.owner) {
      PictureGalleryOwner.animal => _repository.getAnimalPictures(
        widget.ownerId,
      ),
      PictureGalleryOwner.box => _repository.getBoxPictures(widget.ownerId),
    };
  }

  Future<void> _selectPicture(ImageSource source) async {
    if (_processing) {
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final picture = await _pictureSelectionFlow.selectAndCrop(
        context: context,
        source: source,
      );
      if (picture == null || !mounted) {
        return;
      }

      switch (widget.owner) {
        case PictureGalleryOwner.animal:
          await _repository.addAnimalPicture(
            animalId: widget.ownerId,
            fileName: picture.fileName,
            mimeType: picture.mimeType,
            data: picture.bytes,
          );
        case PictureGalleryOwner.box:
          await _repository.addBoxPicture(
            boxId: widget.ownerId,
            fileName: picture.fileName,
            mimeType: picture.mimeType,
            data: picture.bytes,
          );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _changed = true;
        _loadPictures();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.l10n.failedToAddPicture;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _setPrimary(PictureGalleryEntry picture) async {
    if (_processing || picture.isPrimary) {
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final updated = switch (widget.owner) {
        PictureGalleryOwner.animal => await _repository.setAnimalPrimaryPicture(
          animalId: widget.ownerId,
          mediaId: picture.media.id,
        ),
        PictureGalleryOwner.box => await _repository.setBoxPrimaryPicture(
          boxId: widget.ownerId,
          mediaId: picture.media.id,
        ),
      };
      if (!updated) {
        throw StateError('Picture association no longer exists');
      }
      if (mounted) {
        setState(() {
          _changed = true;
          _loadPictures();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.l10n.failedToSetPrimaryPicture;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _deletePicture(PictureGalleryEntry picture) async {
    if (_processing) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deletePictureQuestion),
        content: Text(dialogContext.l10n.deletePictureWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-gallery-picture-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final deleted = switch (widget.owner) {
        PictureGalleryOwner.animal => await _repository.deleteAnimalPicture(
          animalId: widget.ownerId,
          mediaId: picture.media.id,
        ),
        PictureGalleryOwner.box => await _repository.deleteBoxPicture(
          boxId: widget.ownerId,
          mediaId: picture.media.id,
        ),
      };
      if (!deleted) {
        throw StateError('Picture association no longer exists');
      }
      if (mounted) {
        setState(() {
          _changed = true;
          _loadPictures();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.l10n.failedToDeletePicture;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  String _formatTimestamp(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return context.l10n.pictureAddedAt(date, time);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_processing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_processing) {
          Navigator.of(context).pop(_changed);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.pictureGallery),
          leading: BackButton(
            onPressed: _processing
                ? null
                : () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: FutureBuilder<List<PictureGalleryEntry>>(
          future: _picturesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(context.l10n.failedToLoadPictures));
            }

            final pictures = snapshot.data ?? const [];
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(context.l10n.pictureGalleryDescription),
                            const SizedBox(height: 16),
                            PictureSelectionControls(
                              enabled: !_processing,
                              processing: _processing,
                              hasPicture: false,
                              cameraSupported: _pictureSelectionFlow
                                  .supportsImageSource(ImageSource.camera),
                              onSelect: _selectPicture,
                              onRemove: () {},
                              actionButtonKey: const Key(
                                'add-gallery-picture-button',
                              ),
                              removeButtonKey: const Key(
                                'remove-gallery-picture-button',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                key: const Key('picture-gallery-error'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            if (pictures.isEmpty) ...[
                              const SizedBox(height: 32),
                              Text(
                                context.l10n.noPictures,
                                key: const Key('empty-picture-gallery'),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (pictures.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid.builder(
                          itemCount: pictures.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 270,
                              ),
                          itemBuilder: (context, index) => _PictureCard(
                            picture: pictures[index],
                            enabled: !_processing,
                            timestamp: _formatTimestamp(
                              context,
                              pictures[index].capturedAt,
                            ),
                            onOpen: () => FullScreenImagePage.open(
                              context,
                              imageBytes: pictures[index].media.data,
                              title: context.l10n.pictureGallery,
                            ),
                            onSetPrimary: () => _setPrimary(pictures[index]),
                            onDelete: () => _deletePicture(pictures[index]),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PictureCard extends StatelessWidget {
  const _PictureCard({
    required this.picture,
    required this.enabled,
    required this.timestamp,
    required this.onOpen,
    required this.onSetPrimary,
    required this.onDelete,
  });

  final PictureGalleryEntry picture;
  final bool enabled;
  final String timestamp;
  final VoidCallback onOpen;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey<String>('gallery-picture-${picture.media.id}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey<String>('open-gallery-picture-${picture.media.id}'),
              onTap: enabled ? onOpen : null,
              child: Image.memory(
                picture.media.data,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    timestamp,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (picture.isPrimary)
                  Tooltip(
                    message: context.l10n.primaryPicture,
                    child: const Icon(
                      Icons.star,
                      key: Key('primary-picture-indicator'),
                    ),
                  )
                else
                  IconButton(
                    key: ValueKey<String>(
                      'set-primary-picture-${picture.media.id}',
                    ),
                    onPressed: enabled ? onSetPrimary : null,
                    icon: const Icon(Icons.star_outline),
                    tooltip: context.l10n.setAsPrimaryPicture,
                  ),
                IconButton(
                  key: ValueKey<String>(
                    'delete-gallery-picture-${picture.media.id}',
                  ),
                  onPressed: enabled ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.deletePicture,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
