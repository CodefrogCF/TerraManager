import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/settings/presentation/pages/shared_care_event_types_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_care_history_page.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/shared/application/shared_change.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

class SharedBoxCareHistoryPage extends StatefulWidget {
  const SharedBoxCareHistoryPage({
    super.key,
    required this.api,
    required this.boxId,
    required this.label,
    required this.change,
  });
  final SharedApiClient api;
  final int boxId;
  final String label;
  final SharedChange change;
  @override
  State<SharedBoxCareHistoryPage> createState() =>
      _SharedBoxCareHistoryPageState();
}

class _SharedBoxCareHistoryPageState extends State<SharedBoxCareHistoryPage> {
  final _page = GlobalKey<BoxCareHistoryPageState>();
  late final SharedRefreshSubscription _refresh;
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    _refresh = widget.api.refresh.watch(
      dependencies: () => {
        'boxes': {widget.boxId},
        'boxCareHistories': {widget.boxId},
        'careEventTypes': null,
      },
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
  Widget build(BuildContext context) => BoxCareHistoryPage(
    key: _page,
    boxLabel: widget.label,
    manageTypes: () async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SharedCareEventTypesPage(api: widget.api),
        ),
      );
    },
    load: () async {
      final box = await widget.api.box(widget.boxId);
      final entries = await widget.api.boxCareEvents(widget.boxId);
      return BoxCareHistoryData(
        entries: entries,
        active: box['status'] == 'active',
        canDelete: widget.api.canDeleteCollection,
        types: await widget.api.careEventTypes(),
      );
    },
    save:
        ({
          existing,
          required type,
          customTypeId,
          required occurredAt,
          notes,
          required requestId,
        }) => widget.change(() async {
          await widget.api.saveBoxCareEvent(
            widget.boxId,
            existing: existing,
            type: type,
            customTypeId: customTypeId,
            occurredAt: occurredAt,
            notes: notes,
            requestId: requestId,
          );
        }),
    delete: (entry) =>
        widget.change(() => widget.api.deleteBoxCareEvent(entry)),
  );
}
