import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:terramanager/features/media/application/picture_optimizer.dart';
import 'package:terramanager/features/media/presentation/pages/picture_crop_page.dart';
import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';

import '../features/media/presentation/fake_picture_selection_flow.dart';

class _Picker extends ImagePicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(bytes, name: 'source.jpg', mimeType: 'image/jpeg');
}

class _CropRecorder implements PictureOptimizer {
  Uint8List? cropped;
  @override
  Future<OptimizedPicture> optimize({
    required Uint8List bytes,
    required String sourceFileName,
  }) async {
    cropped = bytes;
    return OptimizedPicture(
      bytes: bytes,
      fileName: 'cropped.png',
      mimeType: 'image/png',
    );
  }
}

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  fail('Image workflow did not finish');
}

Future<SharedApiClient> _login(
  Future<http.Response> Function(http.Request) handler,
) async {
  final api = SharedApiClient(
    Uri.parse('https://localhost'),
    MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'user': {'username': 'carer', 'role': 'caregiver'},
            'csrfToken': 'csrf',
          }),
          200,
        );
      }
      return handler(request);
    }),
  );
  await api.login('carer', 'password');
  return api;
}

Widget _gallery(
  SharedApiClient api,
  String kind,
  PictureSelectionFlow? flow,
  VoidCallback onChanged, {
  Key? key,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SharedPictureGallery(
        key: key,
        api: api,
        kind: kind,
        recordId: 1,
        active: true,
        pictureSelectionFlow: flow,
        change: (mutation) async {
          try {
            await mutation();
            return true;
          } catch (_) {
            return false;
          }
        },
        onChanged: onChanged,
      ),
    ),
  ),
);

void main() {
  for (final kind in ['animals', 'boxes']) {
    for (final cancel in [false, true]) {
      testWidgets(
        '$kind uses the real crop step and ${cancel ? 'cancellation never uploads' : 'confirmation uploads oriented cropped bytes'}',
        (tester) async {
          final source = image.Image(width: 120, height: 80);
          tester.view.physicalSize = kind == 'animals'
              ? const Size(320, 844)
              : const Size(1280, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (var y = 0; y < 80; y++) {
            for (var x = 0; x < 120; x++) {
              source.setPixelRgb(x, y, x < 60 ? 255 : 0, 0, x < 60 ? 0 : 255);
            }
          }
          if (kind == 'animals') source.exif.imageIfd.orientation = 6;
          final original = image.encodeJpg(source);
          final optimizer = _CropRecorder();
          final flow = DefaultPictureSelectionFlow(
            imagePicker: _Picker(original),
            pictureOptimizer: optimizer,
          );
          final uploads = <Map<String, dynamic>>[];
          var changes = 0;
          final pictures = <Map<String, dynamic>>[
            {'mediaId': 42, 'isPrimary': true},
          ];
          final api = await _login((request) async {
            if (request.url.path == '/api/v1/$kind/1/pictures') {
              if (request.method == 'POST') {
                uploads.add(jsonDecode(request.body) as Map<String, dynamic>);
                pictures[0] = {...pictures[0], 'isPrimary': false};
                pictures.add({'mediaId': 99, 'isPrimary': true});
                return http.Response(
                  jsonEncode({'picture': pictures.last}),
                  201,
                );
              }
              return http.Response(jsonEncode({'pictures': pictures}), 200);
            }
            return http.Response('{}', 404);
          });
          addTearDown(api.close);
          await tester.pumpWidget(_gallery(api, kind, flow, () => changes++));
          await tester.pumpAndSettle();
          final add = find.byKey(const Key('shared-add-gallery-picture'));
          await tester.ensureVisible(add);
          await tester.tap(add);
          await _waitFor(
            tester,
            () =>
                find
                    .byKey(PictureCropPage.applyButtonKey)
                    .evaluate()
                    .isNotEmpty &&
                tester
                        .widget<TextButton>(
                          find.byKey(PictureCropPage.applyButtonKey),
                        )
                        .onPressed !=
                    null,
          );
          await tester.pumpAndSettle();
          expect(find.byType(PictureCropPage), findsOneWidget);
          await tester.drag(
            find.byType(DotControl).last,
            const Offset(-12, -12),
            kind: kind == 'animals'
                ? PointerDeviceKind.touch
                : PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();
          expect(uploads, isEmpty);
          if (cancel) {
            await tester.tap(find.byKey(PictureCropPage.cancelButtonKey));
            await tester.pumpAndSettle();
            expect(uploads, isEmpty);
            expect(changes, 0);
            expect(pictures, hasLength(1));
            expect(optimizer.cropped, isNull);
          } else {
            await tester.tap(find.byKey(PictureCropPage.applyButtonKey));
            await _waitFor(tester, () => uploads.isNotEmpty && changes == 1);
            await tester.pumpAndSettle();
            expect(uploads, hasLength(1));
            final uploaded = base64Decode(
              uploads.single['dataBase64'] as String,
            );
            expect(uploaded, optimizer.cropped);
            expect(uploaded, isNot(original));
            expect(uploads.single['mimeType'], 'image/png');
            final decoded = image.decodeImage(uploaded)!;
            expect(decoded.width * decoded.height, lessThan(120 * 80));
            final first = kind == 'animals'
                ? decoded.getPixel(decoded.width ~/ 2, 0)
                : decoded.getPixel(0, decoded.height ~/ 2);
            final last = kind == 'animals'
                ? decoded.getPixel(decoded.width ~/ 2, decoded.height - 1)
                : decoded.getPixel(decoded.width - 1, decoded.height ~/ 2);
            expect(
              first.r,
              greaterThan(first.b),
              reason: 'Red half must retain its oriented position',
            );
            expect(
              last.b,
              greaterThan(last.r),
              reason: 'Blue half must retain its oriented position',
            );
            await tester.pumpWidget(
              _gallery(api, kind, flow, () => changes++, key: UniqueKey()),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const Key('shared-open-primary-picture')),
            );
            await tester.pumpAndSettle();
            expect(find.text('2 of 2'), findsOneWidget);
            final displayed = tester.widget<Image>(
              find.byKey(const Key('full-screen-image')),
            );
            expect(
              (displayed.image as NetworkImage).url,
              'https://localhost/api/v1/media/99',
            );
            expect(changes, 1);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'upload errors and an oversized cropped result cannot create a successful gallery entry',
    (tester) async {
      var uploads = 0;
      var changes = 0;
      final api = await _login((request) async {
        if (request.method == 'POST') {
          uploads++;
          return http.Response('{}', 500);
        }
        return http.Response(jsonEncode({'pictures': []}), 200);
      });
      addTearDown(api.close);
      for (final oversized in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final flow = FakePictureSelectionFlow(
          result: oversized
              ? SelectedPicture(
                  bytes: Uint8List(8 * 1024 * 1024 + 1),
                  fileName: 'huge.webp',
                  mimeType: 'image/webp',
                )
              : normalizedTestPicture('small.webp'),
        );
        await tester.pumpWidget(
          _gallery(api, 'boxes', flow, () => changes++, key: UniqueKey()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('shared-add-gallery-picture')));
        await tester.pumpAndSettle();
        expect(changes, 0);
        expect(uploads, 1);
        expect(
          find.text(
            oversized
                ? 'The cropped picture exceeds the 8 MiB upload limit.'
                : 'Picture could not be added',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Picture gallery'));
        await tester.pumpAndSettle();
        expect(find.text('No pictures saved yet'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'a pending picture selection disables resubmission and cancelling clears busy state',
    (tester) async {
      final pending = Completer<SelectedPicture?>();
      final flow = FakePictureSelectionFlow(pendingResult: pending.future);
      final api = await _login((request) async {
        expect(request.method, 'GET');
        return http.Response(jsonEncode({'pictures': []}), 200);
      });
      addTearDown(api.close);
      await tester.pumpWidget(
        _gallery(api, 'boxes', flow, () => fail('No upload expected')),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('shared-add-gallery-picture'));
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      await tester.tap(button);
      expect(flow.selectedSources, [ImageSource.gallery]);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    },
  );

  for (final kind in ['animals', 'boxes']) {
    testWidgets(
      '$kind primary and thumbnail viewers use the same ordered gallery and preserve expansion',
      (tester) async {
        final api = await _login(
          (_) async => http.Response(
            jsonEncode({
              'pictures': [
                {'mediaId': 41, 'isPrimary': false},
                {'mediaId': 42, 'isPrimary': true},
                {'mediaId': 43, 'isPrimary': false},
              ],
            }),
            200,
          ),
        );
        addTearDown(api.close);
        await tester.pumpWidget(_gallery(api, kind, null, () {}));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('shared-open-primary-picture')));
        await tester.pumpAndSettle();
        expect(find.text('2 of 3'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('close-full-screen-image-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Picture gallery'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('shared-open-gallery-picture-41')),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 of 3'), findsOneWidget);
        await tester.tap(find.byKey(const Key('next-full-screen-picture')));
        await tester.pumpAndSettle();
        expect(
          (tester
                      .widget<Image>(find.byKey(const Key('full-screen-image')))
                      .image
                  as NetworkImage)
              .url,
          'https://localhost/api/v1/media/42',
        );
        await tester.tap(
          find.byKey(const Key('close-full-screen-image-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('shared-open-gallery-picture-41')),
          findsOneWidget,
        );
      },
    );
  }
}
