import 'package:flutter/material.dart';

import '../../../../core/boxes/box_label.dart';
import '../../../../core/database/app_database.dart';
import '../widgets/quick_feeding_form.dart';

class FeedingBoxAnimalsPage extends StatelessWidget {
  final AppDatabase database;
  final Box box;
  final List<Animal> animals;
  final DateTime? initialFedAt;

  FeedingBoxAnimalsPage({
    super.key,
    required this.database,
    required this.box,
    required Iterable<Animal> animals,
    this.initialFedAt,
  }) : animals = List<Animal>.unmodifiable(animals);

  @override
  Widget build(BuildContext context) {
    final boxLabel = buildBoxLabel(box.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Feeding – $boxLabel', key: const Key('feeding-box-title')),
      ),
      body: animals.isEmpty
          ? _EmptyAnimalList(
              boxLabel: boxLabel,
              onScanAnother: () {
                Navigator.of(context).pop(false);
              },
            )
          : QuickFeedingForm(
              database: database,
              boxLabel: boxLabel,
              animals: animals,
              initialFedAt: initialFedAt,
              onSaved: () {
                Navigator.of(context).pop(true);
              },
              onCancel: () {
                Navigator.of(context).pop(false);
              },
            ),
    );
  }
}

class _EmptyAnimalList extends StatelessWidget {
  final String boxLabel;
  final VoidCallback onScanAnother;

  const _EmptyAnimalList({required this.boxLabel, required this.onScanAnother});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pets_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'No active animals assigned to $boxLabel',
                    key: const Key('feeding-box-empty-message'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Return to the scanner and scan another Box.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('scan-another-box-button'),
                onPressed: onScanAnother,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan another Box'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
