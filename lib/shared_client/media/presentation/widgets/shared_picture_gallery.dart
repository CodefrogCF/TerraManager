import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:terramanager/core/presentation/widgets/responsive_picture_frame.dart';
import 'package:terramanager/features/media/presentation/pages/full_screen_image_page.dart';
import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_detail_feedback.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_deletion_dialog.dart';
import 'package:terramanager/shared_client/shared/presentation/widgets/shared_load_failure.dart';

class SharedPictureGallery extends StatefulWidget {
  const SharedPictureGallery({
    super.key,
    required this.api,
    required this.kind,
    required this.recordId,
    required this.active,
    required this.change,
    required this.onChanged,
    this.pictureSelectionFlow,
  });
  final PictureSelectionFlow? pictureSelectionFlow;
  final SharedApiClient api;
  final String kind;
  final int recordId;
  final bool active;
  final SharedChange change;
  final VoidCallback onChanged;

  @override
  State<SharedPictureGallery> createState() => _SharedPictureGalleryState();
}

class _SharedPictureGalleryState extends State<SharedPictureGallery> {
  late Future<List<Map<String, dynamic>>> _pictures;
  late final PictureSelectionFlow _pictureSelectionFlow;
  bool _adding = false;
  ({SelectedPicture picture, String requestId})? _pendingUpload;

  void _openPicture(
    Map<String, dynamic> picture,
    List<Map<String, dynamic>> pictures,
  ) {
    FullScreenImagePage.openGallery(
      context,
      imageProviders: [
        for (final entry in pictures)
          NetworkImage(widget.api.mediaUrl(entry['mediaId'] as int).toString()),
      ],
      initialIndex: pictures.indexOf(picture),
      title: widget.kind == 'boxes'
          ? context.l10n.boxPicture
          : context.l10n.animalPicture,
    );
  }

  @override
  void initState() {
    super.initState();
    _pictures = widget.api.pictures(widget.kind, widget.recordId);
    _pictureSelectionFlow =
        widget.pictureSelectionFlow ?? DefaultPictureSelectionFlow();
  }

  void _reload() => setState(() {
    _pictures = widget.api.pictures(widget.kind, widget.recordId);
  });

  void _uploadFailure([String? message]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? context.l10n.failedToAddPicture)),
    );
  }

  String _uploadErrorMessage(SharedApiException error) => switch (error.code) {
    'invalid_data' || 'too_large' => sharedText(
      context,
      'The picture was rejected. Check its format and size.',
      'Das Bild wurde abgelehnt. Prüfe Format und Größe.',
    ),
    'media_storage_limit' => sharedText(
      context,
      'Shared Care picture storage is full.',
      'Der Bildspeicher von Shared Care ist voll.',
    ),
    'idempotency_conflict' => sharedText(
      context,
      'This upload cannot be retried because its picture or request data changed.',
      'Dieser Upload kann nicht wiederholt werden, weil das Bild oder die Anfragedaten geändert wurden.',
    ),
    'forbidden' || 'unauthorized' => sharedText(
      context,
      'You are not allowed to add this picture. Sign in again if needed.',
      'Du darfst dieses Bild nicht hinzufügen. Melde dich gegebenenfalls erneut an.',
    ),
    _ => sharedText(
      context,
      'The picture could not be uploaded (${error.status}).',
      'Das Bild konnte nicht hochgeladen werden (${error.status}).',
    ),
  };

  Future<void> _upload(SelectedPicture picture, String requestId) async {
    try {
      await widget.api.addPicture(
        widget.kind,
        widget.recordId,
        picture.fileName,
        picture.mimeType,
        picture.bytes,
        requestId: requestId,
      );
      if (!mounted) return;
      setState(() => _pendingUpload = null);
      _reload();
      widget.onChanged();
    } on SharedConnectionException {
      if (!mounted) return;
      setState(() => _pendingUpload = (picture: picture, requestId: requestId));
      _uploadFailure(
        sharedText(
          context,
          'Upload result unknown. Retry the same request to confirm it safely.',
          'Upload-Ergebnis unklar. Wiederhole dieselbe Anfrage, um es sicher zu prüfen.',
        ),
      );
    } on SharedApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'invalid_response') {
        setState(
          () => _pendingUpload = (picture: picture, requestId: requestId),
        );
        _uploadFailure(
          sharedText(
            context,
            'Upload result unknown. Retry the same request to confirm it safely.',
            'Upload-Ergebnis unklar. Wiederhole dieselbe Anfrage, um es sicher zu prüfen.',
          ),
        );
      } else {
        setState(() => _pendingUpload = null);
        _uploadFailure(_uploadErrorMessage(error));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingUpload = (picture: picture, requestId: requestId));
      _uploadFailure(
        sharedText(
          context,
          'Upload result unknown. Retry the same request to confirm it safely.',
          'Upload-Ergebnis unklar. Wiederhole dieselbe Anfrage, um es sicher zu prüfen.',
        ),
      );
    }
  }

  Future<void> _retryUpload() async {
    final pending = _pendingUpload;
    if (_adding || pending == null || !widget.active) return;
    setState(() => _adding = true);
    try {
      await _upload(pending.picture, pending.requestId);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _add() async {
    if (_adding ||
        _pendingUpload != null ||
        !widget.active ||
        !widget.api.connected) {
      return;
    }
    setState(() => _adding = true);
    try {
      final picture = await _pictureSelectionFlow.selectAndCrop(
        context: context,
        source: ImageSource.gallery,
      );
      if (picture == null || !mounted) return;
      if (picture.bytes.length > 8 * 1024 * 1024) {
        _uploadFailure(
          sharedText(
            context,
            'The cropped picture exceeds the 8 MiB upload limit.',
            'Das zugeschnittene Bild überschreitet die Upload-Grenze von 8 MiB.',
          ),
        );
        return;
      }
      await _upload(picture, const Uuid().v4());
    } catch (_) {
      if (mounted) _uploadFailure();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _pictureAction(
    Map<String, dynamic> picture,
    String action,
  ) async {
    if (_adding) return;
    final mediaId = picture['mediaId'] as int;
    if (action == 'delete' && !await confirmPermanentDeletion(context)) {
      return;
    }
    final saved = await widget.change(() async {
      if (action == 'primary') {
        await widget.api.setPrimaryPicture(
          widget.kind,
          widget.recordId,
          mediaId,
        );
      } else {
        await widget.api.removePicture(widget.kind, widget.recordId, mediaId);
      }
    });
    if (!mounted) return;
    if (saved) {
      _reload();
      widget.onChanged();
    } else {
      showSharedDetailFailure(context);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_pendingUpload != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sharedText(
                    context,
                    'The upload may have finished despite the lost response. Retry the same request to confirm it without adding a duplicate.',
                    'Der Upload kann trotz verlorener Antwort abgeschlossen sein. Wiederhole dieselbe Anfrage, um das ohne doppeltes Bild zu prüfen.',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('shared-retry-picture-upload'),
                  onPressed: widget.active && !_adding ? _retryUpload : null,
                  icon: _adding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    sharedText(context, 'Retry upload', 'Upload wiederholen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _pictures,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return SizedBox(
              height: 48,
              child: snapshot.hasError
                  ? SharedLoadFailure(onRetry: _reload)
                  : const Center(child: CircularProgressIndicator()),
            );
          }
          final pictures = snapshot.data!;
          final primary =
              pictures
                  .where((picture) => picture['isPrimary'] == true)
                  .firstOrNull ??
              pictures.firstOrNull;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: primary != null,
                    label: primary == null
                        ? null
                        : widget.kind == 'boxes'
                        ? context.l10n.openBoxPicture
                        : context.l10n.openAnimalPicture,
                    child: MouseRegion(
                      cursor: primary == null
                          ? MouseCursor.defer
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        key: const Key('shared-open-primary-picture'),
                        onTap: primary == null
                            ? null
                            : () => _openPicture(primary, pictures),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ResponsivePictureFrame(
                            child: primary == null
                                ? ColoredBox(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Center(
                                      child: Icon(
                                        widget.kind == 'boxes'
                                            ? Icons.inventory_2_outlined
                                            : Icons.emoji_nature_outlined,
                                        size: 72,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    widget.api
                                        .mediaUrl(primary['mediaId'] as int)
                                        .toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 72,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(context.l10n.pictureGallery),
                    children: [
                      if (pictures.isNotEmpty)
                        SizedBox(
                          height: 150,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final picture in pictures)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      Semantics(
                                        button: true,
                                        label: widget.kind == 'boxes'
                                            ? context.l10n.openBoxPicture
                                            : context.l10n.openAnimalPicture,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            key: Key(
                                              'shared-open-gallery-picture-${picture['mediaId']}',
                                            ),
                                            onTap: () =>
                                                _openPicture(picture, pictures),
                                            child: Image.network(
                                              widget.api
                                                  .mediaUrl(
                                                    picture['mediaId'] as int,
                                                  )
                                                  .toString(),
                                              height: 150,
                                              width: 150,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const SizedBox(
                                                    height: 150,
                                                    width: 150,
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (picture['isPrimary'] == true)
                                        const Positioned(
                                          top: 4,
                                          left: 4,
                                          child: Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      if (widget.active &&
                                          (widget.api.canDeleteCollection ||
                                              picture['isPrimary'] != true))
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: PopupMenuButton<String>(
                                            enabled:
                                                widget.api.connected &&
                                                !_adding,
                                            onSelected: (action) =>
                                                _pictureAction(picture, action),
                                            itemBuilder: (context) => [
                                              if (picture['isPrimary'] != true)
                                                PopupMenuItem(
                                                  value: 'primary',
                                                  child: Text(
                                                    sharedText(
                                                      context,
                                                      'Set as primary',
                                                      'Als Hauptbild setzen',
                                                    ),
                                                  ),
                                                ),
                                              if (widget
                                                  .api
                                                  .canDeleteCollection)
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text(
                                                    sharedText(
                                                      context,
                                                      'Delete picture',
                                                      'Bild löschen',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (pictures.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(context.l10n.noPictures),
                        ),
                    ],
                  ),
                  if (widget.active)
                    TextButton.icon(
                      key: const Key('shared-add-gallery-picture'),
                      onPressed:
                          widget.api.connected &&
                              !_adding &&
                              _pendingUpload == null
                          ? _add
                          : null,
                      icon: _adding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        sharedText(context, 'Add picture', 'Bild hinzufügen'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}
