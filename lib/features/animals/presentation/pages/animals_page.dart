import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import 'animal_detail_page.dart';

class AnimalsPage extends StatelessWidget {
  final AppDatabase database;

  const AnimalsPage({
    super.key,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    final repository = AnimalRepository(database);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
      ),
      body: FutureBuilder<List<Animal>>(
        future: repository.getAllAnimals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load animals'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final animals = snapshot.data ?? [];

          if (animals.isEmpty) {
            return const Center(
              child: Text('No animals available'),
            );
          }

          return ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];

              return ListTile(
                leading: const Icon(Icons.emoji_nature_outlined),
                title: Text(animal.commonName),
                subtitle: Text(animal.latinName),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnimalDetailPage(
                        database: database,
                        animalId: animal.id,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}