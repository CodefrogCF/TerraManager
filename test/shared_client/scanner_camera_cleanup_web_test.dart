@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_client/scanner_camera_cleanup_web.dart';
import 'package:web/web.dart' as web;

void main() {
  test('cleanup stops scanner tracks in shadow DOM and clears its video', () {
    final host = web.HTMLDivElement();
    final shadow = host.attachShadow(web.ShadowRootInit(mode: 'open'));
    web.document.body!.append(host);
    addTearDown(() => host.remove());
    final stream = web.HTMLCanvasElement().captureStream(1);
    final tracks = stream.getTracks().toDart;
    expect(tracks, isNotEmpty);
    final video = web.HTMLVideoElement()
      ..style.pointerEvents = 'none'
      ..srcObject = stream;
    shadow.append(video);

    stopScannerCameraTracks();

    expect(tracks.every((track) => track.readyState == 'ended'), isTrue);
    expect(video.srcObject, isNull);
    // A repeated stop is harmless after the scanner was already released.
    stopScannerCameraTracks();
  });

  test('cleanup leaves an unrelated video stream running', () {
    final stream = web.HTMLCanvasElement().captureStream(1);
    final tracks = stream.getTracks().toDart;
    final video = web.HTMLVideoElement()
      ..controls = true
      ..srcObject = stream;
    web.document.body!.append(video);
    addTearDown(() {
      for (final track in tracks) {
        track.stop();
      }
      video.remove();
    });

    stopScannerCameraTracks();

    expect(tracks.every((track) => track.readyState == 'live'), isTrue);
    expect(video.srcObject, isNotNull);
  });
}
