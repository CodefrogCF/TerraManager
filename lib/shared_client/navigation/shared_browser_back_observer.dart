import 'dart:async';

import 'package:flutter/material.dart';

import 'browser_history_port.dart';
import 'browser_history_stub.dart'
    if (dart.library.js_interop) 'browser_history_web.dart'
    as platform;

/// Imperative routes (including unnamed dialogs and scanners) need browser
/// history entries too. The entry stores only depth, never record/session data.
class SharedBrowserBackObserver extends NavigatorObserver {
  SharedBrowserBackObserver({BrowserHistoryPort? history})
    : _history = history ?? platform.createBrowserHistory();
  final BrowserHistoryPort _history;
  final List<Route<dynamic>> _routes = [];
  final List<int> _pushedDuringBack = [];
  bool _initialized = false;
  bool _handlingBack = false;
  bool _disposed = false;
  int? _queuedDepth;
  int get depth => _routes.length - 1;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    if (!_initialized) {
      _initialized = true;
      _history.initialize((target) => unawaited(handleBrowserBack(target)));
    } else if (_handlingBack) {
      _pushedDuringBack.add(depth);
    } else {
      _history.pushDepth(depth);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    if (!_handlingBack && !_disposed) _history.back(1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final removed = _routes.remove(route);
    if (removed && !_handlingBack && !_disposed) _history.back(1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null) return;
    final index = _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
  }

  Future<void> handleBrowserBack(int targetDepth) async {
    if (_disposed || navigator == null) return;
    if (_handlingBack) {
      _queuedDepth = targetDepth;
      return;
    }
    if (targetDepth < 0) return;
    // Forward/reload cannot reconstruct arbitrary unsaved forms or camera
    // sessions. Keep the current view instead of reopening sensitive routes.
    if (targetDepth >= depth) {
      _history.replaceDepth(depth);
      return;
    }
    _handlingBack = true;
    _pushedDuringBack.clear();
    try {
      while (!_disposed && depth > targetDepth) {
        final before = depth;
        await navigator!.maybePop();
        if (depth >= before) {
          // A PopScope can refuse or ask for confirmation. Rebuild the history
          // entry for the protected page before adding its confirmation dialog.
          _history.pushDepth(before);
          for (final pushed in _pushedDuringBack) {
            _history.pushDepth(pushed);
          }
          break;
        }
      }
    } finally {
      _pushedDuringBack.clear();
      _handlingBack = false;
      final queued = _queuedDepth;
      _queuedDepth = null;
      if (queued != null && !_disposed) await handleBrowserBack(queued);
    }
  }

  void dispose() {
    _disposed = true;
    _history.dispose();
    _routes.clear();
  }
}
