import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';

class NewBoxPage extends StatefulWidget {
  final AppDatabase database;

  const NewBoxPage({super.key, required this.database});

  @override
  State<NewBoxPage> createState() => _NewBoxPageState();
}

class _NewBoxPageState extends State<NewBoxPage> {
  bool _saving = false;
  String? _error;

  Future<void> _createBox() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await BoxRepository(widget.database).createBoxWithGeneratedQrId();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = 'Failed to create box';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Box')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.qr_code,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                Text(
                  'Create a new box',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),

                Text(
                  'A unique QR identifier will be generated automatically '
                  'for this box.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),

                Text(
                  'Format: TM:BOX:<UUID>',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                FilledButton.icon(
                  key: const Key('create-box-button'),
                  onPressed: _saving ? null : _createBox,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(_saving ? 'Creating...' : 'Create Box'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
