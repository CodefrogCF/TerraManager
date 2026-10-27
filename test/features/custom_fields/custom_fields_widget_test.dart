import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';
import 'package:terramanager/features/custom_fields/presentation/standalone_custom_fields.dart';
import 'package:terramanager/shared_client/custom_fields/presentation/shared_custom_fields.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_server/custom_fields/application/custom_field_operations.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  for (final mode in ['standalone', 'shared']) {
    for (final lang in ['de', 'en']) {
      testWidgets(
        '$mode $lang typed entries validate on narrow scaled screens and preserve hidden/archive data',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final db = AppDatabase.test(NativeDatabase.memory());
          addTearDown(db.close);
          final repo = CustomFieldRepository(db);
          final box = await BoxRepository(db).createBoxWithGeneratedQrId();
          for (final kind in CustomFieldType.values) {
            await repo.create(
              CustomFieldTemplate(
                id: '${kind.index + 1}2345678-1234-4123-8123-123456789abc',
                target: CustomFieldTarget.box,
                type: kind,
                label: kind.name,
              ),
            );
          }
          SharedApiClient? api;
          if (mode == 'shared') {
            final ops = CustomFieldOperations(db);
            api = SharedApiClient(
              Uri.parse('https://test.local'),
              MockClient((request) async {
                final reply = request.url.path.endsWith('custom-fields')
                    ? await ops.snapshot(CustomFieldTarget.box, box)
                    : await ops.list();
                return http.Response(jsonEncode(reply.body), reply.status);
              }),
            );
            addTearDown(api.close);
          }
          final access = api == null
              ? standaloneCustomFields(db, CustomFieldTarget.box, box)
              : sharedCustomFields(api, CustomFieldTarget.box, box);
          final controller = CustomFieldsController(access);
          addTearDown(controller.dispose);
          await controller.load();
          final form = GlobalKey<FormState>();
          bool valid = false;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: Scaffold(
                body: Form(
                  key: form,
                  child: ListView(
                    children: [
                      CustomFieldsEditor(controller: controller),
                      FilledButton(
                        key: const Key('validate'),
                        onPressed: () {
                          valid = form.currentState!.validate();
                        },
                        child: const Text('Check'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          Future<void> enter(String id, String value) async {
            final f = find.byKey(ValueKey('custom-field-$id'));
            await tester.ensureVisible(f);
            await tester.pumpAndSettle();
            await tester.enterText(f, value);
          }

          const number = '22345678-1234-4123-8123-123456789abc',
              date = '32345678-1234-4123-8123-123456789abc',
              boolean = '42345678-1234-4123-8123-123456789abc';
          await enter(number, 'NaN');
          await enter(date, '2023-02-29');
          await tester.ensureVisible(find.byKey(const Key('validate')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('validate')));
          await tester.pumpAndSettle();
          expect(valid, false);
          await enter(number, '0,0');
          await enter(date, '2024-02-29');
          final booleanFinder = find.byKey(
            const ValueKey('custom-field-$boolean'),
          );
          await tester.ensureVisible(booleanFinder);
          await tester.pumpAndSettle();
          await tester.tap(booleanFinder);
          await tester.pumpAndSettle();
          await tester.tap(find.text(lang == 'de' ? 'Nein' : 'No').last);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('validate')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('validate')));
          await tester.pumpAndSettle();
          expect(valid, true);
          expect(controller.dirty, true);
          await repo.save(CustomFieldTarget.box, box, controller.patch!);
          await controller.load();
          await tester.pumpAndSettle();
          expect(controller.dirty, false);
          final t = (await repo.templates()).firstWhere((t) => t.id == number);
          await repo.update(
            CustomFieldTemplate(
              id: t.id,
              target: t.target,
              type: t.type,
              label: 'Number renamed',
              archived: true,
              revision: t.revision,
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CustomFieldsSection(access: access),
                ),
              ),
            ),
          );
          await db.customSelect('SELECT 1').get();
          await tester.pumpAndSettle();
          expect(find.textContaining('Number renamed'), findsOneWidget);
          expect(find.text('0'), findsOneWidget);
          expect(find.text(lang == 'de' ? 'Nein' : 'No'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'template dialog retains invalid draft, creates stable definition and edits visibility',
    (tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      addTearDown(db.close);
      final access = standaloneCustomFields(db, CustomFieldTarget.animal);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomFieldTemplatesPage(access: access),
        ),
      );
      await db.customSelect('SELECT 1').get();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-field-template')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-field-template')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('field-template-label')),
        'Species-specific data',
      );
      await tester.tap(find.byKey(const Key('save-field-template')));
      await db.customSelect('SELECT 1').get();
      await tester.pumpAndSettle();
      final t = (await CustomFieldRepository(db).templates()).single;
      expect(t.target, CustomFieldTarget.animal);
      expect(CustomFieldTemplate.validId(t.id), true);
      await tester.tap(find.byKey(ValueKey('field-template-${t.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('field-template-label')),
        'Renamed',
      );
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-field-template')));
      await db.customSelect('SELECT 1').get();
      await tester.pumpAndSettle();
      final renamed = (await CustomFieldRepository(db).templates()).single;
      expect(renamed.id, t.id);
      expect(renamed.hidden, true);
      expect(renamed.label, 'Renamed');
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'whole numeric JSON values do not mark an untouched form dirty',
    () async {
      const id = '12345678-1234-4123-8123-123456789abc';
      const template = CustomFieldTemplate(
        id: id,
        target: CustomFieldTarget.animal,
        type: CustomFieldType.number,
        label: 'Number',
      );
      final controller = CustomFieldsController(
        CustomFieldAccess(
          target: CustomFieldTarget.animal,
          load: () async => const CustomFieldsSnapshot(
            templates: [template],
            values: [CustomFieldValue(id, 1)],
            revision: 'snapshot',
          ),
          templates: () async => const [template],
          saveTemplate: (_, {required creating}) async {},
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.dirty, false);
      expect(controller.patch, isNull);
      controller.fields[id]!.text = '1.0';
      expect(controller.dirty, false);
      controller.fields[id]!.text = '2';
      expect(controller.patch!.updates.single.value, 2.0);
      expect(sameFieldValue(0, 0.0), true);
      expect(sameFieldValue(false, 0), false);
    },
  );
}
