import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_box_scanner_page.dart';
import 'package:terramanager/shared_client/shared_forms.dart';

void main() {
  const firstBox = {'id': 1, 'status': 'active', 'name': 'First'};
  const secondBox = {'id': 2, 'status': 'active', 'name': 'Second'};
  final animal = <String, dynamic>{
    'id': 9,
    'status': 'active',
    'revision': 'opened-revision',
    'boxId': 1,
    'commonName': 'Animal',
    'latinName': 'Example species',
    'category': 'reptile',
    'tempMin': 22,
    'tempMax': 28,
    'humidityMin': 40,
    'humidityMax': 60,
    'showWeightOnDetail': true,
    'showSheddingOnDetail': true,
  };

  Future<SharedApiClient> clientWith(
    Future<http.Response> Function(http.Request request) onMove,
  ) async {
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'user': {'username': 'hagen', 'role': 'caregiver'},
              'csrfToken': 'csrf-secret',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/animals/9/move') {
          return onMove(request);
        }
        return http.Response('{}', 404);
      }),
    );
    await api.login('hagen', 'password');
    return api;
  }

  testWidgets('unsaved edits require confirmation before scanning', (
    tester,
  ) async {
    final api = await clientWith((_) async => http.Response('{}', 500));
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SharedAnimalForm(
          api: api,
          boxes: const [firstBox, secondBox],
          initial: animal,
          change: (_) async => true,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Edited');
    await tester.tap(find.byKey(const Key('shared-rehouse-scan-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.byType(SharedBoxScannerPage), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byType(SharedBoxScannerPage), findsNothing);
  });

  testWidgets('confirmed QR reassignment uses the opened revision', (
    tester,
  ) async {
    http.Request? moveRequest;
    final api = await clientWith((request) async {
      moveRequest = request;
      return http.Response(
        jsonEncode({
          'animal': {...animal, 'boxId': 2, 'revision': 'new-revision'},
        }),
        200,
      );
    });
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SharedAnimalForm(
          api: api,
          boxes: const [firstBox, secondBox],
          initial: animal,
          change: (operation) async {
            await operation();
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('shared-rehouse-scan-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final scanner = tester.widget<SharedBoxScannerPage>(
      find.byType(SharedBoxScannerPage),
    );
    final scannerContext = tester.element(find.byType(SharedBoxScannerPage));
    final moving = scanner.onBoxResolved!(scannerContext, secondBox);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byKey(const Key('shared-rehouse-confirmation')),
      findsOneWidget,
    );
    expect(moveRequest, isNull);
    await tester.tap(find.byKey(const Key('shared-rehouse-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await moving;
    expect(moveRequest, isNotNull);
    expect(jsonDecode(moveRequest!.body), {
      'boxId': 2,
      'expectedRevision': 'opened-revision',
    });
  });
}
