import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import 'animal_edit_page.dart';

class AnimalDetailPage extends StatefulWidget {
  final AppDatabase database;
  final int animalId;

  const AnimalDetailPage({
    super.key,
    required this.database,
    required this.animalId,
  });

  @override
  State<AnimalDetailPage> createState() => _AnimalDetailPageState();
}

class _AnimalDetailPageState extends State<AnimalDetailPage> {
  late Future<Animal?> _animalFuture;

  @override
  void initState() {
    super.initState();
    _loadAnimal();
  }

  void _loadAnimal() {
    _animalFuture =
        AnimalRepository(widget.database).getAnimalById(widget.animalId);
  }

  Future<void> _openEditPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnimalEditPage(
          database: widget.database,
          animalId: widget.animalId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      setState(() {
        _loadAnimal();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Details'),
        actions: [
          IconButton(
            key: const Key('edit-animal-button'),
            onPressed: _openEditPage,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Animal',
          ),
        ],
      ),
      body: FutureBuilder<Animal?>(
        future: _animalFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load animal'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final animal = snapshot.data;

          if (animal == null) {
            return const Center(
              child: Text('Animal not found'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                animal.commonName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                animal.latinName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              _DetailRow(
                label: 'Box',
                value: 'Box ${animal.boxId}',
              ),

              if (animal.sex != null)
                _DetailRow(
                  label: 'Sex',
                  value: animal.sex.toString(),
                ),

              if (animal.birthDate != null)
                _DetailRow(
                  label: 'Birth date',
                  value: _formatDate(animal.birthDate!),
                ),

              if (animal.birthDateAccuracy != null)
                _DetailRow(
                  label: 'Birth date accuracy',
                  value: animal.birthDateAccuracy.toString(),
                ),

              _DetailRow(
                label: 'Temperature',
                value: '${animal.tempMin} °C – ${animal.tempMax} °C',
              ),

              _DetailRow(
                label: 'Humidity',
                value: '${animal.humidityMin}% – ${animal.humidityMax}%',
              ),

              if (animal.notes != null && animal.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(animal.notes!),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}