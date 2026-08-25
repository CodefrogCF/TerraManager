import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

class BoxDetailPage extends StatelessWidget {
  final Box box;

  const BoxDetailPage({
    super.key,
    required this.box,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Box Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('QR ID'),
            subtitle: Text(box.qrId),
          ),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('Box ID'),
            subtitle: Text(box.id.toString()),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Created'),
            subtitle: Text(box.createdAt.toString()),
          ),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Updated'),
            subtitle: Text(box.updatedAt.toString()),
          ),
        ],
      ),
    );
  }
}