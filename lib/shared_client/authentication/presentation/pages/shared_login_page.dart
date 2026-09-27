import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

class SharedLoginPage extends StatefulWidget {
  const SharedLoginPage({
    super.key,
    required this.busy,
    required this.error,
    required this.onLogin,
    required this.onRetry,
  });

  final bool busy;
  final String? error;
  final Future<void> Function(String, String) onLogin;
  final Future<void> Function() onRetry;

  @override
  State<SharedLoginPage> createState() => _SharedLoginPageState();
}

class _SharedLoginPageState extends State<SharedLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.appTitle)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sharedText(context, 'Shared Care', 'Gemeinsame Betreuung'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                key: const Key('shared-username'),
                controller: _username,
                enabled: !widget.busy,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(
                  labelText: sharedText(context, 'Username', 'Benutzername'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('shared-password'),
                controller: _password,
                enabled: !widget.busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: sharedText(context, 'Password', 'Passwort'),
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('shared-login'),
                onPressed: widget.busy ? null : _submit,
                child: Text(sharedText(context, 'Sign in', 'Anmelden')),
              ),
              if (widget.error != null)
                TextButton(
                  onPressed: widget.busy ? null : widget.onRetry,
                  child: Text(sharedText(context, 'Retry', 'Erneut versuchen')),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  void _submit() {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return;
    widget.onLogin(_username.text.trim(), _password.text);
  }
}
