import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/box_status.dart';
import '../../../../core/database/repositories/box_lifecycle_exception.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../media/presentation/picture_selection_flow.dart';
import '../../../media/presentation/widgets/picture_selection_controls.dart';
import '../widgets/box_picture.dart';
import '../box_lifecycle_dialogs.dart';

enum BoxEditResult { saved, archived }

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

  final _nameController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _depthController = TextEditingController();
  final _temperatureZonesController = TextEditingController();
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
  bool _managementFlowActive = false;
  bool _archiving = false;
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
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _depthController.dispose();
    _temperatureZonesController.dispose();
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

      if (box.status == BoxStatus.archived) {
        setState(() {
          _loading = false;
          _error = context.l10n.archivedBoxesCannotBeEdited;
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

      _nameController.text = box.name ?? '';

      _widthController.text = _formatEditableNumber(box.widthCm);

      _heightController.text = _formatEditableNumber(box.heightCm);

      _depthController.text = _formatEditableNumber(box.depthCm);

      _temperatureZonesController.text = box.temperatureZones ?? '';

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
    if (_processingPicture || _saving || _managementFlowActive) {
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
    if (_processingPicture || _saving || _managementFlowActive) {
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
    if (_saving ||
        _managementFlowActive ||
        _processingPicture ||
        _box == null) {
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
      final name = _nameController.text.trim();

      final widthCm = _parseOptionalNumber(_widthController.text);

      final heightCm = _parseOptionalNumber(_heightController.text);

      final depthCm = _parseOptionalNumber(_depthController.text);

      final temperatureZones = _temperatureZonesController.text.trim();

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
          name: drift.Value(name.isEmpty ? null : name),
          widthCm: drift.Value(widthCm),
          heightCm: drift.Value(heightCm),
          depthCm: drift.Value(depthCm),
          temperatureZones: drift.Value(
            temperatureZones.isEmpty ? null : temperatureZones,
          ),
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

  Future<void> _archiveBox() async {
    if (_saving ||
        _managementFlowActive ||
        _processingPicture ||
        _box == null) {
      return;
    }
    setState(() {
      _managementFlowActive = true;
      _error = null;
    });
    try {
      final animals = await AnimalRepository(widget.database)
          .getAnimalsForBox(_box!.id);
      if (!mounted) {
        return;
      }
      if (animals.isNotEmpty) {
        await _showCannotArchiveDialog(animals);
        return;
      }
      final input = await showDialog<ArchiveBoxInput>(
        context: context,
        builder: (_) => ArchiveBoxDialog(hasUnsavedChanges: _hasUnsavedChanges),
      );
      if (!mounted || input == null) {
        return;
      }
      setState(() => _archiving = true);
      final success = await BoxRepository(widget.database).archiveBox(
        boxId: _box!.id,
        reason: input.reason,
        archivedAt: DateTime.now(),
        archiveNotes: input.notes,
      );
      if (!mounted) {
        return;
      }
      if (!success) {
        setState(() => _error = context.l10n.failedToArchiveBox);
        return;
      }
      _hasUnsavedChanges = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.boxArchived)));
      Navigator.of(context).pop(BoxEditResult.archived);
    } on BoxArchiveBlockedException catch (error) {
      if (mounted) {
        setState(() => _archiving = false);
        await _showCannotArchiveDialog(error.animals);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.failedToArchiveBox);
      }
    } finally {
      if (mounted) {
        setState(() {
          _managementFlowActive = false;
          _archiving = false;
        });
      }
    }
  }

  Future<void> _showCannotArchiveDialog(List<Animal> animals) {
    return showDialog<void>(
      context: context,
      builder: (context) => CannotArchiveBoxDialog(animals: animals),
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
    if (_saving || _managementFlowActive) {
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
      canPop: !_hasUnsavedChanges && !_saving && !_managementFlowActive,
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
              onPressed:
                  _box == null ||
                      _saving ||
                      _managementFlowActive ||
                      _processingPicture
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
              enabled: !_saving && !_managementFlowActive,
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

            TextFormField(
              key: const Key('box-name-field'),
              controller: _nameController,
              onChanged: (_) => _markAsChanged(),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.boxName,
                helperText: context.l10n.optional,
              ),
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
              key: const Key('box-temperature-zones-field'),
              controller: _temperatureZonesController,
              onChanged: (_) => _markAsChanged(),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.temperatureZones,
                helperText: context.l10n.optional,
                alignLabelWithHint: true,
              ),
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
              onPressed:
                  _box == null ||
                      _saving ||
                      _managementFlowActive ||
                      _processingPicture
                  ? null
                  : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? context.l10n.saving : context.l10n.save),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              key: const Key('archive-box-button'),
              onPressed: _saving || _managementFlowActive || _processingPicture
                  ? null
                  : _archiveBox,
              icon: _archiving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.archive_outlined),
              label: Text(context.l10n.archiveBox),
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
