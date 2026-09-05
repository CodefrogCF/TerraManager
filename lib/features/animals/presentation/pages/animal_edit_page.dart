import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/birth_date_accuracy.dart';
import '../../../../core/database/enums/sex.dart';
import '../../../../core/database/enums/animal_status.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/image_media_info.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../widgets/animal_picture.dart';

class AnimalEditPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;

  const AnimalEditPage({
    super.key,
    required this.database,
    required this.animalId,
  });

  @override
  State<AnimalEditPage> createState() => _AnimalEditPageState();
}

class _AnimalEditPageState extends State<AnimalEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _commonNameController = TextEditingController();
  final _latinNameController = TextEditingController();
  final _tempMinController = TextEditingController();
  final _tempMaxController = TextEditingController();
  final _humidityMinController = TextEditingController();
  final _humidityMaxController = TextEditingController();
  final _notesController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  Sex? _sex;
  BirthDateAccuracy? _birthDateAccuracy;
  DateTime? _birthDate;
  int? _boxId;

  int? _pictureMediaId;
  int? _originalPictureMediaId;

  String? _legacyPicturePath;

  Uint8List? _pictureBytes;
  String? _pictureFileName;
  String? _pictureMimeType;

  bool _pictureChanged = false;

  List<Box> _boxes = [];

  bool _loading = true;
  bool _saving = false;
  bool _hasUnsavedChanges = false;

  String? _error;
  Animal? _animal;

  @override
  void initState() {
    super.initState();
    _loadAnimal();
  }

  @override
  void dispose() {
    _commonNameController.dispose();
    _latinNameController.dispose();
    _tempMinController.dispose();
    _tempMaxController.dispose();
    _humidityMinController.dispose();
    _humidityMaxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimal() async {
    try {
      final animalRepository = AnimalRepository(widget.database);
      final boxRepository = BoxRepository(widget.database);

      final animal = await animalRepository.getAnimalById(widget.animalId);

      if (!mounted) {
        return;
      }

      if (animal == null) {
        setState(() {
          _loading = false;
          _error = context.l10n.animalNotFound;
        });
        return;
      }

      if (animal.status != AnimalStatus.active) {
        setState(() {
          _loading = false;
          _error = context.l10n.archivedAnimalsCannotBeEdited;
        });
        return;
      }

      final boxes = await boxRepository.getAllBoxes();

      MediaAsset? pictureMedia;

      if (animal.pictureMediaId != null) {
        pictureMedia = await MediaRepository(widget.database)
            .getMediaById(animal.pictureMediaId!);
      }

      if (!mounted) {
        return;
      }

      _animal = animal;
      _boxes = boxes;

      _commonNameController.text = animal.commonName;
      _latinNameController.text = animal.latinName;
      _tempMinController.text = animal.tempMin.toString();
      _tempMaxController.text = animal.tempMax.toString();
      _humidityMinController.text = animal.humidityMin.toString();
      _humidityMaxController.text = animal.humidityMax.toString();
      _notesController.text = animal.notes ?? '';

      _sex = animal.sex;
      _birthDate = animal.birthDate;
      _birthDateAccuracy = animal.birthDateAccuracy;
      _boxId = animal.boxId;

      _pictureMediaId = animal.pictureMediaId;

      _originalPictureMediaId = animal.pictureMediaId;

      _legacyPicturePath = animal.picturePath;

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
        _error = context.l10n.failedToLoadAnimal;
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
        _legacyPicturePath = null;

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
      _legacyPicturePath = null;

      _pictureBytes = null;
      _pictureFileName = null;
      _pictureMimeType = null;

      _pictureChanged = true;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _animal == null) {
      return;
    }

    if (_boxId == null) {
      setState(() {
        _error = context.l10n.pleaseSelectBox;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final success = await widget.database.transaction(() async {
        final mediaRepository = MediaRepository(widget.database);

        int? pictureMediaId = _pictureMediaId;

        String? legacyPicturePath = _legacyPicturePath;

        if (_pictureChanged) {
          legacyPicturePath = null;

          if (_pictureBytes != null) {
            pictureMediaId = await mediaRepository.createMedia(
              fileName: _pictureFileName ?? 'animal.img',
              mimeType: _pictureMimeType ?? 'application/octet-stream',
              data: _pictureBytes!,
            );
          } else {
            pictureMediaId = null;
          }
        }

        final updated = await AnimalRepository(widget.database).updateAnimal(
          animalId: _animal!.id,
          boxId: _boxId!,
          commonName: _commonNameController.text.trim(),
          latinName: _latinNameController.text.trim(),
          sex: _sex,
          birthDate: _birthDate,
          birthDateAccuracy: _birthDateAccuracy,
          tempMin: double.parse(_tempMinController.text),
          tempMax: double.parse(_tempMaxController.text),
          humidityMin: double.parse(_humidityMinController.text),
          humidityMax: double.parse(_humidityMaxController.text),
          pictureMediaId: pictureMediaId,
          picturePath: legacyPicturePath,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        if (!updated) {
          throw StateError('Animal update failed');
        }

        final oldMediaId = _originalPictureMediaId;

        if (_pictureChanged &&
            oldMediaId != null &&
            oldMediaId != pictureMediaId) {
          await mediaRepository.deleteMedia(oldMediaId);
        }

        return true;
      });

      if (!mounted) {
        return;
      }

      if (success) {
        _hasUnsavedChanges = false;

        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = context.l10n.failedToSaveAnimal;
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
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
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
          title: Text(context.l10n.editAnimal),
          actions: [
            IconButton(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              tooltip: context.l10n.save,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  bool get _hasPicture =>
      _pictureBytes != null ||
      _legacyPicturePath != null ||
      _pictureMediaId != null;

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _animal == null) {
      return Center(child: Text(_error!));
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],

            AnimalPicture(
              pictureBytes: _pictureBytes,
              picturePath: _legacyPicturePath,
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('select-picture-button'),
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
                    key: const Key('remove-picture-button'),
                    onPressed: _saving ? null : _removePicture,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.l10n.removePicture,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<int>(
              key: const Key('box-field'),
              initialValue: _boxId,
              decoration: InputDecoration(
                labelText: context.l10n.associatedBox,
              ),
              items: _boxes
                  .map(
                    (box) => DropdownMenuItem<int>(
                      value: box.id,
                      child: Text(context.l10n.boxLabel(box.id)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _boxId = value;
                        _hasUnsavedChanges = true;
                      });
                    },
              validator: (value) {
                if (value == null) {
                  return context.l10n.pleaseSelectBox;
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('common-name-field'),
              controller: _commonNameController,
              onChanged: (_) => _markAsChanged(),
              decoration: InputDecoration(labelText: context.l10n.commonName),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.pleaseEnterCommonName;
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('latin-name-field'),
              controller: _latinNameController,
              onChanged: (_) => _markAsChanged(),
              decoration: InputDecoration(labelText: context.l10n.latinName),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.pleaseEnterLatinName;
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<Sex?>(
              key: const Key('sex-field'),
              initialValue: _sex,
              decoration: InputDecoration(labelText: context.l10n.sex),
              items: [
                DropdownMenuItem<Sex?>(
                  value: null,
                  child: Text(context.l10n.unknown),
                ),
                ...Sex.values.map(
                  (sex) => DropdownMenuItem<Sex?>(
                    value: sex,
                    child: Text(context.l10n.animalSexLabel(sex)),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _sex = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),
            const SizedBox(height: 16),

            ListTile(
              key: const Key('birth-date-field'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.birthDate),
              subtitle: Text(
                _birthDate == null
                    ? context.l10n.notSpecified
                    : _formatDate(_birthDate!),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _saving ? null : _selectBirthDate,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<BirthDateAccuracy?>(
              key: const Key('birth-date-accuracy-field'),
              initialValue: _birthDateAccuracy,
              decoration: InputDecoration(
                labelText: context.l10n.birthDateAccuracy,
              ),
              items: [
                DropdownMenuItem<BirthDateAccuracy?>(
                  value: null,
                  child: Text(context.l10n.unknown),
                ),
                ...BirthDateAccuracy.values.map(
                  (accuracy) => DropdownMenuItem<BirthDateAccuracy?>(
                    value: accuracy,
                    child: Text(context.l10n.birthAccuracyLabel(accuracy)),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _birthDateAccuracy = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),
            const SizedBox(height: 16),

            _numberField(
              key: const Key('temp-min-field'),
              controller: _tempMinController,
              label: context.l10n.minimumTemperatureCelsius,
            ),
            const SizedBox(height: 16),

            _numberField(
              key: const Key('temp-max-field'),
              controller: _tempMaxController,
              label: context.l10n.maximumTemperatureCelsius,
            ),
            const SizedBox(height: 16),

            _numberField(
              key: const Key('humidity-min-field'),
              controller: _humidityMinController,
              label: context.l10n.minimumHumidityPercent,
            ),
            const SizedBox(height: 16),

            _numberField(
              key: const Key('humidity-max-field'),
              controller: _humidityMaxController,
              label: context.l10n.maximumHumidityPercent,
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('notes-field'),
              controller: _notesController,
              onChanged: (_) => _markAsChanged(),
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.notes,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      onChanged: (_) => _markAsChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.l10n.pleaseEnterValue;
        }

        if (double.tryParse(value) == null) {
          return context.l10n.pleaseEnterValidNumber;
        }

        return null;
      },
    );
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selected != null && mounted) {
      setState(() {
        _birthDate = selected;
        _hasUnsavedChanges = true;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
