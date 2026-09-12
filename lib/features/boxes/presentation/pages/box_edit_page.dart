import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../media/presentation/picture_selection_flow.dart';
import '../../../media/presentation/widgets/picture_selection_controls.dart';
import '../widgets/box_picture.dart';

enum BoxEditResult { saved, deleted }

class BoxEditPage extends StatefulWidget {
  final AppDatabase database;
  final int boxId;
  final PictureSelectionFlow? pictureSelectionFlow;

  const BoxEditPage({
    super.key,
    required this.database,
    required this.boxId,
    this.pictureSelectionFlow,
  });

  @override
  State<BoxEditPage> createState() => _BoxEditPageState();
}

class _BoxEditPageState extends State<BoxEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _depthController = TextEditingController();
  final _notesController = TextEditingController();

  late final PictureSelectionFlow _pictureSelectionFlow;

  Box? _box;

  int? _pictureMediaId;
  int? _originalPictureMediaId;

  Uint8List? _pictureBytes;
  String? _pictureFileName;
  String? _pictureMimeType;

  bool _pictureChanged = false;

  bool _loading = true;
  bool _saving = false;
  bool _deleteFlowActive = false;
  bool _deleting = false;
  bool _processingPicture = false;
  bool _hasUnsavedChanges = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _pictureSelectionFlow =
        widget.pictureSelectionFlow ?? DefaultPictureSelectionFlow();
    _loadBox();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _depthController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _loadBox() async {
    try {
      final box = await BoxRepository(widget.database).getBoxById(widget.boxId);

      if (!mounted) {
        return;
      }

      if (box == null) {
        setState(() {
          _loading = false;
          _error = context.l10n.boxNotFound;
        });

        return;
      }

      MediaAsset? pictureMedia;

      if (box.pictureMediaId != null) {
        pictureMedia = await MediaRepository(widget.database)
            .getMediaById(box.pictureMediaId!);
      }

      if (!mounted) {
        return;
      }

      _box = box;
      _pictureMediaId = box.pictureMediaId;
      _originalPictureMediaId = box.pictureMediaId;

      _widthController.text = _formatEditableNumber(box.widthCm);

      _heightController.text = _formatEditableNumber(box.heightCm);

      _depthController.text = _formatEditableNumber(box.depthCm);

      _notesController.text = box.notes ?? '';

      if (pictureMedia != null) {
        _pictureBytes = pictureMedia.data;
        _pictureFileName = pictureMedia.fileName;
        _pictureMimeType = pictureMedia.mimeType;
      }

      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = context.l10n.failedToLoadBox;
      });
    }
  }

  void _markAsChanged() {
    if (_hasUnsavedChanges) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _selectPicture(ImageSource source) async {
    if (_processingPicture || _saving || _deleteFlowActive) {
      return;
    }

    setState(() {
      _processingPicture = true;
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

      setState(() {
        _pictureMediaId = null;

        _pictureBytes = picture.bytes;
        _pictureFileName = picture.fileName;
        _pictureMimeType = picture.mimeType;

        _pictureChanged = true;
        _hasUnsavedChanges = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = context.l10n.failedToSelectPicture;
      });
    } finally {
      if (mounted) {
        setState(() {
          _processingPicture = false;
        });
      }
    }
  }

  void _removePicture() {
    if (_processingPicture || _saving || _deleteFlowActive) {
      return;
    }

    setState(() {
      _pictureMediaId = null;

      _pictureBytes = null;
      _pictureFileName = null;
      _pictureMimeType = null;

      _pictureChanged = true;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _save() async {
    if (_saving || _deleteFlowActive || _processingPicture) {
      return;
    }

    if (!_formKey.currentState!.validate() || _box == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final widthCm = _parseOptionalNumber(_widthController.text);

      final heightCm = _parseOptionalNumber(_heightController.text);

      final depthCm = _parseOptionalNumber(_depthController.text);

      final notes = _notesController.text.trim();

      await widget.database.transaction(() async {
        final mediaRepository = MediaRepository(widget.database);

        int? pictureMediaId = _pictureMediaId;

        if (_pictureChanged && _pictureBytes != null) {
          pictureMediaId = await mediaRepository.createMedia(
            fileName: _pictureFileName ?? 'box.img',
            mimeType: _pictureMimeType ?? 'application/octet-stream',
            data: _pictureBytes!,
          );
        }

        final updated = await BoxRepository(widget.database).updateBox(
          boxId: _box!.id,
          widthCm: drift.Value(widthCm),
          heightCm: drift.Value(heightCm),
          depthCm: drift.Value(depthCm),
          notes: drift.Value(notes.isEmpty ? null : notes),
          pictureMediaId: _pictureChanged
              ? drift.Value(pictureMediaId)
              : const drift.Value.absent(),
        );

        if (!updated) {
          throw StateError('Box update failed');
        }

        final oldMediaId = _originalPictureMediaId;

        if (_pictureChanged &&
            oldMediaId != null &&
            oldMediaId != pictureMediaId) {
          await mediaRepository.deleteMedia(oldMediaId);
        }
      });

      if (!mounted) {
        return;
      }

      _hasUnsavedChanges = false;

      Navigator.of(context).pop(BoxEditResult.saved);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = context.l10n.failedToSaveBox;
      });
    }
  }

  Future<void> _deleteBox() async {
    if (_saving || _deleteFlowActive || _processingPicture || _box == null) {
      return;
    }

    setState(() {
      _deleteFlowActive = true;
      _error = null;
    });

    try {
      final animals = await AnimalRepository(widget.database)
          .getAnimalsForBox(_box!.id);

      if (!mounted) {
        return;
      }

      if (animals.isNotEmpty) {
        await _showCannotDeleteDialog(animals.length);

        if (mounted) {
          setState(() {
            _deleteFlowActive = false;
          });
        }

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
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
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
        if (mounted) {
          setState(() {
            _deleteFlowActive = false;
          });
        }

        return;
      }

      setState(() {
        _deleting = true;
      });

      final deleted = await BoxRepository(widget.database).deleteBox(_box!.id);

      if (!mounted) {
        return;
      }

      if (!deleted) {
        setState(() {
          _deleteFlowActive = false;
          _deleting = false;
          _error = context.l10n.failedToDeleteBox;
        });

        return;
      }

      _hasUnsavedChanges = false;

      Navigator.of(context).pop(BoxEditResult.deleted);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deleteFlowActive = false;
        _deleting = false;
        _error = context.l10n.failedToDeleteBox;
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

  Future<bool> _showDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.unsavedChanges),
          content: Text(context.l10n.unsavedChangesLeaveQuestion),
          actions: [
            TextButton(
              key: const Key('cancel-discard-box-button'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('confirm-discard-box-button'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(context.l10n.discard),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _handleBack() async {
    if (_saving || _deleteFlowActive) {
      return;
    }

    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await _showDiscardDialog();

    if (!mounted || !discard) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = false;
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges && !_saving && !_deleteFlowActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            key: const Key('back-button'),
            onPressed: _handleBack,
          ),
          title: Text(
            _box == null
                ? context.l10n.editBox
                : context.l10n.editBoxLabel(context.l10n.boxLabel(_box!.id)),
          ),
          actions: [
            IconButton(
              key: const Key('save-box-button'),
              onPressed: _saving || _deleteFlowActive || _processingPicture
                  ? null
                  : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              tooltip: context.l10n.save,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  bool get _hasPicture => _pictureBytes != null || _pictureMediaId != null;

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_box == null) {
      return Center(child: Text(_error ?? context.l10n.boxNotFound));
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                key: const Key('box-edit-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],

            BoxPicture(
              key: const Key('box-picture'),
              pictureBytes: _pictureBytes,
            ),
            const SizedBox(height: 8),

            PictureSelectionControls(
              enabled: !_saving && !_deleteFlowActive,
              processing: _processingPicture,
              hasPicture: _hasPicture,
              cameraSupported: _pictureSelectionFlow.supportsImageSource(
                ImageSource.camera,
              ),
              onSelect: _selectPicture,
              onRemove: _removePicture,
              actionButtonKey: const Key('select-box-picture-button'),
              removeButtonKey: const Key('remove-box-picture-button'),
            ),
            const SizedBox(height: 24),

            Text(
              context.l10n.qrIdentifier,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            SelectableText(_box!.qrId, key: const Key('box-edit-qr-id')),
            const SizedBox(height: 4),

            Text(
              context.l10n.permanentQrIdentifierHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            Text(
              context.l10n.dimensions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            _dimensionField(
              key: const Key('box-width-field'),
              controller: _widthController,
              label: context.l10n.widthCentimeters,
            ),
            const SizedBox(height: 16),

            _dimensionField(
              key: const Key('box-height-field'),
              controller: _heightController,
              label: context.l10n.heightCentimeters,
            ),
            const SizedBox(height: 16),

            _dimensionField(
              key: const Key('box-depth-field'),
              controller: _depthController,
              label: context.l10n.depthCentimeters,
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('box-notes-field'),
              controller: _notesController,
              onChanged: (_) => _markAsChanged(),
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.notes,
                helperText: context.l10n.optional,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('save-box-form-button'),
              onPressed: _saving || _deleteFlowActive || _processingPicture
                  ? null
                  : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? context.l10n.saving : context.l10n.save),
            ),
            const SizedBox(height: 32),

            const Divider(),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              key: const Key('delete-box-button'),
              onPressed: _saving || _deleteFlowActive || _processingPicture
                  ? null
                  : _deleteBox,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              icon: _deleting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(context.l10n.deleteBox),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimensionField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      onChanged: (_) => _markAsChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: context.l10n.optional,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }

        final parsed = _parseOptionalNumber(value);

        if (parsed == null) {
          return context.l10n.pleaseEnterValidNumber;
        }

        if (parsed <= 0) {
          return context.l10n.valueMustBeGreaterThanZero;
        }

        return null;
      },
    );
  }

  double? _parseOptionalNumber(String value) {
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  String _formatEditableNumber(double? value) {
    if (value == null) {
      return '';
    }

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}
