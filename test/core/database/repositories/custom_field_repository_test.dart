import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';

void main() {
  const id = '12345678-1234-4123-8123-123456789abc';
  late AppDatabase db;
  late CustomFieldRepository repo;
  late int box;
  setUp(() async {
    db = AppDatabase.test(NativeDatabase.memory());
    repo = CustomFieldRepository(db);
    box = await BoxRepository(db).createBoxWithGeneratedQrId();
  });
  tearDown(() async {
    await db.close();
  });
  CustomFieldTemplate template(
    CustomFieldType kind, {
    CustomFieldTarget target = CustomFieldTarget.box,
  }) => CustomFieldTemplate(
    id: id,
    target: target,
    type: kind,
    label: 'Test field',
  );
  CustomFieldPatch patch(CustomFieldsSnapshot state, Object? value) =>
      CustomFieldPatch(
        expectedRevision: state.revision,
        updates: [
          (
            id: id,
            templateRevision: state.templates.single.revision,
            value: value,
          ),
        ],
      );
  for (final kind in CustomFieldType.values) {
    test(
      '${kind.name} validates, saves and clears without erasing metadata',
      () async {
        final t = await repo.create(template(kind));
        final value = switch (kind) {
          CustomFieldType.text => ' Multiline\nÜmlaut ',
          CustomFieldType.number => 0.0,
          CustomFieldType.date => '2024-02-29',
          CustomFieldType.boolean => false,
        };
        await repo.save(
          CustomFieldTarget.box,
          box,
          patch(await repo.snapshot(CustomFieldTarget.box, box), value),
        );
        final state = await repo.snapshot(CustomFieldTarget.box, box);
        expect(state.value(id), value);
        final renamed = await repo.update(
          CustomFieldTemplate(
            id: id,
            target: t.target,
            type: t.type,
            label: 'Renamed',
            hidden: true,
            revision: t.revision,
          ),
        );
        expect(
          (await repo.snapshot(CustomFieldTarget.box, box)).value(id),
          value,
        );
        await expectLater(
          repo.save(CustomFieldTarget.box, box, patch(state, null)),
          throwsA(isA<CustomFieldConflict>()),
        );
        final archived = await repo.update(
          CustomFieldTemplate(
            id: id,
            target: t.target,
            type: t.type,
            label: renamed.label,
            archived: true,
            revision: renamed.revision,
          ),
        );
        expect(
          (await repo.snapshot(CustomFieldTarget.box, box)).value(id),
          value,
        );
        await expectLater(
          repo.save(
            CustomFieldTarget.box,
            box,
            patch(await repo.snapshot(CustomFieldTarget.box, box), null),
          ),
          throwsA(isA<CustomFieldConflict>()),
        );
        await repo.update(
          CustomFieldTemplate(
            id: id,
            target: t.target,
            type: t.type,
            label: archived.label,
            revision: archived.revision,
          ),
        );
        await repo.save(
          CustomFieldTarget.box,
          box,
          patch(await repo.snapshot(CustomFieldTarget.box, box), null),
        );
        expect(
          (await repo.snapshot(CustomFieldTarget.box, box)).value(id),
          null,
        );
        expect(await repo.rows(CustomFieldTarget.box, box), hasLength(1));
      },
    );
  }
  test('rejects invalid dates, nonfinite numbers, types, labels and immutable kind changes', () async {
    for (final v in [
      '2023-02-29',
      '2026-13-01',
      '0000-01-01',
      '2026-01-01T00:00:00Z',
    ]) {
      expect(
        () => template(CustomFieldType.date).validate(v),
        throwsArgumentError,
      );
    }
    for (final v in [double.nan, double.infinity, '1', true]) {
      expect(
        () => template(CustomFieldType.number).validate(v),
        throwsArgumentError,
      );
    }
    expect(
      () => template(CustomFieldType.boolean).validate(0),
      throwsArgumentError,
    );
    final t = await repo.create(template(CustomFieldType.text));
    await expectLater(
      repo.update(
        CustomFieldTemplate(
          id: id,
          target: t.target,
          type: CustomFieldType.number,
          label: t.label,
        ),
      ),
      throwsA(isA<CustomFieldConflict>()),
    );
    for (final label in ['', '\nHidden', '\u200bInvisible', 'a' * 81]) {
      expect(
        () => CustomFieldTemplate.normalizeLabel(label),
        throwsArgumentError,
      );
    }
    await expectLater(
      repo.create(
        const CustomFieldTemplate(
          id: '22345678-1234-4123-8123-123456789abc',
          target: CustomFieldTarget.box,
          type: CustomFieldType.text,
          label: 'TEST   FIELD',
        ),
      ),
      throwsArgumentError,
    );
    await repo.create(
      const CustomFieldTemplate(
        id: '32345678-1234-4123-8123-123456789abc',
        target: CustomFieldTarget.animal,
        type: CustomFieldType.text,
        label: 'TEST FIELD',
      ),
    );
  });
  test('core and custom changes are atomic; snapshot rejects stale and cross-target batches', () async {
    await repo.create(template(CustomFieldType.number));
    final state = await repo.snapshot(CustomFieldTarget.box, box);
    await expectLater(
      BoxRepository(db)
          .updateBox(boxId: box, customFields: patch(state, 'invalid')),
      throwsArgumentError,
    );
    expect((await repo.snapshot(CustomFieldTarget.box, box)).value(id), null);
    final before = await BoxRepository(db).getAllBoxes();
    await expectLater(
      BoxRepository(db).createBoxWithGeneratedQrId(
        customFields: CustomFieldPatch(
          expectedRevision: null,
          updates: [(id: id, templateRevision: 1, value: 'invalid')],
        ),
      ),
      throwsArgumentError,
    );
    expect(await BoxRepository(db).getAllBoxes(), before);
    await repo.save(CustomFieldTarget.box, box, patch(state, 42));
    await expectLater(
      repo.save(CustomFieldTarget.box, box, patch(state, 0)),
      throwsA(isA<CustomFieldConflict>()),
    );
    final animal = await AnimalRepository(db).createAnimal(
      boxId: box,
      commonName: 'Animal',
      latinName: 'Species',
      tempMin: 20,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 60,
    );
    await expectLater(
      repo.save(
        CustomFieldTarget.animal,
        animal,
        CustomFieldPatch(
          expectedRevision: (await repo.snapshot(
            CustomFieldTarget.animal,
            animal,
          )).revision,
          updates: [(id: id, templateRevision: 1, value: 2)],
        ),
      ),
      throwsA(isA<CustomFieldConflict>()),
    );
    final duplicate = await BoxRepository(db)
        .duplicateBox(sourceBoxId: box, name: 'Copy');
    expect(
      (await repo.snapshot(CustomFieldTarget.box, duplicate)).value(id),
      42,
    );
  });
  test('Animal creation, duplicate and owner deletion preserve correct value ownership', () async {
    await repo.create(
      template(CustomFieldType.text, target: CustomFieldTarget.animal),
    );
    final animals = AnimalRepository(db);
    final animal = await animals.createAnimal(
      boxId: box,
      commonName: 'Original',
      latinName: 'Species',
      tempMin: 20,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 60,
      customFields: const CustomFieldPatch(
        expectedRevision: null,
        updates: [(id: id, templateRevision: 1, value: 'Animal data')],
      ),
    );
    final copy = await animals.duplicateAnimal(
      sourceAnimalId: animal,
      boxId: box,
      commonName: 'Copy',
    );
    expect(
      (await repo.snapshot(CustomFieldTarget.animal, copy)).value(id),
      'Animal data',
    );
    expect((await repo.snapshot(CustomFieldTarget.box, box)).values, isEmpty);
    await animals.deleteAnimal(animal);
    expect(await repo.rows(CustomFieldTarget.animal, animal), isEmpty);
    expect(
      (await repo.snapshot(CustomFieldTarget.animal, copy)).value(id),
      'Animal data',
    );
  });
}
