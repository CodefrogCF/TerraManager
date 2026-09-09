import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/birth_date_accuracy.dart';
import '../../../../core/database/enums/sex.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../feedings/presentation/widgets/feeding_reminder_form_fields.dart';
import '../../../media/presentation/picture_selection_flow.dart';
import '../../../media/presentation/widgets/picture_selection_controls.dart';
import '../widgets/animal_picture.dart';

class NewAnimalPage extends StatefulWidget {
  final AppDatabase database;
  final int? initialBoxId;
  final PictureSelectionFlow? pictureSelectionFlow;
  final DateTime Function()? now;

  const NewAnimalPage({
    super.key,
    required this.database,
    this.initialBoxId,
    this.pictureSelectionFlow,
    this.now,
  });

  @override
  State<NewAnimalPage> createState() => _NewAnimalPageState();
}

class _NewAnimalPageState extends State<NewAnimalPage> {
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

  List<Box> _boxes = [];

  int? _boxId;
  Sex _sex = Sex.unknown;
  DateTime? _birthDate;
  BirthDateAccuracy? _birthDateAccuracy;
  bool _feedingReminderEnabled = false;
  DateTime? _feedingReminderBaseline;

  Uint8List? _pictureBytes;
  String? _pictureFileName;
  String? _pictureMimeType;

  bool _loading = true;
  bool _saving = false;
  bool _processingPicture = false;

  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _pictureSelectionFlow =
        widget.pictureSelectionFlow ?? DefaultPictureSelectionFlow();
    _loadBoxes();
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

  Future<void> _loadBoxes() async {
    try {
      final boxes = await BoxRepository(widget.database).getAllBoxes();

      if (!mounted) {
        return;
      }

      setState(() {
        _boxes = boxes;
        if (boxes.any((box) => box.id == widget.initialBoxId)) {
          _boxId = widget.initialBoxId;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadError = context.l10n.failedToLoadBoxes;
      });
    }
  }

  Future<void> _selectPicture(ImageSource source) async {
    if (_processingPicture || _saving) {
      return;
    }

    setState(() {
      _processingPicture = true;
      _saveError = null;
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
        _pictureBytes = picture.bytes;
        _pictureFileName = picture.fileName;
        _pictureMimeType = picture.mimeType;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saveError = context.l10n.failedToSelectPicture;
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
      _pictureBytes = null;
      _pictureFileName = null;
      _pictureMimeType = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _processingPicture) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_boxId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await widget.database.transaction(() async {
        int? pictureMediaId;

        if (_pictureBytes != null) {
          pictureMediaId = await MediaRepository(widget.database).createMedia(
            fileName: _pictureFileName ?? 'animal.img',
            mimeType: _pictureMimeType ?? 'application/octet-stream',
            data: _pictureBytes!,
          );
        }

        await AnimalRepository(widget.database).createAnimal(
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
          picturePath: null,
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
        _saveError = context.l10n.failedToCreateAnimal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.newAnimal),
        actions: [
          IconButton(
            key: const Key('save-animal-button'),
            onPressed:
                _saving || _processingPicture || _loading || _boxes.isEmpty
                ? null
                : _save,
            icon: const Icon(Icons.save),
            tooltip: context.l10n.saveAnimal,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }

    if (_boxes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.noBoxesForAnimal,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saveError != null) ...[
              Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],

            AnimalPicture(pictureBytes: _pictureBytes),
            const SizedBox(height: 8),

            PictureSelectionControls(
              enabled: !_saving,
              processing: _processingPicture,
              hasPicture: _pictureBytes != null,
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
              enabled: !_saving,
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
              enabled: !_saving,
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
                key: const Key('birth-date-button'),
                onPressed: _saving ? null : _selectBirthDate,
                icon: const Icon(Icons.calendar_today),
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
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('notes-field'),
              controller: _notesController,
              enabled: !_saving,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.notes,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('create-animal-button'),
              onPressed: _saving || _processingPicture ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(
                _saving ? context.l10n.creating : context.l10n.createAnimal,
              ),
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
      enabled: !_saving,
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
      });
    }
  }

  void _setFeedingReminderEnabled(bool enabled) {
    setState(() {
      _feedingReminderEnabled = enabled;
      _feedingReminderBaseline = enabled
          ? (widget.now ?? DateTime.now)()
          : null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
