import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import 'animal_detail_page.dart';
import 'animal_history_page.dart';
import 'new_animal_page.dart';

class AnimalsPage extends StatefulWidget {
  final AppDatabase database;

  const AnimalsPage({super.key, required this.database});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  late Future<List<Animal>> _animalsFuture;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  void _loadAnimals() {
    _animalsFuture = AnimalRepository(widget.database).getActiveAnimals();
  }

  Future<void> _openNewAnimalPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewAnimalPage(database: widget.database),
      ),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      setState(() {
        _loadAnimals();
      });
    }
  }

  Future<void> _openAnimalDetail(Animal animal) async {
    await Navigator.of(context).push(
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

  Future<void> _openAnimalHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalHistoryPage(database: widget.database),
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
      appBar: AppBar(
        title: const Text('Animals'),
        actions: [
          IconButton(
            key: const Key('animal-history-button'),
            onPressed: _openAnimalHistory,
            icon: const Icon(Icons.history),
            tooltip: 'Animal History',
          ),
        ],
      ),
      body: FutureBuilder<List<Animal>>(
        future: _animalsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load animals'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final animals = snapshot.data ?? [];

          if (animals.isEmpty) {
            return const Center(child: Text('No animals available'));
          }

          return ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];

              return ListTile(
                key: Key('animal-list-item-${animal.id}'),
                leading: const Icon(Icons.emoji_nature_outlined),
                title: Text(animal.commonName),
                subtitle: Text(animal.latinName),
                onTap: () {
                  _openAnimalDetail(animal);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-animal-button'),
        onPressed: _openNewAnimalPage,
        tooltip: 'Add Animal',
        child: const Icon(Icons.add),
      ),
    );
  }
}
