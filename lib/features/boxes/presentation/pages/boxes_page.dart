import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import 'box_detail_page.dart';
import 'box_scanner_page.dart';
import 'new_box_page.dart';

class BoxesPage extends StatefulWidget {
  final AppDatabase database;

  const BoxesPage({
    super.key,
    required this.database,
  });

  @override
  State<BoxesPage> createState() => _BoxesPageState();
}

class _BoxesPageState extends State<BoxesPage> {
  late Future<List<Box>> _boxesFuture;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  void _loadBoxes() {
    _boxesFuture = BoxRepository(
      widget.database,
    ).getAllBoxes();
  }

  Future<void> _openNewBoxPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewBoxPage(
          database: widget.database,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      setState(() {
        _loadBoxes();
      });
    }
  }

  Future<void> _openBoxDetail(
    Box box,
  ) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BoxDetailPage(
          database: widget.database,
          box: box,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (deleted == true) {
      setState(() {
        _loadBoxes();
      });
    }
  }

  Future<void> _openScannerPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BoxScannerPage(
          database: widget.database,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loadBoxes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boxes'),
        actions: [
          IconButton(
            key: const Key(
              'scan-box-button',
            ),
            onPressed: _openScannerPage,
            icon: const Icon(
              Icons.qr_code_scanner,
            ),
            tooltip: 'Scan Box',
          ),
        ],
      ),
      body: FutureBuilder<List<Box>>(
        future: _boxesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Failed to load boxes',
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final boxes = snapshot.data ?? [];

          if (boxes.isEmpty) {
            return const Center(
              child: Text(
                'No boxes available',
              ),
            );
          }

          return ListView.builder(
            itemCount: boxes.length,
            itemBuilder: (context, index) {
              final box = boxes[index];

              return ListTile(
                key: Key(
                  'box-list-item-${box.id}',
                ),
                leading: const Icon(
                  Icons.home_outlined,
                ),
                title: Text(
                  box.qrId,
                ),
                subtitle: Text(
                  'Box ID: ${box.id}',
                ),
                onTap: () {
                  _openBoxDetail(
                    box,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton(
        key: const Key(
          'add-box-button',
        ),
        onPressed: _openNewBoxPage,
        tooltip: 'Add Box',
        child: const Icon(
          Icons.add,
        ),
      ),
    );
  }
}