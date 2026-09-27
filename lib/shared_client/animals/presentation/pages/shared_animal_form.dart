import 'package:flutter/material.dart';
import 'package:terramanager/core/database/date_only.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/validation/animal_environmental_limits.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/animals/presentation/widgets/animal_range_fields.dart';
import 'package:terramanager/features/feedings/presentation/widgets/feeding_reminder_form_fields.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_scanner_page.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

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
  Map<String, dynamic>? _initial;
  late List<Map<String, dynamic>> _boxes;
  int? _boxId;
  AnimalCategory _category = AnimalCategory.other;
  AnimalSubcategory? _subcategory;
  Sex? _sex;
  DateTime? _birthDate;
  String? _birthAccuracy;
  bool _showWeightOnDetail = true;
  bool _showSheddingOnDetail = true;
  bool _reminderEnabled = false;
  DateTime? _reminderBaseline;
  bool _saving = false;
  bool _stale = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initial = widget.initial;
    _boxes = widget.boxes;
    final initial = widget.initial;
    _showWeightOnDetail = initial?['showWeightOnDetail'] as bool? ?? true;
    _showSheddingOnDetail = initial?['showSheddingOnDetail'] as bool? ?? true;
    final activeBoxes = _boxes.where((box) => box['status'] == 'active');
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
    _birthDate = initial?['birthDate'] == null
        ? null
        : parseDateOnly(initial!['birthDate'] as String);
    _birthAccuracy = initial?['birthDateAccuracy'] as String?;
    _reminderBaseline = DateTime.tryParse(
      initial?['feedingReminderBaseline'] as String? ?? '',
    );
    _reminderEnabled =
        initial?['feedingReminderIntervalDays'] is int &&
        _reminderBaseline != null;
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

  bool get _hasUnsavedEdits {
    final initial = _initial;
    if (initial == null) return false;
    if (_boxId != initial['boxId'] ||
        _category.name != initial['category'] ||
        _subcategory?.name != initial['subcategory'] ||
        _sex?.name != initial['sex'] ||
        _birthAccuracy != initial['birthDateAccuracy'] ||
        _showWeightOnDetail != (initial['showWeightOnDetail'] ?? true) ||
        _showSheddingOnDetail != (initial['showSheddingOnDetail'] ?? true)) {
      return true;
    }
    final originalBaseline = DateTime.tryParse(
      initial['feedingReminderBaseline'] as String? ?? '',
    );
    if (_reminderEnabled !=
            (initial['feedingReminderIntervalDays'] is int &&
                originalBaseline != null) ||
        _reminderBaseline?.toUtc().toIso8601String() !=
            originalBaseline?.toUtc().toIso8601String()) {
      return true;
    }
    final initialBirthDate = DateTime.tryParse(
      initial['birthDate'] as String? ?? '',
    );
    if (dateOnlyString(initialBirthDate) != dateOnlyString(_birthDate)) {
      return true;
    }
    for (final entry in _fields.entries) {
      final original = initial[entry.key]?.toString().trim();
      if (_text(entry.key) !=
          (original == null || original.isEmpty ? null : original)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _openBoxSelectionScanner() async {
    if (_initial != null || _saving || !widget.api.connected) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SharedBoxScannerPage(
          api: widget.api,
          boxes: _boxes,
          animals: const [],
          change: widget.change,
          title: context.l10n.scanBoxTitle,
          onBoxResolved: (scannerContext, box) async {
            final boxes = await widget.api.boxes();
            if (!mounted || !scannerContext.mounted) return null;
            final id = recordId(box);
            if (!boxes.any(
              (candidate) =>
                  candidate['status'] == 'active' && candidate['id'] == id,
            )) {
              ScaffoldMessenger.of(scannerContext).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.boxUnavailableForAssignment),
                ),
              );
              return false;
            }
            setState(() {
              _boxes = boxes;
              _boxId = id;
              _error = null;
            });
            Navigator.of(scannerContext).pop();
            return null;
          },
        ),
      ),
    );
  }

  Future<void> _openRehouseScanner() async {
    if (_initial == null || _saving || _stale || !widget.api.connected) {
      return;
    }
    if (_hasUnsavedEdits) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            sharedText(context, 'Unsaved changes', 'Ungespeicherte Änderungen'),
          ),
          content: Text(
            sharedText(
              context,
              'QR reassignment will not save the other edits in this form. Discard them and continue?',
              'Beim Umsetzen per QR werden die anderen Änderungen in diesem Formular nicht gespeichert. Verwerfen und fortfahren?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(sharedText(context, 'Continue', 'Fortfahren')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    final moved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SharedBoxScannerPage(
          api: widget.api,
          boxes: _boxes,
          animals: const [],
          change: widget.change,
          title: context.l10n.rehouseMode,
          onBoxResolved: _rehouseToBox,
        ),
      ),
    );
    if (moved == true && mounted) Navigator.of(context).pop(true);
  }

  Future<bool?> _rehouseToBox(
    BuildContext scannerContext,
    Map<String, dynamic> box,
  ) async {
    final initial = _initial;
    if (initial == null || !mounted) return false;
    final boxId = box['id'] as int;
    if (boxId == initial['boxId']) {
      ScaffoldMessenger.of(
        scannerContext,
      ).showSnackBar(SnackBar(content: Text(context.l10n.animalAlreadyInBox)));
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: scannerContext,
      builder: (dialogContext) => AlertDialog(
        key: const Key('shared-rehouse-confirmation'),
        title: Text(context.l10n.rehouseAnimalTitle),
        content: Text(
          context.l10n.rehouseAnimalConfirmation(
            initial['commonName'] as String,
            boxLabel(box),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('shared-rehouse-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.rehouseAnimalAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.change(() async {
      await widget.api.rehouseAnimal(
        recordId(initial),
        boxId,
        initial['revision'] as String,
      );
    });
    if (!mounted || !scannerContext.mounted) return false;
    if (saved) {
      Navigator.of(scannerContext).pop(true);
      return true;
    }
    setState(() {
      _saving = false;
      _stale =
          widget.api.lastFailure is SharedApiException &&
          (widget.api.lastFailure as SharedApiException).code == 'stale_record';
      _error = _stale
          ? sharedText(
              context,
              'This Animal changed on the server. Reload and review it before moving.',
              'Dieses Tier wurde auf dem Server geändert. Lade den neuen Stand und prüfe ihn vor dem Umsetzen.',
            )
          : context.l10n.failedToRehouseAnimal;
    });
    Navigator.of(scannerContext).pop(false);
    return false;
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
      'birthDate': dateOnlyString(_birthDate),
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
      'pictureMediaId': _initial?['pictureMediaId'],
      'feedingReminderIntervalDays': _reminderEnabled
          ? int.parse(_text('feedingReminderIntervalDays')!)
          : null,
      'feedingReminderBaseline': _reminderEnabled
          ? _reminderBaseline?.toUtc().toIso8601String()
          : null,
      'showWeightOnDetail': _showWeightOnDetail,
      'showSheddingOnDetail': _showSheddingOnDetail,
    };
    final saved = await widget.change(() async {
      if (_initial == null) {
        await widget.api.createAnimal(values);
      } else {
        await widget.api.updateAnimal(
          recordId(_initial!),
          values,
          _initial!['revision'] as String,
        );
      }
    });
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _stale =
            widget.api.lastFailure is SharedApiException &&
            (widget.api.lastFailure as SharedApiException).code ==
                'stale_record';
        _error = _stale
            ? sharedText(
                context,
                'This Animal changed on the server. Reload and review the new values before saving.',
                'Dieses Tier wurde auf dem Server geändert. Lade die neuen Werte und prüfe sie vor dem Speichern.',
              )
            : sharedText(
                context,
                'The result is uncertain. Reload and check the server data.',
                'Das Ergebnis ist unklar. Neu laden und Serverdaten prüfen.',
              );
      });
    }
  }

  Future<void> _reloadLatest() async {
    if (_initial == null || !widget.api.connected) return;
    try {
      final latest = await widget.api.animal(recordId(_initial!));
      final boxes = await widget.api.boxes();
      if (!mounted) return;
      if (latest['status'] != 'active') {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() {
        _initial = latest;
        _showWeightOnDetail = latest['showWeightOnDetail'] as bool? ?? true;
        _showSheddingOnDetail = latest['showSheddingOnDetail'] as bool? ?? true;
        _boxes = boxes;
        _boxId = latest['boxId'] as int?;
        _category = AnimalCategory.values.firstWhere(
          (value) => value.name == latest['category'],
          orElse: () => AnimalCategory.other,
        );
        _subcategory = null;
        for (final value in AnimalSubcategory.values) {
          if (value.name == latest['subcategory']) _subcategory = value;
        }
        _sex = null;
        for (final value in Sex.values) {
          if (value.name == latest['sex']) _sex = value;
        }
        _birthDate = latest['birthDate'] == null
            ? null
            : parseDateOnly(latest['birthDate'] as String);
        _birthAccuracy = latest['birthDateAccuracy'] as String?;
        _reminderBaseline = DateTime.tryParse(
          latest['feedingReminderBaseline'] as String? ?? '',
        );
        _reminderEnabled =
            latest['feedingReminderIntervalDays'] is int &&
            _reminderBaseline != null;
        for (final entry in _fields.entries) {
          entry.value.text = latest[entry.key]?.toString() ?? '';
        }
        _stale = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = sharedText(
            context,
            'Could not reload the Animal.',
            'Das Tier konnte nicht neu geladen werden.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedPageWidth(
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? sharedText(context, 'New Animal', 'Neues Tier')
              : sharedText(context, 'Edit Animal', 'Tier bearbeiten'),
        ),
      ),
      body: ConstrainedPageWidth(
        maxWidth: 760,
        child: ListenableBuilder(
          listenable: widget.api,
          builder: (context, _) => Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _fields['commonName'],
                  decoration: InputDecoration(
                    labelText: sharedText(
                      context,
                      'Common name',
                      'Trivialname',
                    ),
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: ValueKey('shared-animal-box-$_boxId'),
                        initialValue: _boxId,
                        decoration: InputDecoration(
                          labelText: sharedText(context, 'Box', 'Box'),
                        ),
                        items: [
                          for (final box in _boxes.where(
                            (box) => box['status'] == 'active',
                          ))
                            DropdownMenuItem(
                              value: recordId(box),
                              child: Text(
                                boxLabel(box),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _boxId = value),
                      ),
                    ),
                    ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        key: Key(
                          _initial == null
                              ? 'shared-new-animal-scan-box-button'
                              : 'shared-rehouse-scan-button',
                        ),
                        tooltip: context.l10n.scanNewBox,
                        onPressed: widget.api.connected && !_saving && !_stale
                            ? (_initial == null
                                  ? _openBoxSelectionScanner
                                  : _openRehouseScanner)
                            : null,
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                    ],
                  ],
                ),
                DropdownButtonFormField<AnimalCategory>(
                  isExpanded: true,
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
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _category = value;
                      if (!_category.supports(_subcategory)) {
                        _subcategory = null;
                      }
                    });
                  },
                ),
                DropdownButtonFormField<AnimalSubcategory?>(
                  isExpanded: true,
                  key: ValueKey(_category),
                  initialValue: _subcategory,
                  decoration: InputDecoration(
                    labelText: sharedText(
                      context,
                      'Subcategory',
                      'Unterkategorie',
                    ),
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
                  heading: sharedText(
                    context,
                    'Humidity (%)',
                    'Feuchtigkeit (%)',
                  ),
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
                            : dateOnlyString(_birthDate)!,
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: _birthDate ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (selected != null) {
                          setState(() => _birthDate = selected);
                        }
                      },
                    ),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
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
                      onChanged: (value) =>
                          setState(() => _birthAccuracy = value),
                    ),
                    DropdownButtonFormField<Sex?>(
                      isExpanded: true,
                      initialValue: _sex,
                      decoration: InputDecoration(
                        labelText: sharedText(context, 'Sex', 'Geschlecht'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            sharedText(context, 'Unknown', 'Unbekannt'),
                          ),
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
                    FeedingReminderFormFields(
                      reminderEnabled: _reminderEnabled,
                      controlsEnabled: !_saving,
                      intervalDaysController:
                          _fields['feedingReminderIntervalDays']!,
                      onReminderEnabledChanged: (enabled) => setState(() {
                        _reminderEnabled = enabled;
                        _reminderBaseline = enabled ? DateTime.now() : null;
                      }),
                    ),
                  ],
                ),
                if (_initial != null) ...[
                  SwitchListTile(
                    key: const Key('shared-show-weight-on-detail'),
                    title: Text(context.l10n.showWeightOnAnimalDetail),
                    subtitle: Text(
                      context.l10n.showWeightOnAnimalDetailDescription,
                    ),
                    value: _showWeightOnDetail,
                    onChanged: !_saving && !_stale && widget.api.connected
                        ? (value) => setState(() => _showWeightOnDetail = value)
                        : null,
                  ),
                  SwitchListTile(
                    key: const Key('shared-show-shedding-on-detail'),
                    title: Text(context.l10n.showSheddingOnAnimalDetail),
                    subtitle: Text(
                      context.l10n.showSheddingOnAnimalDetailDescription,
                    ),
                    value: _showSheddingOnDetail,
                    onChanged: !_saving && !_stale && widget.api.connected
                        ? (value) =>
                              setState(() => _showSheddingOnDetail = value)
                        : null,
                  ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_stale)
                  TextButton.icon(
                    onPressed: widget.api.connected ? _reloadLatest : null,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      sharedText(
                        context,
                        'Reload and review',
                        'Neu laden und prüfen',
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('shared-save-animal'),
                  onPressed: widget.api.connected && !_saving && !_stale
                      ? _save
                      : null,
                  child: Text(context.l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
