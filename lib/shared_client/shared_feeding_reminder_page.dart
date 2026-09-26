import 'package:flutter/material.dart';

import '../core/presentation/widgets/constrained_page_width.dart';
import '../features/animals/presentation/animal_display_names.dart';
import '../features/feedings/presentation/widgets/feeding_reminder_form_fields.dart';
import '../l10n/app_localizations_context.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_text.dart';

/// Edits one server-owned reminder without sending the other Animal fields.
class SharedFeedingReminderPage extends StatefulWidget {
  const SharedFeedingReminderPage({
    super.key,
    required this.api,
    required this.animalId,
    required this.change,
  });

  final SharedApiClient api;
  final int animalId;
  final SharedChange change;

  @override
  State<SharedFeedingReminderPage> createState() =>
      _SharedFeedingReminderPageState();
}

class _SharedFeedingReminderPageState extends State<SharedFeedingReminderPage> {
  final _form = GlobalKey<FormState>();
  final _interval = TextEditingController();
  Map<String, dynamic>? _animal;
  DateTime? _baseline;
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _stale = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final animal = await widget.api.animal(widget.animalId);
      if (!mounted) return;
      if (animal['status'] != 'active') {
        setState(() {
          _animal = null;
          _loading = false;
          _error = context.l10n.archivedAnimalsCannotBeEdited;
        });
        return;
      }
      final baseline = DateTime.tryParse(
        animal['feedingReminderBaseline'] as String? ?? '',
      );
      _interval.text = animal['feedingReminderIntervalDays']?.toString() ?? '';
      setState(() {
        _animal = animal;
        _baseline = baseline;
        _enabled =
            animal['feedingReminderIntervalDays'] is int && baseline != null;
        _loading = false;
        _dirty = false;
        _stale = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.failedToLoadFeedingReminder;
      });
    }
  }

  Future<void> _save() async {
    final animal = _animal;
    if (_saving ||
        _loading ||
        _stale ||
        animal == null ||
        !widget.api.connected ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.change(() async {
      await widget.api.updateFeedingReminder(
        widget.animalId,
        expectedRevision: animal['revision'] as String,
        intervalDays: _enabled ? int.parse(_interval.text.trim()) : null,
        baseline: _enabled ? _baseline : null,
      );
    });
    if (!mounted) return;
    if (saved) {
      setState(() => _dirty = false);
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
                'This Animal changed on the server. Reload and review the reminder.',
                'Dieses Tier wurde auf dem Server geändert. Lade die Erinnerung neu und prüfe sie.',
              )
            : context.l10n.failedToSaveFeedingReminder;
      });
    }
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.unsavedChanges),
          content: Text(context.l10n.unsavedChangesLeaveQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.discard),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _dirty = false);
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop) await _back();
    },
    child: ConstrainedPageWidth(
      child: Scaffold(
        key: const Key('shared-feeding-reminder-page'),
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Text(context.l10n.feedingReminder),
          actions: [
            IconButton(
              key: const Key('shared-feeding-reminder-save-action'),
              onPressed: _saving || _loading || _animal == null || _stale
                  ? null
                  : _save,
              tooltip: context.l10n.save,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: ConstrainedPageWidth(
          maxWidth: 760,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _animal == null
              ? Center(child: Text(_error ?? context.l10n.animalNotFound))
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        AnimalDisplayNames.fromContext(
                          context,
                          commonName: _animal!['commonName'] as String? ?? '',
                          latinName: _animal!['latinName'] as String? ?? '',
                        ).primary,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          key: const Key('shared-feeding-reminder-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (_stale)
                          TextButton.icon(
                            onPressed: widget.api.connected ? _load : null,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              sharedText(
                                context,
                                'Reload and review',
                                'Neu laden und prüfen',
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      FeedingReminderFormFields(
                        reminderEnabled: _enabled,
                        controlsEnabled: !_saving && !_stale,
                        intervalDaysController: _interval,
                        onReminderEnabledChanged: (enabled) => setState(() {
                          _enabled = enabled;
                          _baseline = enabled ? DateTime.now() : null;
                          _dirty = true;
                        }),
                        onIntervalChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('shared-feeding-reminder-save'),
                        onPressed: _saving || _stale ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(context.l10n.save),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
