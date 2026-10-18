// Compiled separately to exercise the actual web adapter with real EventSource.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;
import 'package:terramanager/shared_client/changes/infrastructure/shared_event_source_web.dart';

void main() {
  final source = createSharedEventSource();
  final bridge = JSObject();
  final events = <Map<String, Object?>>[];
  var errors = 0;
  bridge.setProperty('ready'.toJS, true.toJS);
  bridge.setProperty('events'.toJS, '[]'.toJS);
  bridge.setProperty(
    'start'.toJS,
    ((JSString path) {
      events.clear();
      errors = 0;
      bridge.setProperty('events'.toJS, '[]'.toJS);
      bridge.setProperty('errors'.toJS, 0.toJS);
      source.open(
        Uri.parse(web.window.location.origin).resolve(path.toDart),
        onOpen: () => bridge.setProperty('open'.toJS, true.toJS),
        onMessage: (event, data, id) {
          events.add({'event': event, 'data': jsonDecode(data), 'id': id});
          bridge.setProperty('events'.toJS, jsonEncode(events).toJS);
          if (event == 'auth-required') source.close();
        },
        onError: () {
          errors++;
          source.close();
          bridge.setProperty('errors'.toJS, errors.toJS);
        },
      );
    }).toJS,
  );
  bridge.setProperty('stop'.toJS, (() => source.close()).toJS);
  web.window.setProperty('tmSseSmoke'.toJS, bridge);
}
