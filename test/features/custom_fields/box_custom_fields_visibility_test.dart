import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';
import 'package:terramanager/features/custom_fields/presentation/standalone_custom_fields.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/custom_fields/presentation/shared_custom_fields.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_server/custom_fields/application/custom_field_operations.dart';

Widget localized(Widget child, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final target in [CustomFieldTarget.animal, CustomFieldTarget.box]) {
    for (final shared in [false, true]) {
      for (final language in ['de', 'en']) {
        testWidgets(
          '${shared ? 'Shared Care' : 'Standalone'} $language ${target.name} details show only populated fields and keep management in editing',
          (tester) async {
            final db = AppDatabase.test(NativeDatabase.memory());
            addTearDown(db.close);
            final repo = CustomFieldRepository(db);
            final box = await BoxRepository(db).createBoxWithGeneratedQrId();
            final id = target == CustomFieldTarget.box
                ? box
                : await AnimalRepository(db).createAnimal(
                    boxId: box,
                    commonName: 'Test Animal',
                    latinName: 'Test species',
                    tempMin: 22,
                    tempMax: 28,
                    humidityMin: 40,
                    humidityMax: 60,
                  );
            final ops = CustomFieldOperations(db);
            final api = shared
                ? SharedApiClient(
                    Uri.parse('https://test.local'),
                    MockClient((request) async {
                      final reply = request.url.path.endsWith('custom-fields')
                          ? await ops.snapshot(target, id)
                          : await ops.list();
                      return http.Response(
                        jsonEncode(reply.body),
                        reply.status,
                      );
                    }),
                  )
                : null;
            if (api != null) addTearDown(api.close);
            final access = api == null
                ? standaloneCustomFields(db, target, id)
                : sharedCustomFields(api, target, id);
            final l10n = await AppLocalizations.delegate.load(Locale(language));
            final key = GlobalKey<CustomFieldsSectionState>();
            await tester.pumpWidget(
              localized(
                CustomFieldsSection(key: key, access: access),
                language: language,
              ),
            );
            await db.customSelect('SELECT 1').get();
            await tester.pumpAndSettle();

            void expectEmptyDetails() {
              expect(find.text(l10n.customFields), findsNothing);
              expect(find.text(l10n.customFieldsEmpty), findsNothing);
              expect(find.text(l10n.customFieldsManage), findsNothing);
              expect(tester.getSize(find.byKey(key)).height, 0);
            }

            Future<void> reload() async {
              await key.currentState!.reload();
              await tester.pumpAndSettle();
            }

            expectEmptyDetails();
            final number = CustomFieldTemplate(
              id: '12345678-1234-4123-8123-123456789abc',
              target: target,
              type: CustomFieldType.number,
              label: 'Number',
            );
            final boolean = CustomFieldTemplate(
              id: '22345678-1234-4123-8123-123456789abc',
              target: target,
              type: CustomFieldType.boolean,
              label: 'Flag',
            );
            final internal = CustomFieldTemplate(
              id: '32345678-1234-4123-8123-123456789abc',
              target: target,
              type: CustomFieldType.text,
              label: 'Internal',
            );
            final unfilled = CustomFieldTemplate(
              id: '42345678-1234-4123-8123-123456789abc',
              target: target,
              type: CustomFieldType.text,
              label: 'Unfilled',
            );
            for (final template in [number, boolean, internal, unfilled]) {
              await repo.create(template);
            }
            await reload();
            expectEmptyDetails();

            Future<void> save(Map<String, Object?> values) async {
              final snapshot = await repo.snapshot(target, id);
              await repo.save(
                target,
                id,
                CustomFieldPatch(
                  expectedRevision: snapshot.revision,
                  updates: [
                    for (final entry in values.entries)
                      (
                        id: entry.key,
                        templateRevision: snapshot.templates
                            .singleWhere((t) => t.id == entry.key)
                            .revision,
                        value: entry.value,
                      ),
                  ],
                ),
              );
            }

            await save({internal.id: 'Preserved hidden value'});
            await repo.update(
              CustomFieldTemplate(
                id: internal.id,
                target: internal.target,
                type: internal.type,
                label: internal.label,
                hidden: true,
                revision: internal.revision,
              ),
            );
            await reload();
            expectEmptyDetails();
            await save({number.id: 0, boolean.id: false});
            await reload();
            expect(find.text(l10n.customFields), findsOneWidget);
            expect(find.text('Number'), findsOneWidget);
            expect(find.text('0'), findsOneWidget);
            expect(find.text(l10n.customFieldNo), findsOneWidget);
            expect(find.text('Internal'), findsNothing);
            expect(find.text('Unfilled'), findsNothing);
            expect(find.text(l10n.customFieldsManage), findsNothing);
            await save({number.id: null, boolean.id: null});
            await reload();
            expectEmptyDetails();
            expect(
              (await repo.snapshot(target, id)).value(internal.id),
              'Preserved hidden value',
            );

            final controller = CustomFieldsController(access);
            addTearDown(controller.dispose);
            await controller.load();
            await tester.pumpWidget(
              localized(
                CustomFieldsEditor(controller: controller),
                language: language,
              ),
            );
            await tester.pumpAndSettle();
            final manage = find.byKey(const Key('manage-custom-fields'));
            await tester.ensureVisible(manage);
            await tester.pumpAndSettle();
            await tester.tap(manage);
            await db.customSelect('SELECT 1').get();
            await tester.pumpAndSettle();
            expect(find.byType(CustomFieldTemplatesPage), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      '${target.name} detail load failures remain visible and can be retried',
      (tester) async {
        var fail = true;
        final access = CustomFieldAccess(
          target: target,
          load: () async {
            if (fail) throw StateError('Temporarily unavailable');
            return const CustomFieldsSnapshot(templates: [], values: []);
          },
          templates: () async => [],
          saveTemplate: (_, {required creating}) async {},
        );
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.pumpWidget(localized(CustomFieldsSection(access: access)));
        await tester.pumpAndSettle();
        expect(find.text(l10n.customFieldsFailure), findsOneWidget);
        expect(find.text(l10n.customFieldsManage), findsNothing);
        fail = false;
        await tester.tap(find.text(l10n.customFieldsReload));
        await tester.pumpAndSettle();
        expect(find.text(l10n.customFields), findsNothing);
        expect(find.text(l10n.customFieldsFailure), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
