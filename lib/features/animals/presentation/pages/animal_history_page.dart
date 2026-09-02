import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums/animal_archive_reason.dart';
import '../../../../core/database/repositories/animal_repository.dart';
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

  Future<void> _openAnimalDetail(Animal animal) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AnimalDetailPage(database: widget.database, animalId: animal.id),
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
      appBar: AppBar(title: const Text('Animal History')),
      body: FutureBuilder<List<Animal>>(
        future: _animalsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load animal history'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final animals = snapshot.data ?? [];

          if (animals.isEmpty) {
            return const Center(
              key: Key('animal-history-empty-state'),
              child: Text('No archived animals'),
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
                    Text(_archiveSummary(animal)),
                  ],
                ),
                isThreeLine: true,
                onTap: () {
                  _openAnimalDetail(animal);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _archiveSummary(Animal animal) {
    final parts = <String>[];

    if (animal.archiveReason != null) {
      parts.add(_archiveReasonLabel(animal.archiveReason!));
    }

    if (animal.archivedAt != null) {
      parts.add(_formatDate(animal.archivedAt!));
    }

    return parts.isEmpty ? 'Archived' : parts.join(' • ');
  }
}

String _archiveReasonLabel(AnimalArchiveReason reason) {
  switch (reason) {
    case AnimalArchiveReason.sold:
      return 'Sold';
    case AnimalArchiveReason.traded:
      return 'Traded';
    case AnimalArchiveReason.deceased:
      return 'Deceased';
    case AnimalArchiveReason.rehomed:
      return 'Rehomed';
    case AnimalArchiveReason.other:
      return 'Other';
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}
