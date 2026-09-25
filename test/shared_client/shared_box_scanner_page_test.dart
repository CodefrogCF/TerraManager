import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_box_scanner_page.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';

void main() {
  const qrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc';

  testWidgets('invalid QR never reaches the server', (tester) async {
    var requests = 0;
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((_) async {
        requests++;
        return http.Response('{}', 404);
      }),
    );
    late Future<void> Function(String) scan;
    await tester.pumpWidget(
      MaterialApp(
        home: SharedBoxScannerPage(
          api: api,
          boxes: const [],
          animals: const [],
          change: (operation) async {
            await operation();
            return true;
          },
          onHandlerReady: (handler) => scan = handler,
        ),
      ),
    );
    await tester.pump();

    await scan('https://example.com');
    await tester.pump();

    expect(find.text('Invalid TerraManager QR code'), findsOneWidget);
    expect(requests, 0);
    api.close();
  });

  for (final status in ['missing', 'archived']) {
    testWidgets('$status Box cannot be opened from a QR scan', (tester) async {
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient((request) async {
          expect(request.url.pathSegments.last, qrId);
          if (status == 'missing') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'not_found', 'message': 'Box not found.'},
              }),
              404,
            );
          }
          return http.Response(
            jsonEncode({
              'box': {'id': 7, 'status': 'archived'},
            }),
            200,
          );
        }),
      );
      late Future<void> Function(String) scan;
      await tester.pumpWidget(
        MaterialApp(
          home: SharedBoxScannerPage(
            api: api,
            boxes: const [],
            animals: const [],
            change: (operation) async {
              await operation();
              return true;
            },
            onHandlerReady: (handler) => scan = handler,
          ),
        ),
      );
      await tester.pump();

      await scan(qrId);
      await tester.pump();

      expect(find.byType(SharedBoxDetailPage), findsNothing);
      expect(
        find.text(
          status == 'missing' ? 'Box not found' : 'This Box is archived. Restore it from Archived Boxes before using it.',
        ),
        findsOneWidget,
      );
      api.close();
    });
  }

  testWidgets('valid active QR opens server Box details', (tester) async {
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        if (request.url.pathSegments.contains('qr') ||
            request.url.path == '/api/v1/boxes/7') {
          return http.Response(
            jsonEncode({
              'box': {'id': 7, 'qrId': qrId, 'status': 'active'},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    late Future<void> Function(String) scan;
    await tester.pumpWidget(
      MaterialApp(
        home: SharedBoxScannerPage(
          api: api,
          boxes: const [],
          animals: const [],
          change: (operation) async {
            await operation();
            return true;
          },
          onHandlerReady: (handler) => scan = handler,
          stopScanner: () async {},
          startScanner: () async {},
        ),
      ),
    );
    await tester.pump();

    final scanning = scan(qrId);
    await tester.pumpAndSettle();
    expect(find.byType(SharedBoxDetailPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await scanning;
    expect(find.byType(SharedBoxScannerPage), findsOneWidget);
    api.close();
  });

  testWidgets('Feeding Mode can choose a Box without camera scanning', (
    tester,
  ) async {
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient(
        (request) async => http.Response(
          jsonEncode({
            'boxes': [
              {'id': 7, 'name': 'Main Box', 'status': 'active'},
              {'id': 8, 'name': 'Old Box', 'status': 'archived'},
            ],
          }),
          200,
        ),
      ),
    );
    int? chosenId;
    await tester.pumpWidget(
      MaterialApp(
        home: SharedBoxScannerPage(
          api: api,
          boxes: const [],
          animals: const [],
          change: (operation) async {
            await operation();
            return true;
          },
          allowBoxSelection: true,
          onBoxResolved: (_, box) async {
            chosenId = box['id'] as int;
            return false;
          },
          stopScanner: () async {},
          startScanner: () async {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('shared-scanner-choose-box')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('shared-scanner-box-7')), findsOneWidget);
    expect(find.byKey(const Key('shared-scanner-box-8')), findsNothing);
    await tester.tap(find.byKey(const Key('shared-scanner-box-7')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(chosenId, 7);
    api.close();
  });
}
