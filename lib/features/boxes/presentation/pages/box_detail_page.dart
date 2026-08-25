import 'package:flutter/material.dart';

class BoxDetailPage extends StatelessWidget {
  final String qrId;

  const BoxDetailPage({
    super.key,
    required this.qrId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Box Details'),
      ),
      body: Center(
        child: Text('Box Detail: $qrId'),
      ),
    );
  }
}