import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'browser_history_port.dart';

BrowserHistoryPort createBrowserHistory() => _WebBrowserHistory();

class _WebBrowserHistory implements BrowserHistoryPort {
  final _session = DateTime.now().microsecondsSinceEpoch.toString();
  JSFunction? _listener;
  Future<void> _ready = Future.value();
  bool _disposed = false;

  Future<void> _report(int depth, {required bool replace}) =>
      SystemNavigator.routeInformationUpdated(
        uri: Uri.parse('/'),
        state: <String, Object>{
          'terramanagerNavigation': _session,
          'depth': depth,
        },
        replace: replace,
      );

  @override
  void initialize(void Function(int depth) onBack) {
    _ready = SystemNavigator.selectMultiEntryHistory().then((_) async {
      if (_disposed) return;
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
      await _report(0, replace: true);
    });
  }

  void _afterReady(Future<void> Function() action) {
    _ready = _ready.then((_) async {
      if (!_disposed) await action();
    });
    unawaited(_ready);
  }

  @override
  void pushDepth(int depth) =>
      _afterReady(() => _report(depth, replace: false));
  @override
  void replaceDepth(int depth) =>
      _afterReady(() => _report(depth, replace: true));
  @override
  void back(int count) => _afterReady(() async {
    web.window.history.go(-count);
  });
  @override
  void dispose() {
    _disposed = true;
    if (_listener != null) {
      web.window.removeEventListener('popstate', _listener);
    }
    _listener = null;
  }
}
