import 'dart:async';

import 'package:terramanager/shared_client/navigation/infrastructure/browser_history_port.dart';

/// Browser traversals finish asynchronously. Later route writes must wait for
/// popstate, and the echo of an in-app pop must not pop a new Flutter dialog.
abstract class SerializedBrowserHistory implements BrowserHistoryPort {
  Future<void> _ready = Future.value();
  Completer<void>? _traversal;
  void Function(int)? _onBack;
  bool _disposed = false;
  bool get isDisposed => _disposed;

  Future<void> start(void Function(int) onHistoryChanged);
  Future<void> report(int depth, {required bool replace});
  void traverse(int count);
  void stop();

  @override
  void initialize(void Function(int depth) onBack) {
    _onBack = onBack;
    _ready = start(_historyChanged).then((_) async {
      if (!_disposed) await report(0, replace: true);
    });
  }

  void _historyChanged(int depth) {
    if (_disposed) return;
    final traversal = _traversal;
    if (traversal != null) {
      _traversal = null;
      traversal.complete();
      return;
    }
    _onBack?.call(depth);
  }

  void _enqueue(Future<void> Function() action) {
    _ready = _ready.then((_) async {
      if (!_disposed) await action();
    });
    unawaited(_ready);
  }

  @override
  void pushDepth(int depth) => _enqueue(() => report(depth, replace: false));
  @override
  void replaceDepth(int depth) => _enqueue(() => report(depth, replace: true));
  @override
  void back(int count) => _enqueue(() async {
    final traversal = _traversal = Completer<void>();
    traverse(count);
    await traversal.future;
  });

  @override
  void dispose() {
    _disposed = true;
    _onBack = null;
    _traversal?.complete();
    _traversal = null;
    stop();
  }
}
