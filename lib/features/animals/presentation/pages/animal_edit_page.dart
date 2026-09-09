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
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../feedings/presentation/widgets/feeding_reminder_form_fields.dart';
import '../../../media/presentation/picture_selection_flow.dart';
import '../../../media/presentation/widgets/picture_selection_controls.dart';
import '../widgets/animal_picture.dart';

class AnimalEditPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;
  final PictureSelectionFlow? pictureSelectionFlow;
  final DateTime Function()? now;

  const AnimalEditPage({
    super.key,
    required this.database,
    required this.animalId,
    this.pictureSelectionFlow,
    this.now,
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
  final _feedingReminderIntervalDaysController = TextEditingController();

  late final PictureSelectionFlow _pictureSelectionFlow;

  Sex _sex = Sex.unknown;
  BirthDateAccuracy? _birthDateAccuracy;
  DateTime? _birthDate;
  int? _boxId;
  bool _feedingReminderEnabled = false;
  DateTime? _feedingReminderBaseline;

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
  bool _processingPicture = false;
  bool _hasUnsavedChanges = false;

  String? _error;
  Animal? _animal;

  @override
  void initState() {
    super.initState();
    _pictureSelectionFlow =
        widget.pictureSelectionFlow ?? DefaultPictureSelectionFlow();
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
    _feedingReminderIntervalDaysController.dispose();
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

      _sex = animal.sex ?? Sex.unknown;
      _birthDate = animal.birthDate;
      _birthDateAccuracy = animal.birthDateAccuracy;
      _boxId = animal.boxId;

      final reminderIntervalDays = animal.feedingReminderIntervalDays;
      final reminderBaseline = animal.feedingReminderBaseline;

      _feedingReminderEnabled =
          reminderIntervalDays != null && reminderBaseline != null;
      _feedingReminderIntervalDaysController.text =
          reminderIntervalDays?.toString() ?? '';
      _feedingReminderBaseline = reminderBaseline;

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

  Future<void> _selectPicture(ImageSource source) async {
    if (_processingPicture || _saving) {
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
        _legacyPicturePath = null;

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
    if (_processingPicture || _saving) {
      return;
    }

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
    if (_saving || _processingPicture) {
      return;
    }

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
          feedingReminderIntervalDays: _feedingReminderEnabled
              ? int.parse(_feedingReminderIntervalDaysController.text.trim())
              : null,
          feedingReminderBaseline: _feedingReminderEnabled
              ? _feedingReminderBaseline
              : null,
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
              key: const Key('save-animal-button'),
              onPressed: _saving || _processingPicture ? null : _save,
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

            PictureSelectionControls(
              enabled: !_saving,
              processing: _processingPicture,
              hasPicture: _hasPicture,
              cameraSupported: _pictureSelectionFlow.supportsImageSource(
                ImageSource.camera,
              ),
              onSelect: _selectPicture,
              onRemove: _removePicture,
              actionButtonKey: const Key('select-picture-button'),
              removeButtonKey: const Key('remove-picture-button'),
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

            DropdownButtonFormField<Sex>(
              key: const Key('sex-field'),
              initialValue: _sex,
              decoration: InputDecoration(labelText: context.l10n.sex),
              items: Sex.values
                  .map(
                    (sex) => DropdownMenuItem<Sex>(
                      value: sex,
                      child: Text(context.l10n.animalSexLabel(sex)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

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

            FeedingReminderFormFields(
              reminderEnabled: _feedingReminderEnabled,
              controlsEnabled: !_saving && !_processingPicture,
              intervalDaysController: _feedingReminderIntervalDaysController,
              onReminderEnabledChanged: _setFeedingReminderEnabled,
              onIntervalChanged: (_) => _markAsChanged(),
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
              key: const Key('save-animal-form-button'),
              onPressed: _saving || _processingPicture ? null : _save,
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

  void _setFeedingReminderEnabled(bool enabled) {
    setState(() {
      _feedingReminderEnabled = enabled;
      _feedingReminderBaseline = enabled
          ? (widget.now ?? DateTime.now)()
          : null;
      _hasUnsavedChanges = true;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
