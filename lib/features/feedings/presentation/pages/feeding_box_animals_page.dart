import 'package:flutter/material.dart';

import '../../../../core/boxes/box_label.dart';
import '../../../../core/database/app_database.dart';

class FeedingBoxAnimalsPage extends StatelessWidget {
  final Box box;
  final List<Animal> animals;

  FeedingBoxAnimalsPage({
    super.key,
    required this.box,
    required Iterable<Animal> animals,
  }) : animals = List<Animal>.unmodifiable(animals);

  @override
  Widget build(BuildContext context) {
    final boxLabel = buildBoxLabel(box.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Feeding – $boxLabel', key: const Key('feeding-box-title')),
      ),
      body: Column(
        children: [
          Expanded(
            child: animals.isEmpty
                ? _EmptyAnimalList(boxLabel: boxLabel)
                : _AnimalList(boxLabel: boxLabel, animals: animals),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('scan-another-box-button'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan another Box'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAnimalList extends StatelessWidget {
  final String boxLabel;

  const _EmptyAnimalList({required this.boxLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

class _AnimalList extends StatelessWidget {
  final String boxLabel;
  final List<Animal> animals;

  const _AnimalList({required this.boxLabel, required this.animals});

  @override
  Widget build(BuildContext context) {
    final animalLabel = animals.length == 1 ? 'animal' : 'animals';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${animals.length} active $animalLabel assigned to $boxLabel',
            key: const Key('feeding-box-animal-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: animals.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final animal = animals[index];

              return ListTile(
                key: Key('feeding-mode-animal-${animal.id}'),
                leading: const Icon(Icons.pets_outlined),
                title: Text(animal.commonName),
                subtitle: Text(animal.latinName),
              );
            },
          ),
        ),
      ],
    );
  }
}
