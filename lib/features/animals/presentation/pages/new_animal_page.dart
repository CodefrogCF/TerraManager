import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/birth_date_accuracy.dart';
import '../../../../core/database/enums/sex.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/image_media_info.dart';
import '../widgets/animal_picture.dart';

class NewAnimalPage extends StatefulWidget {
  final AppDatabase database;

  const NewAnimalPage({super.key, required this.database});

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

  final ImagePicker _imagePicker = ImagePicker();

  List<Box> _boxes = [];

  int? _boxId;
  Sex? _sex;
  DateTime? _birthDate;
  BirthDateAccuracy? _birthDateAccuracy;

  Uint8List? _pictureBytes;
  String? _pictureFileName;
  String? _pictureMimeType;

  bool _loading = true;
  bool _saving = false;

  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
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
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadError = 'Failed to load boxes';
      });
    }
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
        _saveError = 'Failed to select picture';
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

  Future<void> _save() async {
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
        _saveError = 'Failed to create animal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Animal'),
        actions: [
          IconButton(
            key: const Key('save-animal-button'),
            onPressed: _saving || _loading || _boxes.isEmpty ? null : _save,
            icon: const Icon(Icons.save),
            tooltip: 'Save Animal',
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No boxes available. Create a box before adding an animal.',
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

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('select-picture-button'),
                    onPressed: _saving ? null : _selectPicture,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _pictureBytes == null
                          ? 'Select Picture'
                          : 'Change Picture',
                    ),
                  ),
                ),
                if (_pictureBytes != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('remove-picture-button'),
                    onPressed: _saving ? null : _removePicture,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove Picture',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<int>(
              key: const Key('box-field'),
              initialValue: _boxId,
              decoration: const InputDecoration(labelText: 'Associated Box'),
              items: _boxes
                  .map(
                    (box) => DropdownMenuItem<int>(
                      value: box.id,
                      child: Text(box.qrId),
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
                  return 'Please select a box';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('common-name-field'),
              controller: _commonNameController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Common Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a common name';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('latin-name-field'),
              controller: _latinNameController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Latin Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a latin name';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<Sex?>(
              key: const Key('sex-field'),
              initialValue: _sex,
              decoration: const InputDecoration(labelText: 'Sex'),
              items: [
                const DropdownMenuItem<Sex?>(
                  value: null,
                  child: Text('Unknown'),
                ),
                ...Sex.values.map(
                  (sex) => DropdownMenuItem<Sex?>(
                    value: sex,
                    child: Text(sex.toString()),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _sex = value;
                      });
                    },
            ),
            const SizedBox(height: 16),

            ListTile(
              key: const Key('birth-date-field'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Birth Date'),
              subtitle: Text(
                _birthDate == null ? 'Not specified' : _formatDate(_birthDate!),
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
              decoration: const InputDecoration(
                labelText: 'Birth Date Accuracy',
              ),
              items: [
                const DropdownMenuItem<BirthDateAccuracy?>(
                  value: null,
                  child: Text('Unknown'),
                ),
                ...BirthDateAccuracy.values.map(
                  (accuracy) => DropdownMenuItem<BirthDateAccuracy?>(
                    value: accuracy,
                    child: Text(accuracy.toString()),
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
              label: 'Minimum Temperature (°C)',
            ),
            const SizedBox(height: 16),

            _numberField(
              key: const Key('temp-max-field'),
              controller: _tempMaxController,
              label: 'Maximum Temperature (°C)',
            ),
            const SizedBox(height: 16),

            _numberField(
              key: const Key('humidity-min-field'),
              controller: _humidityMinController,
              label: 'Minimum Humidity (%)',
            ),
            const SizedBox(height: 16),

            _numberField(
              key: const Key('humidity-max-field'),
              controller: _humidityMaxController,
              label: 'Maximum Humidity (%)',
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('notes-field'),
              controller: _notesController,
              enabled: !_saving,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('create-animal-button'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_saving ? 'Creating...' : 'Create Animal'),
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
          return 'Please enter a value';
        }

        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
