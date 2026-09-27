@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_client/navigation/infrastructure/serialized_browser_history.dart';
import 'package:web/web.dart' as web;

class _RealBrowserHistory extends SerializedBrowserHistory {
  JSFunction? _listener;
  final events = <String>[];
  @override
  Future<void> start(void Function(int) changed) async {
    _listener = ((web.Event event) {
      final state = (event as web.PopStateEvent).state?.dartify();
      if (state is Map && state['depth'] is int) {
        final depth = state['depth'] as int;
        events.add('pop $depth');
        changed(depth);
      }
    }).toJS;
    web.window.addEventListener('popstate', _listener);
  }

  @override
  Future<void> report(int depth, {required bool replace}) async {
    events.add('report $depth');
    final state = <String, Object>{'depth': depth}.jsify();
    if (replace) {
      web.window.history.replaceState(state, '', web.window.location.href);
    } else {
      web.window.history.pushState(state, '', web.window.location.href);
    }
  }

  @override
  void traverse(int count) {
    events.add('go $count');
    web.window.history.go(-count);
  }

  @override
  void stop() {
    if (_listener != null) {
      web.window.removeEventListener('popstate', _listener);
    }
    _listener = null;
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  final until = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(until)) {
      fail('Browser traversal did not complete.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('a menu popstate echo cannot close the next dialog, while real Back is delivered', () async {
    final history = _RealBrowserHistory();
    final returned = <int>[];
    addTearDown(history.dispose);
    history.initialize(returned.add);
    history.pushDepth(1);
    await _waitUntil(() => history.events.length == 2);
    history.back(1);
    history.pushDepth(1);
    await _waitUntil(() => history.events.length == 5);
    expect(history.events, [
      'report 0',
      'report 1',
      'go 1',
      'pop 0',
      'report 1',
    ]);
    expect(returned, isEmpty);
    web.window.history.go(-1); // The browser button or mobile Back gesture.
    await _waitUntil(() => returned.isNotEmpty);
    expect(returned, [0]);
  });

  test('rapid in-app pops finish before the next route is reported', () async {
    final history = _RealBrowserHistory();
    final returned = <int>[];
    addTearDown(history.dispose);
    history.initialize(returned.add);
    history.pushDepth(1);
    history.pushDepth(2);
    await _waitUntil(() => history.events.length == 3);
    history.back(1);
    history.back(1);
    history.pushDepth(1);
    await _waitUntil(() => history.events.length == 8);
    expect(history.events, [
      'report 0',
      'report 1',
      'report 2',
      'go 1',
      'pop 1',
      'go 1',
      'pop 0',
      'report 1',
    ]);
    expect(returned, isEmpty);
  });
}
