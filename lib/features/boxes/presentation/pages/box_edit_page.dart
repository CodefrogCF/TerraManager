import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/image_media_info.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../widgets/box_picture.dart';

class BoxEditPage extends StatefulWidget {
  final AppDatabase database;
  final int boxId;

  const BoxEditPage({super.key, required this.database, required this.boxId});

  @override
  State<BoxEditPage> createState() => _BoxEditPageState();
}

class _BoxEditPageState extends State<BoxEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _depthController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  Box? _box;

  int? _pictureMediaId;

  Uint8List? _pictureBytes;
  String? _pictureFileName;
  String? _pictureMimeType;

  bool _pictureChanged = false;

  bool _loading = true;
  bool _saving = false;
  bool _hasUnsavedChanges = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBox();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _depthController.dispose();

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

      _widthController.text = _formatEditableNumber(box.widthCm);

      _heightController.text = _formatEditableNumber(box.heightCm);

      _depthController.text = _formatEditableNumber(box.depthCm);

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

  Future<void> _selectPicture() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      final info = ImageMediaInfo.fromXFile(image);

      if (!mounted) {
        return;
      }

      setState(() {
        _pictureMediaId = null;

        _pictureBytes = bytes;
        _pictureFileName = info.fileName;
        _pictureMimeType = info.mimeType;

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
    }
  }

  void _removePicture() {
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
          pictureMediaId: _pictureChanged
              ? drift.Value(pictureMediaId)
              : const drift.Value.absent(),
        );

        if (!updated) {
          throw StateError('Box update failed');
        }
      });

      if (!mounted) {
        return;
      }

      _hasUnsavedChanges = false;

      Navigator.of(context).pop(true);
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
    if (_saving) {
      return;
    }

    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    final discard = await _showDiscardDialog();

    if (!mounted || !discard) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = false;
    });

    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges && !_saving,
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
              onPressed: _saving ? null : _save,
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

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('select-box-picture-button'),
                    onPressed: _saving ? null : _selectPicture,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _hasPicture
                          ? context.l10n.changePicture
                          : context.l10n.selectPicture,
                    ),
                  ),
                ),
                if (_hasPicture) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('remove-box-picture-button'),
                    onPressed: _saving ? null : _removePicture,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.l10n.removePicture,
                  ),
                ],
              ],
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
            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('save-box-form-button'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? context.l10n.saving : context.l10n.save),
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
