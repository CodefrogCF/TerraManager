import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';

class NewBoxPage extends StatefulWidget {
  final AppDatabase database;

  const NewBoxPage({
    super.key,
    required this.database,
  });

  @override
  State<NewBoxPage> createState() => _NewBoxPageState();
}

class _NewBoxPageState extends State<NewBoxPage> {
  final _formKey = GlobalKey<FormState>();
  final _qrIdController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _qrIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await BoxRepository(widget.database).createBox(
        _qrIdController.text.trim(),
      );

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
      appBar: AppBar(
        title: const Text('New Box'),
        actions: [
          IconButton(
            key: const Key('save-box-button'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            tooltip: 'Save Box',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('qr-id-field'),
                controller: _qrIdController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'QR ID',
                  helperText:
                      'Temporary manual identifier until QR generation is implemented.',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a QR ID';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('create-box-button'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _saving ? 'Creating...' : 'Create Box',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}