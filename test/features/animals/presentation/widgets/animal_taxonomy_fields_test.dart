import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/features/animals/presentation/widgets/animal_taxonomy_fields.dart';

void main() {
  testWidgets('shows compatible subcategories and clears incompatible values', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _TaxonomyHarness()));

    expect(find.byKey(const Key('animal-category-field')), findsOneWidget);
    expect(
      find.byKey(const Key('animal-subcategory-field-other')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('animal-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reptile').last);
    await tester.pumpAndSettle();

    final reptileField = find.byKey(
      const Key('animal-subcategory-field-reptile'),
    );
    expect(reptileField, findsOneWidget);
    await tester.tap(reptileField);
    await tester.pumpAndSettle();
    expect(find.text('Snake'), findsOneWidget);
    expect(find.text('Lizard'), findsOneWidget);
    expect(find.text('Turtle'), findsOneWidget);
    await tester.tap(find.text('Snake'));
    await tester.pumpAndSettle();

    final selectedReptile = tester.widget<DropdownButton<AnimalSubcategory?>>(
      find.descendant(
        of: reptileField,
        matching: find.byType(DropdownButton<AnimalSubcategory?>),
      ),
    );
    expect(selectedReptile.value, AnimalSubcategory.snake);

    await tester.tap(find.byKey(const Key('animal-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arachnid').last);
    await tester.pumpAndSettle();

    final arachnidField = find.byKey(
      const Key('animal-subcategory-field-arachnid'),
    );
    final selectedArachnid = tester.widget<DropdownButton<AnimalSubcategory?>>(
      find.descendant(
        of: arachnidField,
        matching: find.byType(DropdownButton<AnimalSubcategory?>),
      ),
    );
    expect(selectedArachnid.value, isNull);

    await tester.tap(arachnidField);
    await tester.pumpAndSettle();
    expect(find.text('Tarantula'), findsOneWidget);
    expect(find.text('Other spider'), findsOneWidget);
    expect(find.text('Jumping spider'), findsNothing);
  });
}

class _TaxonomyHarness extends StatefulWidget {
  const _TaxonomyHarness();

  @override
  State<_TaxonomyHarness> createState() => _TaxonomyHarnessState();
}

class _TaxonomyHarnessState extends State<_TaxonomyHarness> {
  AnimalCategory category = AnimalCategory.other;
  AnimalSubcategory? subcategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        child: AnimalTaxonomyFields(
          category: category,
          subcategory: subcategory,
          enabled: true,
          onChanged: (nextCategory, nextSubcategory) {
            setState(() {
              category = nextCategory;
              subcategory = nextSubcategory;
            });
          },
        ),
      ),
    );
  }
}
