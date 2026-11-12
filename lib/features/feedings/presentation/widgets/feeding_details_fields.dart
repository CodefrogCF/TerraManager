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
    this.saved,
    this.enabled = true,
  });

  final FeedingDetailsAccess access;
  final List<FeedingFieldValue>? saved;
  final bool enabled;

  @override
  State<FeedingDetailsFields> createState() => FeedingDetailsFieldsState();
}

class FeedingDetailsFieldsState extends State<FeedingDetailsFields>
    with AutomaticKeepAliveClientMixin<FeedingDetailsFields> {
  final _form = GlobalKey<FormState>();
  final _expansion = ExpansibleController();
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

  bool validate() {
    final valid = _form.currentState?.validate() ?? true;
    if (!valid) _expansion.expand();
    return valid;
  }

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
    _expansion.dispose();
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
          final editableIds = _fields.editable
              .map((template) => template.id)
              .toSet();
          final presets = (snapshot.data ?? const <FoodPreset>[])
              .where(
                (preset) =>
                    !preset.archived &&
                    preset.defaults.keys.any(editableIds.contains),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (presets.isNotEmpty)
                DropdownButton<FoodPreset>(
                  key: const Key('feeding-preset-picker'),
                  isExpanded: true,
                  hint: Text(context.l10n.foodPresetSelect),
                  items: [
                    for (final preset in presets)
                      DropdownMenuItem(
                        value: preset,
                        child: Text(
                          preset.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: !widget.enabled
                      ? null
                      : (preset) {
                          if (preset == null) return;
                          _fields.applyDefaults(preset.defaults);
                          _expansion.expand();
                        },
                ),
              ExpansionTile(
                key: const Key('feeding-details-fields'),
                controller: _expansion,
                maintainState: true,
                tilePadding: EdgeInsets.zero,
                title: Text(context.l10n.feedingDetails),
                initiallyExpanded: widget.saved?.isNotEmpty ?? false,
                children: [
                  Form(
                    key: _form,
                    child: CustomFieldsEditor(
                      controller: _fields,
                      enabled: widget.enabled,
                    ),
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
