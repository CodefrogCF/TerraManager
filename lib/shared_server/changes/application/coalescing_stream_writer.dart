import 'dart:async';

/// One in-flight write plus a dirty bit, regardless of the number of commits.
/// A missed retained revision becomes a reset when the next frame is built.
class CoalescingStreamWriter {
  CoalescingStreamWriter({
    required this.write,
    required this.onFailure,
    required this.timeout,
  });
  final Future<void> Function() write;
  final void Function() onFailure;
  final Duration timeout;
  final _closed = Completer<void>();
  bool _running = false;
  bool _dirty = false;
  bool get closed => _closed.isCompleted;

  void request() {
    if (closed) return;
    _dirty = true;
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_dirty && !closed) {
        _dirty = false;
        await Future.any<void>([write(), _closed.future]).timeout(timeout);
      }
    } catch (_) {
      if (!closed) {
        close();
        onFailure();
      }
    } finally {
      _running = false;
    }
  }

  void close() {
    _dirty = false;
    if (!closed) _closed.complete();
  }
}
