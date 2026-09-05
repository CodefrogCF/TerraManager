import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/image_media_info.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../widgets/box_picture.dart';

class NewBoxPage extends StatefulWidget {
  final AppDatabase database;

  const NewBoxPage({super.key, required this.database});

  @override
  State<NewBoxPage> createState() => _NewBoxPageState();
}

class _NewBoxPageState extends State<NewBoxPage> {
  final _formKey = GlobalKey<FormState>();

  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _depthController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _pictureBytes;
  String? _pictureFileName;
  String? _pictureMimeType;

  bool _saving = false;

  String? _error;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _depthController.dispose();

    super.dispose();
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
        _pictureBytes = bytes;
        _pictureFileName = info.fileName;
        _pictureMimeType = info.mimeType;
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
      _pictureBytes = null;
      _pictureFileName = null;
      _pictureMimeType = null;
    });
  }

  Future<void> _createBox() async {
    if (!_formKey.currentState!.validate()) {
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
        int? pictureMediaId;

        if (_pictureBytes != null) {
          pictureMediaId = await MediaRepository(widget.database).createMedia(
            fileName: _pictureFileName ?? 'box.img',
            mimeType: _pictureMimeType ?? 'application/octet-stream',
            data: _pictureBytes!,
          );
        }

        await BoxRepository(widget.database).createBoxWithGeneratedQrId(
          widthCm: widthCm,
          heightCm: heightCm,
          depthCm: depthCm,
          pictureMediaId: pictureMediaId,
        );
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = context.l10n.failedToCreateBox;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.newBox)),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    context.l10n.createNewBox,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    context.l10n.automaticQrIdentifierHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    context.l10n.qrIdentifierFormat,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),

                  BoxPicture(
                    key: const Key('new-box-picture'),
                    pictureBytes: _pictureBytes,
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('select-new-box-picture-button'),
                          onPressed: _saving ? null : _selectPicture,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _pictureBytes == null
                                ? context.l10n.selectPicture
                                : context.l10n.changePicture,
                          ),
                        ),
                      ),
                      if (_pictureBytes != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('remove-new-box-picture-button'),
                          onPressed: _saving ? null : _removePicture,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: context.l10n.removePicture,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    context.l10n.dimensions,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  _dimensionField(
                    key: const Key('new-box-width-field'),
                    controller: _widthController,
                    label: context.l10n.widthCentimeters,
                  ),
                  const SizedBox(height: 16),

                  _dimensionField(
                    key: const Key('new-box-height-field'),
                    controller: _heightController,
                    label: context.l10n.heightCentimeters,
                  ),
                  const SizedBox(height: 16),

                  _dimensionField(
                    key: const Key('new-box-depth-field'),
                    controller: _depthController,
                    label: context.l10n.depthCentimeters,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _error!,
                      key: const Key('new-box-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  FilledButton.icon(
                    key: const Key('create-box-button'),
                    onPressed: _saving ? null : _createBox,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(
                      _saving ? context.l10n.creating : context.l10n.createBox,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
}
