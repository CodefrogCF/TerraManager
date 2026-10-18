// Optional measurement build. Production main_shared.dart remains unchanged.
// drawFrame measures Flutter UI build/layout/paint CPU, NOT presented pixels.
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'package:terramanager/main_shared.dart' as production;

@JS('tm230Metrics')
external set _metrics(JSFunction value);

class AcceptanceBinding extends WidgetsFlutterBinding {
  final _samples = <int>[];
  var _dropped = 0;
  @override
  void drawFrame() {
    final watch = Stopwatch()..start();
    try {
      super.drawFrame();
    } finally {
      if (_samples.length < 10000) {
        _samples.add(watch.elapsedMicroseconds);
      } else {
        _dropped++;
      }
    }
  }

  JSString snapshot(JSBoolean reset) {
    final result = jsonEncode({
      'kind': 'instrumented-flutter-drawFrame-CPU',
      'timeOriginMs': web.window.performance.timeOrigin,
      'atMs': web.window.performance.now(),
      'frameCpuMicroseconds': _samples,
      'droppedSamples': _dropped,
      'limit': 'Not GPU raster, widget build count, browser paint or physical presentation latency.',
    });
    if (reset.toDart) {
      _samples.clear();
      _dropped = 0;
    }
    return result.toJS;
  }
}

void main() {
  final binding = AcceptanceBinding();
  _metrics = binding.snapshot.toJS;
  production.main();
}
