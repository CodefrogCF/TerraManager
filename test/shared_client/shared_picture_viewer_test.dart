import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';

void main() {
  testWidgets('shared primary picture opens the same zoomable viewer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient(
        (request) async => request.url.path == '/api/v1/boxes/1/pictures'
            ? http.Response(
                jsonEncode({
                  'pictures': [
                    {'mediaId': 42, 'isPrimary': true},
                  ],
                }),
                200,
              )
            : http.Response('{}', 404),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SharedPictureGallery(
            api: api,
            kind: 'boxes',
            recordId: 1,
            active: true,
            change: (_) async => true,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shared-open-primary-picture')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('full-screen-image-page')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('full-screen-image-page'))).width,
      1920,
    );
    final image = tester.widget<Image>(
      find.byKey(const Key('full-screen-image')),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://192.168.1.117/api/v1/media/42',
    );
    expect(
      tester
          .widget<InteractiveViewer>(
            find.byKey(const Key('full-screen-image-viewer')),
          )
          .scaleEnabled,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('close-full-screen-image-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('full-screen-image-page')), findsNothing);

    await tester.tap(find.text('Picture gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared-open-gallery-picture-42')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('full-screen-image-page')), findsOneWidget);
  });
}
