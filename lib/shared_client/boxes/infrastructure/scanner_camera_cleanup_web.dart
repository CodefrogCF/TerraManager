import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Release the camera stream retained by mobile_scanner's browser polling
/// reader. Its stop() cancels decoding but currently leaves MediaStream tracks
/// running, so the browser still reports an active camera after leaving QR mode.
void stopScannerCameraTracks() {
  _stopVideosIn(web.document.querySelectorAll('*'));
}

void _stopVideosIn(web.NodeList nodes) {
  for (var index = 0; index < nodes.length; index++) {
    final element = nodes.item(index) as web.Element?;
    if (element == null) continue;

    if (element.localName == 'video') {
      final video = element as web.HTMLVideoElement;
      // The scanner creates a control-free video whose pointer events are
      // disabled. Leave any unrelated video content alone.
      if (!video.controls && video.style.pointerEvents == 'none') {
        final source = video.srcObject;
        if (source != null && source.isA<web.MediaStream>()) {
          final stream = source as web.MediaStream;
          for (final track in stream.getTracks().toDart) {
            track.stop();
          }
          video.srcObject = null;
        }
      }
    }

    // Flutter platform views can place the camera video in a shadow root.
    final shadowRoot = element.shadowRoot;
    if (shadowRoot != null) {
      _stopVideosIn(shadowRoot.querySelectorAll('*'));
    }
  }
}
