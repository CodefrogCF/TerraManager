import 'package:flutter/material.dart';

import '../core/database/enums/animal_category.dart';
import '../core/database/enums/birth_date_accuracy.dart';
import '../core/database/enums/sex.dart';
import '../core/database/validation/animal_environmental_limits.dart';
import '../features/animals/presentation/widgets/animal_range_fields.dart';
import '../l10n/app_localizations_context.dart';
import '../l10n/app_localizations_labels.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_text.dart';

class SharedBoxForm extends StatefulWidget {
  const SharedBoxForm({
    super.key,
    required this.api,
    required this.change,
    this.initial,
  });
  final SharedApiClient api;
  final SharedChange change;
  final Map<String, dynamic>? initial;

  @override
  State<SharedBoxForm> createState() => _SharedBoxFormState();
}

class _SharedBoxFormState extends State<SharedBoxForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fields = {
      for (final key in [
        'name',
        'widthCm',
        'heightCm',
        'depthCm',
        'temperatureZones',
        'notes',
      ])
        key: TextEditingController(
          text: widget.initial?[key]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _text(String key) {
    final value = _fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _number(String key) {
    final value = _text(key);
    return value == null ? null : double.tryParse(value.replaceAll(',', '.'));
  }

  String? _positive(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null || !number.isFinite || number <= 0) {
      return sharedText(
        context,
        'Enter a positive number.',
        'Positive Zahl eingeben.',
      );
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !widget.api.connected || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final values = <String, dynamic>{
      'name': _text('name'),
      'widthCm': _number('widthCm'),
      'heightCm': _number('heightCm'),
      'depthCm': _number('depthCm'),
      'temperatureZones': _text('temperatureZones'),
      'notes': _text('notes'),
    };
    final saved = await widget.change(() async {
      if (widget.initial == null) {
        await widget.api.createBox(values);
      } else {
        await widget.api.updateBox(recordId(widget.initial!), values);
      }
    });
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = sharedText(
          context,
          'The result is uncertain. Reload and check the server data.',
          'Das Ergebnis ist unklar. Neu laden und Serverdaten prüfen.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.initial == null
            ? sharedText(context, 'New Box', 'Neue Box')
            : sharedText(context, 'Edit Box', 'Box bearbeiten'),
      ),
    ),
    body: ListenableBuilder(
      listenable: widget.api,
      builder: (context, _) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _fields['name'],
              maxLength: 200,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Name', 'Name'),
              ),
            ),
            for (final entry in [
              ('widthCm', 'Width (cm)', 'Breite (cm)'),
              ('heightCm', 'Height (cm)', 'Höhe (cm)'),
              ('depthCm', 'Depth (cm)', 'Tiefe (cm)'),
            ])
              TextFormField(
                controller: _fields[entry.$1],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _positive,
                decoration: InputDecoration(
                  labelText: sharedText(context, entry.$2, entry.$3),
                ),
              ),
            TextFormField(
              controller: _fields['temperatureZones'],
              maxLines: 2,
              decoration: InputDecoration(
                labelText: sharedText(
                  context,
                  'Temperature zones',
                  'Temperaturzonen',
                ),
              ),
            ),
            TextFormField(
              controller: _fields['notes'],
              maxLines: 4,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Notes', 'Notizen'),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('shared-save-box'),
              onPressed: widget.api.connected && !_saving ? _save : null,
              child: Text(sharedText(context, 'Save', 'Speichern')),
            ),
          ],
        ),
      ),
    ),
  );
}

class SharedAnimalForm extends StatefulWidget {
  const SharedAnimalForm({
    super.key,
    required this.api,
    required this.boxes,
    required this.change,
    this.initial,
  });
  final SharedApiClient api;
  final List<Map<String, dynamic>> boxes;
  final SharedChange change;
  final Map<String, dynamic>? initial;

  @override
  State<SharedAnimalForm> createState() => _SharedAnimalFormState();
}

class _SharedAnimalFormState extends State<SharedAnimalForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  int? _boxId;
  AnimalCategory _category = AnimalCategory.other;
  AnimalSubcategory? _subcategory;
  Sex? _sex;
  DateTime? _birthDate;
  String? _birthAccuracy;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final activeBoxes = widget.boxes.where((box) => box['status'] == 'active');
    _boxId =
        initial?['boxId'] as int? ??
        (activeBoxes.isEmpty ? null : recordId(activeBoxes.first));
    _category = AnimalCategory.values.firstWhere(
      (value) => value.name == initial?['category'],
      orElse: () => AnimalCategory.other,
    );
    for (final value in AnimalSubcategory.values) {
      if (value.name == initial?['subcategory']) _subcategory = value;
    }
    for (final value in Sex.values) {
      if (value.name == initial?['sex']) _sex = value;
    }
    _birthDate = DateTime.tryParse(initial?['birthDate'] as String? ?? '');
    _birthAccuracy = initial?['birthDateAccuracy'] as String?;
    _fields = {
      for (final key in [
        'commonName',
        'latinName',
        'tempMin',
        'tempMax',
        'nighttimeTemperatureMin',
        'nighttimeTemperatureMax',
        'humidityMin',
        'humidityMax',
        'originHabitat',
        'restOrDormancyPeriods',
        'notes',
        'feedingReminderIntervalDays',
      ])
        key: TextEditingController(text: initial?[key]?.toString() ?? ''),
    };
    if (initial == null) {
      _fields['tempMin']!.text = '20';
      _fields['tempMax']!.text = '30';
      _fields['humidityMin']!.text = '40';
      _fields['humidityMax']!.text = '60';
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _text(String key) {
    final value = _fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _number(String key) {
    final value = _text(key);
    return value == null ? null : double.tryParse(value.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (_saving || !widget.api.connected || !_form.currentState!.validate()) {
      return;
    }
    if (_boxId == null) return;
    final tempMin = _number('tempMin')!;
    final tempMax = _number('tempMax')!;
    final humidityMin = _number('humidityMin')!;
    final humidityMax = _number('humidityMax')!;
    try {
      AnimalEnvironmentalLimits.validate(
        temperatureMinimum: tempMin,
        temperatureMaximum: tempMax,
        nighttimeTemperatureMinimum: _number('nighttimeTemperatureMin'),
        nighttimeTemperatureMaximum: _number('nighttimeTemperatureMax'),
        humidityMinimum: humidityMin,
        humidityMaximum: humidityMax,
      );
    } catch (_) {
      setState(
        () => _error = sharedText(
          context,
          'Check the temperature and humidity ranges.',
          'Temperatur- und Feuchtigkeitsbereiche prüfen.',
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final values = <String, dynamic>{
      'boxId': _boxId,
      'commonName': _text('commonName') ?? '',
      'latinName': _text('latinName') ?? '',
      'category': _category.name,
      'subcategory': _subcategory?.name,
      'sex': _sex?.name,
      'birthDate': _birthDate?.toUtc().toIso8601String(),
      'birthDateAccuracy': _birthAccuracy,
      'tempMin': tempMin,
      'tempMax': tempMax,
      'nighttimeTemperatureMin': _number('nighttimeTemperatureMin'),
      'nighttimeTemperatureMax': _number('nighttimeTemperatureMax'),
      'humidityMin': humidityMin,
      'humidityMax': humidityMax,
      'originHabitat': _text('originHabitat'),
      'restOrDormancyPeriods': _text('restOrDormancyPeriods'),
      'notes': _text('notes'),
      'pictureMediaId': widget.initial?['pictureMediaId'],
      'feedingReminderIntervalDays': int.tryParse(
        _text('feedingReminderIntervalDays') ?? '',
      ),
      'feedingReminderBaseline': widget.initial?['feedingReminderBaseline'],
      'showWeightOnDetail': widget.initial?['showWeightOnDetail'] ?? true,
      'showSheddingOnDetail': widget.initial?['showSheddingOnDetail'] ?? true,
    };
    final saved = await widget.change(() async {
      if (widget.initial == null) {
        await widget.api.createAnimal(values);
      } else {
        await widget.api.updateAnimal(recordId(widget.initial!), values);
      }
    });
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = sharedText(
          context,
          'The result is uncertain. Reload and check the server data.',
          'Das Ergebnis ist unklar. Neu laden und Serverdaten prüfen.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.initial == null
            ? sharedText(context, 'New Animal', 'Neues Tier')
            : sharedText(context, 'Edit Animal', 'Tier bearbeiten'),
      ),
    ),
    body: ListenableBuilder(
      listenable: widget.api,
      builder: (context, _) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _fields['commonName'],
              decoration: InputDecoration(
                labelText: sharedText(context, 'Common name', 'Trivialname'),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? sharedText(context, 'Required', 'Pflichtfeld')
                  : null,
            ),
            TextFormField(
              controller: _fields['latinName'],
              decoration: InputDecoration(
                labelText: sharedText(
                  context,
                  'Latin name',
                  'Lateinischer Name',
                ),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? sharedText(context, 'Required', 'Pflichtfeld')
                  : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: _boxId,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Box', 'Box'),
              ),
              items: [
                for (final box in widget.boxes.where(
                  (box) => box['status'] == 'active',
                ))
                  DropdownMenuItem(
                    value: recordId(box),
                    child: Text(boxLabel(box)),
                  ),
              ],
              onChanged: (value) => setState(() => _boxId = value),
            ),
            DropdownButtonFormField<AnimalCategory>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Category', 'Kategorie'),
              ),
              items: [
                for (final value in AnimalCategory.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(context.l10n.animalCategoryLabel(value)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  if (!_category.supports(_subcategory)) _subcategory = null;
                });
              },
            ),
            DropdownButtonFormField<AnimalSubcategory?>(
              key: ValueKey(_category),
              initialValue: _subcategory,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Subcategory', 'Unterkategorie'),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(sharedText(context, 'None', 'Keine')),
                ),
                for (final value in _category.subcategories)
                  DropdownMenuItem(
                    value: value,
                    child: Text(context.l10n.animalSubcategoryLabel(value)),
                  ),
              ],
              onChanged: (value) => setState(() => _subcategory = value),
            ),
            AnimalRangeFields.temperature(
              heading: sharedText(
                context,
                'Day temperature (°C)',
                'Tagestemperatur (°C)',
              ),
              minimumKey: const Key('shared-temp-min'),
              maximumKey: const Key('shared-temp-max'),
              minimumController: _fields['tempMin']!,
              maximumController: _fields['tempMax']!,
              required: true,
              enabled: !_saving,
            ),
            AnimalRangeFields.temperature(
              heading: sharedText(
                context,
                'Night temperature (°C)',
                'Nachttemperatur (°C)',
              ),
              minimumKey: const Key('shared-night-min'),
              maximumKey: const Key('shared-night-max'),
              minimumController: _fields['nighttimeTemperatureMin']!,
              maximumController: _fields['nighttimeTemperatureMax']!,
              required: false,
              enabled: !_saving,
            ),
            AnimalRangeFields(
              heading: sharedText(context, 'Humidity (%)', 'Feuchtigkeit (%)'),
              minimumKey: const Key('shared-humidity-min'),
              maximumKey: const Key('shared-humidity-max'),
              minimumController: _fields['humidityMin']!,
              maximumController: _fields['humidityMax']!,
              minimumAllowed: 0,
              maximumAllowed: 100,
              required: true,
              enabled: !_saving,
            ),
            ExpansionTile(
              title: Text(
                sharedText(
                  context,
                  'Additional characteristics',
                  'Weitere Merkmale',
                ),
              ),
              children: [
                ListTile(
                  title: Text(
                    _birthDate == null
                        ? sharedText(context, 'Birth date', 'Geburtsdatum')
                        : _birthDate!.toLocal().toString().split(' ').first,
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _birthDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) setState(() => _birthDate = selected);
                  },
                ),
                DropdownButtonFormField<String?>(
                  initialValue: _birthAccuracy,
                  decoration: InputDecoration(
                    labelText: sharedText(
                      context,
                      'Birth date accuracy',
                      'Genauigkeit des Geburtsdatums',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(sharedText(context, 'None', 'Keine')),
                    ),
                    for (final value in BirthDateAccuracy.values)
                      DropdownMenuItem(
                        value: value.name,
                        child: Text(context.l10n.birthAccuracyLabel(value)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _birthAccuracy = value),
                ),
                DropdownButtonFormField<Sex?>(
                  initialValue: _sex,
                  decoration: InputDecoration(
                    labelText: sharedText(context, 'Sex', 'Geschlecht'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(sharedText(context, 'Unknown', 'Unbekannt')),
                    ),
                    for (final value in Sex.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(context.l10n.animalSexLabel(value)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _sex = value),
                ),
                for (final entry in [
                  (
                    'originHabitat',
                    'Origin / habitat',
                    'Herkunft / Lebensraum',
                  ),
                  (
                    'restOrDormancyPeriods',
                    'Rest / dormancy periods',
                    'Ruhezeiten',
                  ),
                  ('notes', 'Notes', 'Notizen'),
                ])
                  TextFormField(
                    controller: _fields[entry.$1],
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: sharedText(context, entry.$2, entry.$3),
                    ),
                  ),
                TextFormField(
                  controller: _fields['feedingReminderIntervalDays'],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: sharedText(
                      context,
                      'Feeding interval (days)',
                      'Fütterungsintervall (Tage)',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('shared-save-animal'),
              onPressed: widget.api.connected && !_saving ? _save : null,
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    ),
  );
}
