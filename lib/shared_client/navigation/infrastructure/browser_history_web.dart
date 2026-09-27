import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:terramanager/shared_client/navigation/infrastructure/browser_history_port.dart';
import 'package:terramanager/shared_client/navigation/infrastructure/serialized_browser_history.dart';
import 'package:web/web.dart' as web;

BrowserHistoryPort createBrowserHistory() => _WebBrowserHistory();

class _WebBrowserHistory extends SerializedBrowserHistory {
  final _session = DateTime.now().microsecondsSinceEpoch.toString();
  JSFunction? _listener;

  @override
  Future<void> report(int depth, {required bool replace}) =>
      SystemNavigator.routeInformationUpdated(
        uri: Uri.parse('/'),
        state: <String, Object>{
          'terramanagerNavigation': _session,
          'depth': depth,
        },
        replace: replace,
      );

  @override
  Future<void> start(void Function(int depth) onBack) async {
    await SystemNavigator.selectMultiEntryHistory();
    if (isDisposed) return;
    _listener = ((web.Event event) {
      final wrapped = (event as web.PopStateEvent).state?.dartify();
      final state = wrapped is Map ? wrapped['state'] : null;
      if (state is Map &&
          state['terramanagerNavigation'] == _session &&
          state['depth'] is int) {
        onBack(state['depth'] as int);
      }
    }).toJS;
    web.window.addEventListener('popstate', _listener);
  }

  @override
  void traverse(int count) => web.window.history.go(-count);

  @override
  void stop() {
    if (_listener != null) {
      web.window.removeEventListener('popstate', _listener);
    }
    _listener = null;
  }
}
