import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import 'animal_detail_page.dart';

class AnimalHistoryPage extends StatefulWidget {
  final AppDatabase database;

  const AnimalHistoryPage({super.key, required this.database});

  @override
  State<AnimalHistoryPage> createState() => _AnimalHistoryPageState();
}

class _AnimalHistoryPageState extends State<AnimalHistoryPage> {
  late Future<List<Animal>> _animalsFuture;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  void _loadAnimals() {
    _animalsFuture = AnimalRepository(widget.database).getArchivedAnimals();
  }

  Future<void> _openAnimalDetail(Animal animal, List<Animal> animals) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnimalDetailPage(
          database: widget.database,
          animalId: animal.id,
          navigationContext: DetailNavigationContext.archivedAnimals(
            animalIds: animals.map((animal) => animal.id),
            currentAnimalId: animal.id,
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadAnimals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.animalHistory)),
      body: FutureBuilder<List<Animal>>(
        future: _animalsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.failedToLoadAnimalHistory));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final animals = snapshot.data ?? [];

          if (animals.isEmpty) {
            return Center(
              key: const Key('animal-history-empty-state'),
              child: Text(context.l10n.noArchivedAnimals),
            );
          }

          return ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];

              return ListTile(
                key: Key('archived-animal-list-item-${animal.id}'),
                leading: const Icon(Icons.history),
                title: Text(animal.commonName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.latinName),
                    const SizedBox(height: 4),
                    Text(_archiveSummary(context, animal)),
                  ],
                ),
                isThreeLine: true,
                onTap: () {
                  _openAnimalDetail(animal, animals);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _archiveSummary(BuildContext context, Animal animal) {
    final parts = <String>[];

    if (animal.archiveReason != null) {
      parts.add(context.l10n.animalArchiveReasonLabel(animal.archiveReason!));
    }

    if (animal.archivedAt != null) {
      parts.add(_formatDate(animal.archivedAt!));
    }

    return parts.isEmpty ? context.l10n.archived : parts.join(' • ');
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}
