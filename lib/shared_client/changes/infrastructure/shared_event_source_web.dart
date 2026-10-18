import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;
import 'package:terramanager/shared_client/changes/domain/shared_event_source_port.dart';

SharedEventSourcePort createSharedEventSource() => _BrowserSource();

class _BrowserSource implements SharedEventSourcePort {
  web.EventSource? _source;
  final _listeners = <String, JSFunction>{};
  @override
  bool get supported => web.window.hasProperty('EventSource'.toJS).toDart;

  @override
  void open(
    Uri url, {
    required void Function() onOpen,
    required void Function(String event, String data, String id) onMessage,
    required void Function() onError,
  }) {
    close();
    if (url.origin != web.window.location.origin ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw ArgumentError(
        'Change streams must use the current origin without credentials or query.',
      );
    }
    final source = web.EventSource(url.toString());
    _source = source;
    void listen(String name, void Function(web.Event) callback) {
      final listener = callback.toJS;
      _listeners[name] = listener;
      source.addEventListener(name, listener);
    }

    listen('open', (_) => onOpen());
    listen('error', (_) => onError());
    for (final name in ['changes', 'auth-required', 'keepalive']) {
      listen(name, (event) {
        final message = event as web.MessageEvent;
        final data = message.data;
        if (!data.isA<JSString>()) {
          onError();
          return;
        }
        onMessage(name, (data as JSString).toDart, message.lastEventId);
      });
    }
  }

  @override
  void close() {
    final source = _source;
    _source = null;
    if (source == null) return;
    for (final entry in _listeners.entries) {
      source.removeEventListener(entry.key, entry.value);
    }
    _listeners.clear();
    // Also cancels the browser's implicit retry. Policy belongs to #229.
    source.close();
  }
}
