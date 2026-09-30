import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

class BackupExportChoice {
  const BackupExportChoice(this.password);
  final String? password;
  bool get encrypted => password != null;
}

Future<BackupExportChoice?> chooseBackupProtection(BuildContext context) {
  return showDialog<BackupExportChoice>(
    context: context,
    builder: (context) => const _BackupPasswordDialog(export: true),
  );
}

Future<String?> askBackupPassword(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _BackupPasswordDialog(export: false),
  );
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.export});
  final bool export;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _protected = false;
  String? _error;

  @override
  void dispose() {
    _password.clear();
    _confirmation.clear();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.export && !_protected) {
      Navigator.pop(context, const BackupExportChoice(null));
      return;
    }
    if (_password.text.isEmpty) {
      setState(
        () => _error = sharedText(
          context,
          'Enter a password.',
          'Bitte ein Passwort eingeben.',
        ),
      );
      return;
    }
    if (widget.export && _password.text != _confirmation.text) {
      setState(
        () => _error = sharedText(
          context,
          'Passwords do not match.',
          'Die Passwörter stimmen nicht überein.',
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      widget.export ? BackupExportChoice(_password.text) : _password.text,
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.export
          ? sharedText(context, 'Save backup', 'Sicherung speichern')
          : sharedText(context, 'Encrypted backup', 'Verschlüsselte Sicherung'),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.export)
            SwitchListTile(
              key: const Key('backup-password-protection'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                sharedText(
                  context,
                  'Protect with password',
                  'Mit Passwort schützen',
                ),
              ),
              value: _protected,
              onChanged: (value) => setState(() {
                _protected = value;
                _error = null;
              }),
            ),
          if (!widget.export || _protected) ...[
            Text(
              sharedText(
                context,
                'Keep this password safe. A forgotten password cannot be recovered.',
                'Bewahre dieses Passwort sicher auf. Ein vergessenes Passwort kann nicht wiederhergestellt werden.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('backup-password'),
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Password', 'Passwort'),
              ),
            ),
            if (widget.export)
              TextField(
                key: const Key('backup-password-confirmation'),
                controller: _confirmation,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: sharedText(
                    context,
                    'Confirm password',
                    'Passwort bestätigen',
                  ),
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        key: const Key('backup-password-submit'),
        onPressed: _submit,
        child: Text(
          widget.export
              ? sharedText(context, 'Save', 'Speichern')
              : sharedText(context, 'Unlock', 'Entsperren'),
        ),
      ),
    ],
  );
}
