import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/shared_client/animals/application/shared_animal_profile_pdf_loader.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  test('Shared Care loads the primary image, complete histories and optional gallery', () async {
    final mediaRequests = <int>[];
    final api = SharedApiClient(
      Uri.parse('https://localhost'),
      MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'user': {'username': 'carer', 'role': 'caregiver'},
              'csrfToken': 'csrf',
            }),
            200,
          );
        }
        if (path.startsWith('/api/v1/media/')) {
          final id = int.parse(path.split('/').last);
          mediaRequests.add(id);
          return http.Response.bytes(
            [id],
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        final response = switch (path) {
          '/api/v1/animals/9' => {
            'animal': {
              'id': 9,
              'status': 'active',
              'boxId': 2,
              'commonName': 'Corn snake',
              'latinName': 'Pantherophis guttatus',
              'category': 'reptile',
              'pictureMediaId': 7,
              'tempMin': 24.0,
              'tempMax': 28.0,
              'humidityMin': 40.0,
              'humidityMax': 60.0,
            },
          },
          '/api/v1/animals/9/pictures' => {
            'pictures': [
              {
                'mediaId': 7,
                'isPrimary': true,
                'capturedAt': '2026-10-02T12:00:00Z',
              },
              {
                'mediaId': 9,
                'isPrimary': false,
                'capturedAt': '2026-10-03T12:00:00Z',
              },
              {
                'mediaId': 8,
                'isPrimary': false,
                'capturedAt': '2026-10-01T12:00:00Z',
              },
            ],
          },
          '/api/v1/animals/9/feedings' => {
            'feedings': [
              {'fedAt': '2026-10-01T17:00:00Z', 'notes': 'Mouse'},
            ],
          },
          '/api/v1/animals/9/shedding' => {
            'shedding': [
              {'shedAt': '2026-09-01T17:00:00Z', 'notes': 'Complete'},
            ],
          },
          '/api/v1/animals/9/weights' => {
            'weights': [
              {'measuredAt': '2026-09-02T17:00:00Z', 'weightGrams': 123.5},
            ],
          },
          _ => throw StateError('Unexpected request: $path'),
        };
        return http.Response(jsonEncode(response), 200);
      }),
    );
    addTearDown(api.close);
    await api.login('carer', 'password');
    final loader = SharedAnimalProfilePdfLoader(api);
    final l10n = lookupAppLocalizations(const Locale('de'));
    final boxes = <Map<String, dynamic>>[
      {'id': 2, 'name': 'Waldterrarium'},
    ];

    final withoutGallery = await loader.load(
      9,
      l10n,
      boxes,
      includeGallery: false,
    );
    expect(withoutGallery.primaryPicture, [7]);
    expect(withoutGallery.galleryPictures, isEmpty);
    expect(withoutGallery.feedings.single.notes, 'Mouse');
    expect(withoutGallery.shedding.single.notes, 'Complete');
    expect(withoutGallery.weights.single.value, '123,5 g');
    expect(
      withoutGallery.fields.map((field) => field.value),
      contains('Waldterrarium · Box 2'),
    );
    expect(mediaRequests, [7]);

    final withGallery = await loader.load(9, l10n, boxes, includeGallery: true);
    expect(withGallery.galleryPictures.map((bytes) => bytes.single), [8, 7, 9]);
    expect(mediaRequests, [7, 7, 8, 9]);
  });
}
