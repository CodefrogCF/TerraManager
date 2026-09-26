import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/constrained_page_width.dart';
import '../../../shared_api_client.dart';
import '../../../shared_text.dart';

String _roleLabel(BuildContext context, String role) => role == 'administrator'
    ? sharedText(context, 'Administrator', 'Administrator')
    : sharedText(context, 'Caregiver', 'Betreuung');

class SharedAccountsSection extends StatelessWidget {
  const SharedAccountsSection({super.key, required this.api});
  final SharedApiClient api;

  @override
  Widget build(BuildContext context) => ListTile(
    key: const Key('shared-manage-accounts'),
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.manage_accounts_outlined),
    title: Text(sharedText(context, 'Manage accounts', 'Konten verwalten')),
    subtitle: Text(
      sharedText(
        context,
        'Add, edit, deactivate or remove server accounts.',
        'Serverkonten hinzufügen, bearbeiten, deaktivieren oder löschen.',
      ),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: api.connected && api.session?.role == 'administrator'
        ? () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SharedAccountsPage(api: api),
            ),
          )
        : null,
  );
}

class SharedAccountsPage extends StatefulWidget {
  const SharedAccountsPage({super.key, required this.api});
  final SharedApiClient api;
  @override
  State<SharedAccountsPage> createState() => _SharedAccountsPageState();
}

class _SharedAccountsPageState extends State<SharedAccountsPage> {
  Future<List<Map<String, dynamic>>>? _accounts;
  bool _busy = false;
  String? _error;
  bool get _allowed => widget.api.session?.role == 'administrator';

  @override
  void initState() {
    super.initState();
    if (_allowed) _accounts = widget.api.accounts();
  }

  void _reload() {
    if (_allowed) setState(() => _accounts = widget.api.accounts());
  }

  Future<void> _change(
    Future<void> Function() operation,
    String success,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
      if (widget.api.session == null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _reload();
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is SharedApiException && error.status == 409
            ? sharedText(
                context,
                'The name is already in use, the account changed, or this is the last active administrator. Reload and check the account.',
                'Der Name ist bereits vergeben, das Konto wurde geändert oder es ist der letzte aktive Administrator. Liste neu laden und Konto prüfen.',
              )
            : sharedText(
                context,
                'Account change failed. Check your administrator access and connection, then reload before trying again.',
                'Kontoänderung fehlgeschlagen. Administratorzugang und Verbindung prüfen und vor einem neuen Versuch neu laden.',
              ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? account]) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AccountDialog(account: account),
    );
    if (values == null || !mounted) return;
    final self = account?['username'] == widget.api.session?.username;
    final success = self
        ? sharedText(
            context,
            'Account updated. Sign in again.',
            'Konto aktualisiert. Bitte erneut anmelden.',
          )
        : sharedText(context, 'Account saved.', 'Konto gespeichert.');
    await _change(() async {
      if (account == null) {
        await widget.api.createAccount(
          values['username'] as String,
          values['password'] as String,
          values['role'] as String,
        );
      } else {
        await widget.api.updateAccount(account['id'] as int, values);
      }
    }, success);
  }

  Future<void> _remove(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sharedText(context, 'Remove account?', 'Konto löschen?')),
        content: Text(
          sharedText(
            context,
            'Remove ${account['username']}? Its credentials and all sessions will be removed. Collection records and past audit entries remain. This cannot be undone.',
            '${account['username']} löschen? Zugangsdaten und alle Sitzungen werden entfernt. Sammlungsdaten und bisherige Audit-Einträge bleiben erhalten. Dies kann nicht rückgängig gemacht werden.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
          ),
          FilledButton(
            key: const Key('confirm-remove-account'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(sharedText(context, 'Remove account', 'Konto löschen')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(
      () => widget.api.removeAccount(
        account['id'] as int,
        account['auditId'] as String,
      ),
      sharedText(context, 'Account removed.', 'Konto gelöscht.'),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(sharedText(context, 'Manage accounts', 'Konten verwalten')),
      actions: [
        IconButton(
          key: const Key('reload-accounts'),
          onPressed: !_busy && _allowed ? _reload : null,
          tooltip: sharedText(context, 'Refresh', 'Aktualisieren'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ConstrainedPageWidth(
      maxWidth: 760,
      child: ListenableBuilder(
        listenable: widget.api,
        builder: (context, _) => !_allowed
            ? Center(
                child: Text(
                  sharedText(
                    context,
                    'Administrator access required.',
                    'Administratorzugang erforderlich.',
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    sharedText(
                      context,
                      'Changes sign the affected user out on all devices. Keep at least one active administrator. Account removal does not delete Animals, Boxes or care records.',
                      'Änderungen melden den betroffenen Benutzer auf allen Geräten ab. Mindestens ein aktiver Administrator muss erhalten bleiben. Das Löschen eines Kontos löscht keine Tiere, Boxen oder Pflegeeinträge.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_busy) const LinearProgressIndicator(),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _accounts,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          sharedText(
                            context,
                            'Accounts could not be loaded. Use Refresh to try again.',
                            'Konten konnten nicht geladen werden. Mit Aktualisieren erneut versuchen.',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      return Column(
                        children: [
                          for (final account in snapshot.data!)
                            ListTile(
                              key: Key('shared-account-${account['id']}'),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                account['active'] == true
                                    ? Icons.person_outline
                                    : Icons.person_off_outlined,
                              ),
                              title: Text(account['username'] as String),
                              subtitle: Text(
                                '${_roleLabel(context, account['role'] as String)} · '
                                '${account['active'] == true ? sharedText(context, 'Active', 'Aktiv') : sharedText(context, 'Inactive', 'Inaktiv')}',
                              ),
                              onTap: !_busy && widget.api.connected
                                  ? () => _edit(account)
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: Key('edit-account-${account['id']}'),
                                    onPressed: !_busy && widget.api.connected
                                        ? () => _edit(account)
                                        : null,
                                    tooltip: sharedText(
                                      context,
                                      'Edit account',
                                      'Konto bearbeiten',
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    key: Key('remove-account-${account['id']}'),
                                    onPressed: !_busy && widget.api.connected
                                        ? () => _remove(account)
                                        : null,
                                    tooltip: sharedText(
                                      context,
                                      'Remove account',
                                      'Konto löschen',
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        key: const Key('account-change-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  TextButton.icon(
                    key: const Key('add-account'),
                    onPressed: !_busy && widget.api.connected
                        ? () => _edit()
                        : null,
                    icon: const Icon(Icons.person_add_outlined),
                    label: Text(
                      sharedText(context, 'Add account', 'Konto hinzufügen'),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({this.account});
  final Map<String, dynamic>? account;
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final TextEditingController _username;
  final _password = TextEditingController();
  late String _role;
  late bool _active;
  String? _error;
  bool get _new => widget.account == null;
  @override
  void initState() {
    super.initState();
    _username = TextEditingController(
      text: widget.account?['username'] as String? ?? '',
    );
    _role = widget.account?['role'] as String? ?? 'caregiver';
    _active = widget.account?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _username.text.trim().toLowerCase();
    final password = _password.text;
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$').hasMatch(name) ||
        ((_new || password.isNotEmpty) &&
            (password.length < 12 || utf8.encode(password).length > 1024))) {
      setState(
        () => _error = sharedText(
          context,
          'Use a 3–64 character username starting with a letter or digit. Passwords need at least 12 characters and at most 1024 UTF-8 bytes.',
          'Benutzername: 3–64 Zeichen, beginnend mit Buchstabe oder Ziffer. Passwort: mindestens 12 Zeichen und höchstens 1024 UTF-8-Bytes.',
        ),
      );
      return;
    }
    final values = <String, dynamic>{
      if (!_new) 'expectedAuditId': widget.account!['auditId'],
      if (_new || name != widget.account!['username']) 'username': name,
      if (_new || _role != widget.account!['role']) 'role': _role,
      if (!_new && _active != widget.account!['active']) 'active': _active,
      if (_new || password.isNotEmpty) 'password': password,
    };
    if (values.keys.every((key) => key == 'expectedAuditId')) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      sharedText(
        context,
        _new ? 'Add account' : 'Edit account',
        _new ? 'Konto hinzufügen' : 'Konto bearbeiten',
      ),
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('account-username'),
              controller: _username,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Username', 'Benutzername'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('account-role'),
              initialValue: _role,
              decoration: InputDecoration(
                labelText: sharedText(context, 'Role', 'Rolle'),
              ),
              items: [
                for (final role in ['caregiver', 'administrator'])
                  DropdownMenuItem(
                    value: role,
                    child: Text(_roleLabel(context, role)),
                  ),
              ],
              onChanged: (role) {
                if (role != null) setState(() => _role = role);
              },
            ),
            if (!_new)
              SwitchListTile(
                key: const Key('account-active'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  sharedText(context, 'Active account', 'Konto aktiv'),
                ),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            TextField(
              key: const Key('account-password'),
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: sharedText(
                  context,
                  _new ? 'Password' : 'New password (optional)',
                  _new ? 'Passwort' : 'Neues Passwort (optional)',
                ),
                helperText: _new
                    ? null
                    : sharedText(
                        context,
                        'Leave empty to keep the password.',
                        'Leer lassen, um das Passwort beizubehalten.',
                      ),
              ),
            ),
            if (!_new)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  sharedText(
                    context,
                    'Saving changes signs this user out on all devices, including this device if you edit your own account.',
                    'Änderungen melden diesen Benutzer auf allen Geräten ab, auch hier, falls du dein eigenes Konto bearbeitest.',
                  ),
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        key: const Key('save-account'),
        onPressed: _submit,
        child: Text(
          sharedText(
            context,
            _new ? 'Create' : 'Save',
            _new ? 'Erstellen' : 'Speichern',
          ),
        ),
      ),
    ],
  );
}
