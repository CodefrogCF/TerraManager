import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/presentation/widgets/overview_context_menu.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
import '../animal_display_names.dart';
import '../animal_quick_action_dialogs.dart';
import 'animal_detail_page.dart';

enum _ArchivedAnimalAction { duplicate }

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

  Future<void> _duplicateAnimal(Animal animal) async {
    List<Box> boxes;
    try {
      boxes = await BoxRepository(widget.database).getActiveBoxes();
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToLoadBoxes);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (boxes.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('duplicate-animal-no-boxes-dialog'),
          title: Text(context.l10n.noBoxesAvailableTitle),
          content: Text(context.l10n.noBoxesForAnimal),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    final input = await showDialog<DuplicateAnimalInput>(
      context: context,
      builder: (_) => DuplicateAnimalDialog(
        initialName: context.l10n.copyName(animal.commonName),
        boxes: boxes,
      ),
    );
    if (!mounted || input == null) {
      return;
    }

    try {
      await AnimalRepository(widget.database).duplicateAnimal(
        sourceAnimalId: animal.id,
        boxId: input.boxId,
        commonName: input.commonName,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToDuplicateAnimal);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
              final displayNames = AnimalDisplayNames.fromContext(
                context,
                commonName: animal.commonName,
                latinName: animal.latinName,
              );

              return OverviewContextMenu<_ArchivedAnimalAction>(
                key: Key('archived-animal-context-menu-region-${animal.id}'),
                menuButtonKey: Key(
                  'archived-animal-context-menu-button-${animal.id}',
                ),
                tooltip: context.l10n.animalActions(displayNames.primary),
                onSelected: (_) {
                  _duplicateAnimal(animal);
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_ArchivedAnimalAction>(
                    value: _ArchivedAnimalAction.duplicate,
                    child: Row(
                      children: [
                        const Icon(Icons.copy_outlined, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(context.l10n.duplicateAnimal)),
                      ],
                    ),
                  ),
                ],
                builder: (context, menuButton) => ListTile(
                  key: Key('archived-animal-list-item-${animal.id}'),
                  leading: const Icon(Icons.history),
                  title: Text(displayNames.primary),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayNames.secondary),
                      const SizedBox(height: 4),
                      Text(_archiveSummary(context, animal)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: menuButton,
                  onTap: () {
                    _openAnimalDetail(animal, animals);
                  },
                ),
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
