import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';
import 'package:terramanager/features/media/presentation/widgets/picture_selection_controls.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_form.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_form.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

import '../features/media/presentation/fake_picture_selection_flow.dart';

class _Fixture {
  _Fixture(
    this.kind, {
    this.rejectFirstUpload = false,
    this.loseFirstReply = false,
  });
  final String kind;
  final bool rejectFirstUpload;
  final bool loseFirstReply;
  late SharedApiClient api;
  int creates = 0;
  int uploads = 0;
  bool? result;
  Map<String, dynamic>? record;
  final pictures = <String, Map<String, dynamic>>{};
  final uploadKeys = <String?>[];
  final bodies = <Map<String, dynamic>>[];
  String get singular => kind == 'animals' ? 'animal' : 'box';
  String get saveKey => 'shared-save-$singular';

  Future<void> initialize() async {
    api = SharedApiClient(
      Uri.parse('https://localhost'),
      MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/custom-field-templates') {
          return http.Response(jsonEncode({'templates': []}), 200);
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/custom-fields')) {
          return http.Response(
            jsonEncode({
              'templates': [],
              'values': [],
              'active': true,
              'revision': 'custom-fields',
            }),
            200,
          );
        }

        final path = request.url.path;
        if (path.startsWith('/api/v1/auth/')) {
          return _json({
            'user': {'id': 1, 'username': 'caregiver', 'role': 'caregiver'},
            'csrfToken': 'csrf',
          });
        }
        if (request.method == 'POST' && path == '/api/v1/$kind') {
          creates++;
          record = {
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'id': 7,
            'revision': 'created',
            'status': 'active',
          };
          return _json({singular: record}, 201);
        }
        if (request.method == 'POST' && path == '/api/v1/$kind/7/pictures') {
          uploads++;
          final key = request.headers['Idempotency-Key'];
          uploadKeys.add(key);
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (rejectFirstUpload && uploads == 1) {
            return _json({
              'error': {'code': 'media_storage_limit', 'message': 'Full'},
            }, 507);
          }
          final picture = pictures.putIfAbsent(
            key!,
            () => {'id': 1, 'mediaId': 41, 'isPrimary': true},
          );
          record!['pictureMediaId'] = 41;
          if (loseFirstReply && uploads == 1) {
            throw http.ClientException('Reply lost after commit');
          }
          return _json({'picture': picture}, 201);
        }
        if (path == '/api/v1/$kind/7') return _json({singular: record});
        if (path == '/api/v1/$kind/7/pictures') {
          return _json({'pictures': pictures.values.toList()});
        }
        if (path == '/api/v1/media/41') {
          return http.Response.bytes(normalizedTestPictureBytes, 200);
        }
        throw StateError('Unexpected request: ${request.method} $path');
      }),
    );
    await api.login('caregiver', 'password');
  }

  static http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  Future<void> open(
    WidgetTester tester,
    FakePictureSelectionFlow flow, {
    String language = 'en',
    bool edit = false,
  }) async {
    Future<bool> change(Future<void> Function() operation) async {
      try {
        await operation();
        return true;
      } catch (_) {
        return false;
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => kind == 'animals'
                        ? SharedAnimalForm(
                            api: api,
                            boxes: const [
                              {'id': 1, 'name': 'Box', 'status': 'active'},
                            ],
                            change: change,
                            pictureSelectionFlow: flow,
                            initial: edit
                                ? {
                                    'id': 7,
                                    'boxId': 1,
                                    'revision': 'r',
                                    'commonName': 'Animal',
                                    'latinName': 'Species',
                                  }
                                : null,
                          )
                        : SharedBoxForm(
                            api: api,
                            change: change,
                            pictureSelectionFlow: flow,
                            initial: edit
                                ? {'id': 7, 'revision': 'r', 'name': 'Box'}
                                : null,
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, {String language = 'en'}) async {
    final label = kind == 'animals'
        ? (language == 'en' ? 'Common name' : 'Trivialname')
        : 'Name';
    Finder field(String label) => find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), 'Created profile');
    if (kind == 'animals') {
      final latin = field(
        language == 'en' ? 'Latin name' : 'Lateinischer Name',
      );
      await tester.ensureVisible(latin);
      await tester.enterText(latin, 'Test species');
    }
  }

  Future<void> select(WidgetTester tester, {bool camera = false}) async {
    final button = find.byKey(const Key('shared-creation-picture-select'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        camera
            ? PictureSelectionControls.cameraOptionKey
            : PictureSelectionControls.galleryOptionKey,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final button = find.byKey(Key(saveKey));
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final kind in ['boxes', 'animals']) {
    Future<_Fixture> fixture({bool reject = false, bool lose = false}) async {
      final value = _Fixture(
        kind,
        rejectFirstUpload: reject,
        loseFirstReply: lose,
      );
      await value.initialize();
      addTearDown(value.api.close);
      return value;
    }

    testWidgets('$kind can be created without a picture', (tester) async {
      final f = await fixture();
      await f.open(tester, FakePictureSelectionFlow());
      await f.fill(tester);
      await f.save(tester);
      expect(f.result, isTrue);
      expect(f.creates, 1);
      expect(f.uploads, 0);
    });

    for (final language in ['en', 'de']) {
      testWidgets('$kind previews and uploads a selected picture ($language)', (
        tester,
      ) async {
        final f = await fixture();
        final flow = FakePictureSelectionFlow(
          result: normalizedTestPicture('profile.webp'),
        );
        await f.open(tester, flow, language: language);
        await f.select(tester, camera: language == 'de');
        expect(
          find.byKey(const Key('shared-creation-picture-preview')),
          findsOneWidget,
        );
        expect(f.creates, 0);
        expect(f.uploads, 0);
        expect(flow.selectedSources, [
          language == 'de' ? ImageSource.camera : ImageSource.gallery,
        ]);
        await f.fill(tester, language: language);
        await f.save(tester);
        expect(f.result, isTrue);
        expect(f.creates, 1);
        expect(f.uploads, 1);
        expect(f.bodies.single['fileName'], 'profile.webp');
        expect(f.bodies.single['mimeType'], 'image/webp');
        expect(
          base64Decode(f.bodies.single['dataBase64'] as String),
          orderedEquals(normalizedTestPictureBytes),
        );
        final stored = kind == 'animals'
            ? await f.api.animal(7)
            : await f.api.box(7);
        expect(stored['pictureMediaId'], 41);
        expect(await f.api.pictures(kind, 7), hasLength(1));
        expect(
          await f.api.mediaBytes(41),
          orderedEquals(normalizedTestPictureBytes),
        );
      });
    }

    testWidgets('$kind cancelled selection remains optional', (tester) async {
      final f = await fixture();
      await f.open(tester, FakePictureSelectionFlow(result: null));
      await f.select(tester);
      expect(
        find.byKey(const Key('shared-creation-picture-preview')),
        findsNothing,
      );
      expect(f.creates, 0);
      await f.fill(tester);
      await f.save(tester);
      expect(f.result, isTrue);
      expect(f.uploads, 0);
    });

    for (final uncertain in [false, true]) {
      testWidgets(
        '$kind retries only the picture after ${uncertain ? 'a lost reply' : 'a rejection'}',
        (tester) async {
          final f = await fixture(reject: !uncertain, lose: uncertain);
          await f.open(
            tester,
            FakePictureSelectionFlow(
              result: normalizedTestPicture('profile.webp'),
            ),
          );
          await f.select(tester);
          await f.fill(tester);
          await f.save(tester);
          expect(f.result, isNull);
          expect(f.creates, 1);
          expect(f.uploads, 1);
          expect(
            find.textContaining('was created, but its picture'),
            findsOneWidget,
          );
          if (uncertain) {
            await f.api.restoreSession();
            await tester.pumpAndSettle();
          }
          await f.save(tester);
          expect(f.result, isTrue);
          expect(f.creates, 1);
          expect(f.uploads, 2);
          expect(f.uploadKeys.first, isNotEmpty);
          expect(f.uploadKeys.last, f.uploadKeys.first);
          expect(f.pictures, hasLength(1));
        },
      );
    }

    testWidgets(
      '$kind can finish after picture failure without recreating it',
      (tester) async {
        final f = await fixture(reject: true);
        await f.open(
          tester,
          FakePictureSelectionFlow(
            result: normalizedTestPicture('profile.webp'),
          ),
        );
        await f.select(tester);
        await f.fill(tester);
        await f.save(tester);
        if (kind == 'boxes') {
          await tester.ensureVisible(
            find.byKey(const Key('shared-creation-finish')),
          );
          await tester.tap(find.byKey(const Key('shared-creation-finish')));
        } else {
          await tester.pageBack();
        }
        await tester.pumpAndSettle();
        expect(f.result, isTrue);
        expect(f.creates, 1);
        expect(f.uploads, 1);
      },
    );

    testWidgets('$kind selection failure does not create an entity', (
      tester,
    ) async {
      final f = await fixture();
      await f.open(
        tester,
        FakePictureSelectionFlow(error: StateError('Picker failed')),
      );
      await f.select(tester);
      final labels = AppLocalizations.of(
        tester.element(find.byKey(const Key('shared-creation-picture-select'))),
      )!;
      expect(find.text(labels.failedToSelectPicture), findsOneWidget);
      expect(f.creates, 0);
      await f.fill(tester);
      await f.save(tester);
      expect(f.result, isTrue);
      expect(f.uploads, 0);
    });

    testWidgets('$kind editing keeps the existing gallery workflow', (
      tester,
    ) async {
      final f = await fixture();
      await f.open(tester, FakePictureSelectionFlow(), edit: true);
      expect(
        find.byKey(const Key('shared-creation-picture-select')),
        findsNothing,
      );
    });

    testWidgets('$kind cannot save while a picture is being processed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = await fixture();
      final selected = Completer<SelectedPicture?>();
      await f.open(
        tester,
        FakePictureSelectionFlow(pendingResult: selected.future),
      );
      await f.fill(tester);
      await tester.tap(find.byKey(const Key('shared-creation-picture-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<FilledButton>(find.byKey(Key(f.saveKey))).onPressed,
        isNull,
      );
      expect(f.creates, 0);
      selected.complete(null);
      await tester.pumpAndSettle();
      await f.save(tester);
      expect(f.result, isTrue);
    });
  }
}
