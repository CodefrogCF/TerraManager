import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/animal_repository.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/media/media_thumbnail.dart';
import '../../../navigation/domain/detail_navigation_context.dart';
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

  final ScrollController _scrollController = ScrollController();

  final Map<int, Future<MediaAsset?>> _pictureFutures = {};

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  void _loadAnimals() {
    _pictureFutures.clear();

    _animalsFuture = AnimalRepository(widget.database).getActiveAnimals();
  }

  Future<void> _reloadAnimalsPreservingScroll(double previousOffset) async {
    setState(() {
      _loadAnimals();
    });

    try {
      await _animalsFuture;
    } catch (_) {
      return;
    }

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final maxOffset = _scrollController.position.maxScrollExtent;

      final targetOffset = previousOffset.clamp(0.0, maxOffset);

      _scrollController.jumpTo(targetOffset);
    });
  }

  Future<MediaAsset?> _pictureFutureFor(int? mediaId) {
    if (mediaId == null) {
      return Future<MediaAsset?>.value(null);
    }

    return _pictureFutures.putIfAbsent(
      mediaId,
      () => MediaRepository(widget.database).getMediaById(mediaId),
    );
  }

  Future<void> _openNewAnimalPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewAnimalPage(database: widget.database),
      ),
    );

    if (!mounted || created != true) {
      return;
    }

    setState(() {
      _loadAnimals();
    });
  }

  Future<void> _openAnimalDetail(Animal animal, List<Animal> animals) async {
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalDetailPage(
          database: widget.database,
          animalId: animal.id,
          navigationContext: DetailNavigationContext.activeAnimals(
            animalIds: animals.map((animal) => animal.id),
            currentAnimalId: animal.id,
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadAnimalsPreservingScroll(previousOffset);
  }

  Future<void> _openAnimalHistory() async {
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimalHistoryPage(database: widget.database),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadAnimalsPreservingScroll(previousOffset);
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
            key: const PageStorageKey<String>('animals-overview-list'),
            controller: _scrollController,
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];

              return ListTile(
                key: Key('animal-list-item-${animal.id}'),
                leading: FutureBuilder<MediaAsset?>(
                  future: _pictureFutureFor(animal.pictureMediaId),
                  builder: (context, pictureSnapshot) {
                    return MediaThumbnail(
                      key: Key('animal-thumbnail-${animal.id}'),
                      pictureBytes: pictureSnapshot.data?.data,
                      picturePath: pictureSnapshot.data == null
                          ? animal.picturePath
                          : null,
                      fallbackIcon: Icons.emoji_nature_outlined,
                    );
                  },
                ),
                title: Text(animal.commonName),
                subtitle: Text(animal.latinName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _openAnimalDetail(animal, animals);
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
