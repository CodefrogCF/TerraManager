import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../boxes/presentation/pages/box_detail_page.dart';

class BoxesPage extends StatelessWidget {
  final AppDatabase database;

  const BoxesPage({
    super.key,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    final repository = BoxRepository(database);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boxes'),
      ),
      body: FutureBuilder<List<Box>>(
        future: repository.getAllBoxes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load boxes'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final boxes = snapshot.data ?? [];

          if (boxes.isEmpty) {
            return const Center(
              child: Text('No boxes available'),
            );
          }

          return ListView.builder(
            itemCount: boxes.length,
            itemBuilder: (context, index) {
              final box = boxes[index];

              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(box.qrId),
                subtitle: Text('Box ID: ${box.id}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BoxDetailPage(
                        qrId: box.qrId,
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