import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';

CustomFieldAccess sharedCustomFields(
  SharedApiClient api,
  CustomFieldTarget target, [
  int? id,
]) => CustomFieldAccess(
  target: target,
  load: () => api.customFields(target, id),
  templates: () => api.customFieldTemplates(target),
  saveTemplate: (t, {required creating}) =>
      api.saveCustomFieldTemplate(t, creating: creating),
);

class SharedCustomFieldsSection extends StatefulWidget {
  const SharedCustomFieldsSection({
    super.key,
    required this.api,
    required this.target,
    required this.id,
  });
  final SharedApiClient api;
  final CustomFieldTarget target;
  final int id;
  @override
  State<SharedCustomFieldsSection> createState() => _SectionState();
}

class _SectionState extends State<SharedCustomFieldsSection> {
  final _key = GlobalKey<CustomFieldsSectionState>();
  late final SharedRefreshSubscription _refresh;
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    _refresh = widget.api.refresh.watch(
      dependencies: () => {
        'customFieldTemplates': null,
        widget.target == CustomFieldTarget.animal
            ? 'animalCustomFields'
            : 'boxCustomFields': {
          widget.id,
        },
      },
      isVisible: () => mounted && (_route?.isCurrent ?? false),
      refresh: (_) async {
        await _key.currentState?.reload();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(
          widget.api.refresh.refreshVisible().catchError((Object _) {}),
        );
      }
    });
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomFieldsSection(
    key: _key,
    access: sharedCustomFields(widget.api, widget.target, widget.id),
  );
}
