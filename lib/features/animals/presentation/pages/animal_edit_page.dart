import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/presentation/widgets/constrained_page_width.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/birth_date_accuracy.dart';
import '../../../../core/database/enums/animal_category.dart';
import '../../../../core/database/enums/sex.dart';
import '../../../../core/database/enums/animal_status.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/animal_weight_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/database/repositories/box_lifecycle_exception.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/database/validation/animal_environmental_limits.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../boxes/presentation/box_selection_label.dart';
import '../../../boxes/presentation/pages/box_scanner_page.dart';
import '../../../media/presentation/picture_selection_flow.dart';
import '../../../media/presentation/widgets/picture_selection_controls.dart';
import '../animal_archive_dialog.dart';
import '../animal_environmental_validator.dart';
import '../widgets/animal_additional_characteristics_fields.dart';
import '../widgets/animal_picture.dart';
import '../widgets/animal_range_fields.dart';
import '../widgets/animal_taxonomy_fields.dart';
import '../shedding_entry_dialog.dart';
import 'shedding_history_page.dart';

class AnimalEditPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;
  final PictureSelectionFlow? pictureSelectionFlow;

  const AnimalEditPage({
    super.key,
    required this.database,
    required this.animalId,
    this.pictureSelectionFlow,
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
  final _originHabitatController = TextEditingController();
  final _weightController = TextEditingController();
  final _restOrDormancyPeriodsController = TextEditingController();
  final _nighttimeTemperatureMinController = TextEditingController();
  final _nighttimeTemperatureMaxController = TextEditingController();
  final _notesController = TextEditingController();

  late final PictureSelectionFlow _pictureSelectionFlow;

  Sex _sex = Sex.unknown;
  AnimalCategory _category = AnimalCategory.other;
  AnimalSubcategory? _subcategory;
  BirthDateAccuracy? _birthDateAccuracy;
  DateTime? _birthDate;
  int? _boxId;

  int? _pictureMediaId;

  String? _legacyPicturePath;

  Uint8List? _pictureBytes;
  String? _pictureFileName;
  String? _pictureMimeType;

  bool _pictureChanged = false;

  List<Box> _boxes = [];

  bool _loading = true;
  bool _saving = false;
  bool _archiving = false;
  bool _processingPicture = false;
  bool _hasUnsavedChanges = false;
  bool _additionalCharacteristicsExpanded = false;
  bool _showWeightOnDetail = true;
  bool _showSheddingOnDetail = true;

  String? _error;
  Animal? _animal;

  bool get _actionInProgress => _saving || _archiving;

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
    _originHabitatController.dispose();
    _weightController.dispose();
    _restOrDormancyPeriodsController.dispose();
    _nighttimeTemperatureMinController.dispose();
    _nighttimeTemperatureMaxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openRehouseScanner() async {
    final animal = _animal;

    if (animal == null || _actionInProgress || _processingPicture) {
      return;
    }

    final moved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BoxScannerPage(
          database: widget.database,
          title: context.l10n.rehouseMode,
          onBoxScanned: (box) async {
            final confirmed = await _confirmRehouse(animal: animal, box: box);

            return confirmed;
          },
        ),
      ),
    );

    if (!mounted || moved != true) {
      return;
    }

    _hasUnsavedChanges = false;
    Navigator.of(context).pop(true);
  }

  Future<bool> _confirmRehouse({
    required Animal animal,
    required Box box,
  }) async {
    if (box.id == animal.boxId) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.animalAlreadyInBox)));

      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('rehouse-confirmation-dialog'),
          title: Text(context.l10n.rehouseAnimalTitle),
          content: Text(
            context.l10n.rehouseAnimalConfirmation(
              animal.commonName,
              boxSelectionLabel(context.l10n, box),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('rehouse-cancel-button'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('rehouse-confirm-button'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(context.l10n.rehouseAnimalAction),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return false;
    }

    try {
      final moved = await AnimalRepository(widget.database)
          .moveAnimalToBox(animalId: animal.id, boxId: box.id);

      if (!mounted) {
        return true;
      }

      if (!moved) {
        setState(() {
          _error = context.l10n.failedToRehouseAnimal;
        });

        return false;
      }

      _hasUnsavedChanges = false;

      return true;
    } on BoxAssignmentException {
      if (!mounted) {
        return false;
      }

      setState(() {
        _error = context.l10n.boxUnavailableForAssignment;
      });

      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _error = context.l10n.failedToRehouseAnimal;
      });

      return false;
    }
  }

  Future<void> _addSheddingEntry() async {
    final animal = _animal;

    if (_actionInProgress || _processingPicture || animal == null) {
      return;
    }

    await showSheddingEntryDialog(
      context: context,
      database: widget.database,
      animalId: animal.id,
    );
  }

  Future<void> _openSheddingHistory() async {
    final animal = _animal;

    if (_actionInProgress || _processingPicture || animal == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            SheddingHistoryPage(database: widget.database, animalId: animal.id),
      ),
    );
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

      final latestWeight = await AnimalWeightRepository(widget.database)
          .getLatest(animal.id);

      final boxes = await boxRepository.getActiveBoxes();

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
      _originHabitatController.text = animal.originHabitat ?? '';
      _weightController.text = latestWeight?.weightGrams.toString() ?? '';
      _restOrDormancyPeriodsController.text =
          animal.restOrDormancyPeriods ?? '';
      _nighttimeTemperatureMinController.text =
          (animal.nighttimeTemperatureMin ?? animal.nighttimeTemperature)
              ?.toString() ??
          '';
      _nighttimeTemperatureMaxController.text =
          (animal.nighttimeTemperatureMax ?? animal.nighttimeTemperature)
              ?.toString() ??
          '';
      _notesController.text = animal.notes ?? '';

      _additionalCharacteristicsExpanded = [
        animal.originHabitat,
        animal.birthDate?.toString(),
        animal.birthDateAccuracy?.name,
        animal.sex == null || animal.sex == Sex.unknown
            ? null
            : animal.sex!.name,
        latestWeight?.weightGrams.toString(),
        animal.weight,
        animal.originHabitat,
        animal.nighttimeTemperatureMin?.toString(),
        animal.nighttimeTemperatureMax?.toString(),
        animal.nighttimeTemperature?.toString(),
        animal.restOrDormancyPeriods,
        animal.notes,
      ].any((value) => value != null && value.trim().isNotEmpty);

      _sex = animal.sex ?? Sex.unknown;
      _category = animal.category;
      _subcategory = animal.subcategory;
      _birthDate = animal.birthDate;
      _birthDateAccuracy = animal.birthDateAccuracy;
      _showWeightOnDetail = animal.showWeightOnDetail;
      _showSheddingOnDetail = animal.showSheddingOnDetail;
      _boxId = boxes.any((box) => box.id == animal.boxId) ? animal.boxId : null;

      _pictureMediaId = animal.pictureMediaId;

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
    if (_processingPicture || _actionInProgress) {
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
    if (_processingPicture || _actionInProgress) {
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
    if (_actionInProgress || _processingPicture) {
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
          category: _category,
          subcategory: _subcategory,
          sex: _sex,
          birthDate: _birthDate,
          birthDateAccuracy: _birthDateAccuracy,
          tempMin: parseAnimalDecimal(_tempMinController.text)!,
          tempMax: parseAnimalDecimal(_tempMaxController.text)!,
          nighttimeTemperatureMin: _optionalDouble(
            _nighttimeTemperatureMinController,
          ),
          nighttimeTemperatureMax: _optionalDouble(
            _nighttimeTemperatureMaxController,
          ),
          humidityMin: parseAnimalDecimal(_humidityMinController.text)!,
          humidityMax: parseAnimalDecimal(_humidityMaxController.text)!,
          originHabitat: _optionalText(_originHabitatController),
          weight: _animal!.weight,
          weightGrams: _optionalDouble(_weightController),
          restOrDormancyPeriods: _optionalText(
            _restOrDormancyPeriodsController,
          ),
          pictureMediaId: pictureMediaId,
          picturePath: legacyPicturePath,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          feedingReminderIntervalDays: _animal!.feedingReminderIntervalDays,
          feedingReminderBaseline: _animal!.feedingReminderBaseline,
          showWeightOnDetail: _showWeightOnDetail,
          showSheddingOnDetail: _showSheddingOnDetail,
        );

        if (!updated) {
          throw StateError('Animal update failed');
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
    } on BoxAssignmentException {
      try {
        final boxes = await BoxRepository(widget.database).getActiveBoxes();
        if (!mounted) {
          return;
        }
        setState(() {
          _boxes = boxes;
          _boxId = null;
          _saving = false;
          _error = context.l10n.boxUnavailableForAssignment;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _saving = false;
          _error = context.l10n.failedToLoadBoxes;
        });
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

  Future<void> _archiveAnimal() async {
    final animal = _animal;
    if (_actionInProgress ||
        _processingPicture ||
        animal == null ||
        animal.status != AnimalStatus.active) {
      return;
    }

    final result = await showDialog<AnimalArchiveInput>(
      context: context,
      builder: (_) =>
          AnimalArchiveDialog(hasUnsavedChanges: _hasUnsavedChanges),
    );
    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _archiving = true;
      _error = null;
    });

    try {
      final archived = await AnimalRepository(widget.database).archiveAnimal(
        animalId: animal.id,
        reason: result.reason,
        archivedAt: result.archivedAt,
        archiveNotes: result.notes,
      );
      if (!mounted) {
        return;
      }
      if (!archived) {
        setState(() {
          _archiving = false;
          _error = context.l10n.failedToArchiveAnimal;
        });
        return;
      }

      _hasUnsavedChanges = false;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _archiving = false;
          _error = context.l10n.failedToArchiveAnimal;
        });
      }
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
    if (_actionInProgress) {
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
      canPop: !_hasUnsavedChanges && !_actionInProgress,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _handleBack();
      },
      child: ConstrainedPageWidth(
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
                onPressed: _actionInProgress || _processingPicture
                    ? null
                    : _save,
                icon: const Icon(Icons.save),
                tooltip: context.l10n.save,
              ),
            ],
          ),
          body: ConstrainedPageWidth(maxWidth: 760, child: _buildBody()),
        ),
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
              enabled: !_actionInProgress,
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

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('box-field'),
                    initialValue: _boxId,
                    decoration: InputDecoration(
                      labelText: context.l10n.associatedBox,
                    ),
                    items: _boxes
                        .map(
                          (box) => DropdownMenuItem<int>(
                            value: box.id,
                            child: Text(boxSelectionLabel(context.l10n, box)),
                          ),
                        )
                        .toList(),
                    onChanged: _actionInProgress
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
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('rehouse-scan-button'),
                  onPressed: _actionInProgress || _processingPicture
                      ? null
                      : _openRehouseScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: context.l10n.scanNewBox,
                ),
              ],
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

            AnimalTaxonomyFields(
              category: _category,
              subcategory: _subcategory,
              enabled: !_actionInProgress,
              onChanged: (category, subcategory) {
                setState(() {
                  _category = category;
                  _subcategory = subcategory;
                  _hasUnsavedChanges = true;
                });
              },
            ),
            const SizedBox(height: 16),

            AnimalRangeFields.temperature(
              key: const Key('daytime-temperature-range'),
              heading: context.l10n.daytimeTemperatureCelsius,
              minimumKey: const Key('temp-min-field'),
              maximumKey: const Key('temp-max-field'),
              minimumController: _tempMinController,
              maximumController: _tempMaxController,
              required: true,
              enabled: !_actionInProgress,
              onChanged: (_) => _markAsChanged(),
            ),
            const SizedBox(height: 16),

            AnimalRangeFields(
              key: const Key('humidity-range'),
              heading: context.l10n.humidityPercent,
              minimumKey: const Key('humidity-min-field'),
              maximumKey: const Key('humidity-max-field'),
              minimumController: _humidityMinController,
              maximumController: _humidityMaxController,
              minimumAllowed: AnimalEnvironmentalLimits.minimumHumidityPercent,
              maximumAllowed: AnimalEnvironmentalLimits.maximumHumidityPercent,
              required: true,
              enabled: !_actionInProgress,
              onChanged: (_) => _markAsChanged(),
            ),
            const SizedBox(height: 16),
            AnimalAdditionalCharacteristicsFields(
              expanded: _additionalCharacteristicsExpanded,
              enabled: !_actionInProgress && !_processingPicture,
              onToggle: () {
                setState(() {
                  _additionalCharacteristicsExpanded =
                      !_additionalCharacteristicsExpanded;
                });
              },
              onChanged: (_) => _markAsChanged(),
              birthDateField: ListTile(
                key: const Key('birth-date-field'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.birthDate),
                subtitle: Text(
                  _birthDate == null
                      ? context.l10n.notSpecified
                      : _formatDate(_birthDate!),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_birthDate != null)
                      IconButton(
                        key: const Key('clear-birth-date-button'),
                        tooltip: context.l10n.clearBirthDate,
                        icon: const Icon(Icons.clear),
                        onPressed: _actionInProgress ? null : _clearBirthDate,
                      ),
                    IconButton(
                      key: const Key('birth-date-button'),
                      tooltip: context.l10n.selectBirthDate,
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _actionInProgress ? null : _selectBirthDate,
                    ),
                  ],
                ),
              ),
              birthDateAccuracyField:
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
                          child: Text(
                            context.l10n.birthAccuracyLabel(accuracy),
                          ),
                        ),
                      ),
                    ],
                    onChanged: _actionInProgress || _birthDate == null
                        ? null
                        : (value) {
                            setState(() {
                              _birthDateAccuracy = value;
                              _hasUnsavedChanges = true;
                            });
                          },
                  ),
              sexField: DropdownButtonFormField<Sex>(
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
                onChanged: _actionInProgress
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _sex = value;
                            _hasUnsavedChanges = true;
                          });
                        }
                      },
              ),
              weightController: _weightController,
              legacyWeight: _animal?.weight,
              originHabitatController: _originHabitatController,
              nighttimeTemperatureMinController:
                  _nighttimeTemperatureMinController,
              nighttimeTemperatureMaxController:
                  _nighttimeTemperatureMaxController,
              restOrDormancyPeriodsController: _restOrDormancyPeriodsController,
              notesController: _notesController,
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              key: const Key('show-weight-on-detail-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.showWeightOnAnimalDetail),
              subtitle: Text(context.l10n.showWeightOnAnimalDetailDescription),
              value: _showWeightOnDetail,
              onChanged: _actionInProgress || _processingPicture
                  ? null
                  : (value) {
                      setState(() {
                        _showWeightOnDetail = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),

            SwitchListTile(
              key: const Key('show-shedding-on-detail-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.showSheddingOnAnimalDetail),
              subtitle: Text(
                context.l10n.showSheddingOnAnimalDetailDescription,
              ),
              value: _showSheddingOnDetail,
              onChanged: _actionInProgress || _processingPicture
                  ? null
                  : (value) {
                      setState(() {
                        _showSheddingOnDetail = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('edit-animal-add-shedding-button'),
                    onPressed: _actionInProgress || _processingPicture
                        ? null
                        : _addSheddingEntry,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addSheddingEvent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('edit-animal-shedding-history-button'),
                    onPressed: _actionInProgress || _processingPicture
                        ? null
                        : _openSheddingHistory,
                    icon: const Icon(Icons.history),
                    label: Text(context.l10n.sheddingHistory),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              key: const Key('save-animal-form-button'),
              onPressed: _actionInProgress || _processingPicture ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(context.l10n.save),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              key: const Key('archive-animal-button'),
              onPressed: _actionInProgress || _processingPicture
                  ? null
                  : _archiveAnimal,
              icon: _archiving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.archive_outlined),
              label: Text(context.l10n.archiveAnimal),
            ),
          ],
        ),
      ),
    );
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _optionalDouble(TextEditingController controller) {
    final value = controller.text.trim();
    return parseAnimalDecimal(value);
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

  void _clearBirthDate() {
    if (_birthDate == null || _actionInProgress) {
      return;
    }

    setState(() {
      _birthDate = null;
      _birthDateAccuracy = null;
      _hasUnsavedChanges = true;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
