import 'package:flutter/material.dart';

class BoxesPage extends StatelessWidget {
  const BoxesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boxes'),
      ),
      body: const Center(
        child: Text('Box overview'),
      ),
    );
  }
}