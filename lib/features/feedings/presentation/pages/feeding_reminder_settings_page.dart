import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/animal_status.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../animals/presentation/animal_display_names.dart';
import '../../application/feeding_reminder_service.dart';
import '../widgets/feeding_reminder_form_fields.dart';

class FeedingReminderSettingsPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;
  final FeedingReminderClock? now;

  const FeedingReminderSettingsPage({
    super.key,
    required this.database,
    required this.animalId,
    this.now,
  });

  @override
  State<FeedingReminderSettingsPage> createState() =>
      _FeedingReminderSettingsPageState();
}

class _FeedingReminderSettingsPageState
    extends State<FeedingReminderSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _intervalDaysController = TextEditingController();

  Animal? _animal;
  bool _reminderEnabled = false;
  DateTime? _baseline;
  bool _loading = true;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReminder();
  }

  @override
  void dispose() {
    _intervalDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadReminder() async {
    try {
      final animal = await AnimalRepository(widget.database)
          .getAnimalById(widget.animalId);

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

      final intervalDays = animal.feedingReminderIntervalDays;
      final baseline = animal.feedingReminderBaseline;

      _animal = animal;
      _reminderEnabled = intervalDays != null && baseline != null;
      _intervalDaysController.text = intervalDays?.toString() ?? '';
      _baseline = baseline;

      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = context.l10n.failedToLoadFeedingReminder;
      });
    }
  }

  void _setReminderEnabled(bool enabled) {
    if (_saving) {
      return;
    }

    setState(() {
      _reminderEnabled = enabled;
      _baseline = enabled ? (widget.now ?? DateTime.now)() : null;
      _hasUnsavedChanges = true;
      _error = null;
    });
  }

  void _markAsChanged() {
    if (_hasUnsavedChanges) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _save() async {
    if (_saving || _animal == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await AnimalRepository(widget.database)
          .updateFeedingReminder(
            animalId: widget.animalId,
            intervalDays: _reminderEnabled
                ? int.parse(_intervalDaysController.text.trim())
                : null,
            baseline: _reminderEnabled ? _baseline : null,
          );

      if (!mounted) {
        return;
      }

      if (!updated) {
        throw StateError('Feeding reminder update failed');
      }

      _hasUnsavedChanges = false;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = context.l10n.failedToSaveFeedingReminder;
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
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
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
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        key: const Key('feeding-reminder-settings-page'),
        appBar: AppBar(
          leading: BackButton(
            key: const Key('back-feeding-reminder-button'),
            onPressed: _handleBack,
          ),
          title: Text(context.l10n.feedingReminder),
          actions: [
            IconButton(
              key: const Key('save-feeding-reminder-button'),
              onPressed: _loading || _saving || _animal == null ? null : _save,
              icon: const Icon(Icons.save),
              tooltip: context.l10n.save,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_animal == null) {
      return Center(child: Text(_error ?? context.l10n.animalNotFound));
    }

    final displayNames = AnimalDisplayNames.fromContext(
      context,
      commonName: _animal!.commonName,
      latinName: _animal!.latinName,
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            displayNames.primary,
            key: const Key('feeding-reminder-animal-name'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            displayNames.secondary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(
              _error!,
              key: const Key('feeding-reminder-save-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
          ],
          FeedingReminderFormFields(
            reminderEnabled: _reminderEnabled,
            controlsEnabled: !_saving,
            intervalDaysController: _intervalDaysController,
            onReminderEnabledChanged: _setReminderEnabled,
            onIntervalChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('save-feeding-reminder-form-button'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? context.l10n.saving : context.l10n.save),
          ),
        ],
      ),
    );
  }
}
