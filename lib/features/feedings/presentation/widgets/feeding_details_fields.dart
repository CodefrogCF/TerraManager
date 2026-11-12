import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';

import '../../domain/feeding_field_values.dart';
import '../../domain/food_preset.dart';
import '../pages/food_presets_page.dart';
import 'feeding_details_access.dart';

class FeedingDetailsFields extends StatefulWidget {
  const FeedingDetailsFields({
    super.key,
    required this.access,
    required this.notes,
    this.saved,
    this.enabled = true,
  });

  final FeedingDetailsAccess access;
  final Widget notes;
  final List<FeedingFieldValue>? saved;
  final bool enabled;

  @override
  State<FeedingDetailsFields> createState() => FeedingDetailsFieldsState();
}

class FeedingDetailsFieldsState extends State<FeedingDetailsFields>
    with AutomaticKeepAliveClientMixin<FeedingDetailsFields> {
  final _form = GlobalKey<FormState>();
  late final CustomFieldsController _fields;
  late Future<List<FoodPreset>> _presets;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final access = widget.access.fields;
    _fields = CustomFieldsController(
      CustomFieldAccess(
        target: CustomFieldTarget.feeding,
        load: () async => feedingFieldsSnapshot(
          await access.templates(),
          saved: widget.saved,
        ),
        templates: access.templates,
        saveTemplate: access.saveTemplate,
      ),
    );
    unawaited(_fields.load());
    _presets = widget.access.presets();
  }

  bool validate() => _form.currentState?.validate() ?? true;

  CustomFieldPatch? get patch => _fields.patch;

  Future<void> _managePresets() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FoodPresetsPage(access: widget.access)),
    );
    if (mounted) {
      setState(() {
        _presets = widget.access.presets();
      });
    }
  }

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<FoodPreset>>(
      future: _presets,
      builder: (context, snapshot) => ListenableBuilder(
        listenable: _fields,
        builder: (context, _) {
          final defaults = {
            for (final preset in snapshot.data ?? const <FoodPreset>[])
              if (!preset.archived)
                preset: preset.applicableDefaults(_fields.editable),
          };
          final presets = defaults.entries.where(
            (entry) => entry.value.isNotEmpty,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  context.l10n.feedingDetails,
                  key: const Key('feeding-details-fields'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (presets.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<FoodPreset>(
                    key: const Key('feeding-preset-picker'),
                    isExpanded: true,
                    hint: Text(context.l10n.foodPresetSelect),
                    items: [
                      for (final entry in presets)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.key.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: !widget.enabled
                        ? null
                        : (preset) {
                            if (preset != null) {
                              _fields.applyDefaults(defaults[preset]!);
                            }
                          },
                  ),
                ),
              const SizedBox(height: 8),
              Form(
                key: _form,
                child: CustomFieldsEditor(
                  controller: _fields,
                  enabled: widget.enabled,
                  compact: true,
                  showManagement: false,
                ),
              ),
              const SizedBox(height: 12),
              widget.notes,
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  CustomFieldTemplatesButton(
                    controller: _fields,
                    enabled:
                        widget.enabled && !_fields.loading && !_fields.failed,
                  ),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: widget.enabled
                          ? () => setState(() {
                              _presets = widget.access.presets();
                            })
                          : null,
                      child: Text(context.l10n.foodPresetsRetry),
                    ),
                  TextButton.icon(
                    key: const Key('manage-food-presets'),
                    onPressed: widget.enabled ? _managePresets : null,
                    icon: const Icon(Icons.restaurant_menu),
                    label: Text(context.l10n.foodPresetsManage),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget? feedingDetailsSubtitle(
  BuildContext context,
  String? notes,
  List<FeedingFieldValue> fields,
) {
  final rows = [
    for (final field in fields)
      Text(
        '${field.template.label} · ${customFieldDisplay(context, field.template, field.value)}',
      ),
    if (notes?.trim().isNotEmpty ?? false) Text(notes!),
  ];
  if (rows.isEmpty) return null;
  if (rows.length == 1) return rows.single;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: rows,
  );
}
