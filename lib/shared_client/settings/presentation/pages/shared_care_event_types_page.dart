import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/features/boxes/presentation/pages/care_event_types_page.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

class SharedCareEventTypesPage extends StatefulWidget {
  const SharedCareEventTypesPage({super.key, required this.api});
  final SharedApiClient api;
  @override
  State<SharedCareEventTypesPage> createState() =>
      _SharedCareEventTypesPageState();
}

class _SharedCareEventTypesPageState extends State<SharedCareEventTypesPage> {
  final _page = GlobalKey<CareEventTypesPageState>();
  late final SharedRefreshSubscription _refresh;
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    _refresh = widget.api.refresh.watch(
      dependencies: () => {'careEventTypes': null},
      isVisible: () => mounted && (_route?.isCurrent ?? false),
      refresh: (_) async {
        await _page.currentState?.reload();
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
  Widget build(BuildContext context) => CareEventTypesPage(
    key: _page,
    load: widget.api.careEventTypes,
    create: widget.api.createCareEventType,
    update: (type, label, archived) =>
        widget.api.updateCareEventType(type, label: label, archived: archived),
    reorder: widget.api.reorderCareEventTypes,
  );
}
