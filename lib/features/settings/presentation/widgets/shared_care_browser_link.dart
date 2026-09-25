import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared_client/shared_text.dart';

const _browserChannel = MethodChannel('com.codefrog.terramanager/browser');

/// Opens the shared collection in the system browser. The Android app does
/// not make a network request and keeps its local collection independent.
class SharedCareBrowserLink extends StatelessWidget {
  const SharedCareBrowserLink({super.key});

  static const _preferenceKey = 'shared_care_browser_origin';

  Future<void> _open(BuildContext context) async {
    final preferences = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    try {
      final origin = await showDialog<String>(
        context: context,
        builder: (_) => _SharedServerUrlDialog(
          initial: preferences.getString(_preferenceKey) ?? '',
        ),
      );
      if (origin == null || !context.mounted) return;
      await preferences.setString(_preferenceKey, origin);
      await _browserChannel.invokeMethod<void>('openExternalUrl', {
        'url': origin,
      });
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sharedText(
                context,
                'No browser could open the server address.',
                'Die Serveradresse konnte nicht im Browser geöffnet werden.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const Key('shared-care-browser-link'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.open_in_browser),
      title: Text(
        sharedText(context, 'Open shared server', 'Gemeinsamen Server öffnen'),
      ),
      subtitle: Text(
        sharedText(
          context,
          'Use the server collection in your browser',
          'Serversammlung im Browser verwenden',
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(context),
    );
  }
}

/// Opens the public project pages without adding a network permission to the
/// standalone Android app. Android owns the fixed destination URLs.
class ProjectWebLinks extends StatelessWidget {
  const ProjectWebLinks({super.key});

  Future<void> _open(BuildContext context, String page) async {
    try {
      await _browserChannel.invokeMethod<void>('openProjectPage', {
        'page': page,
      });
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sharedText(
                context,
                'Install the updated app to open project links.',
                'Installiere die aktualisierte App, um Projektlinks zu öffnen.',
              ),
            ),
          ),
        );
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sharedText(
                context,
                'No browser could open this page.',
                'Die Seite konnte nicht im Browser geöffnet werden.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final language = Localizations.localeOf(context).languageCode == 'de'
        ? 'de'
        : 'en';
    return Column(
      children: [
        ListTile(
          key: const Key('project-website-link'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language),
          title: Text(sharedText(context, 'Website', 'Website')),
          subtitle: Text(
            sharedText(
              context,
              'Downloads and project information',
              'Downloads und Projektinformationen',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, 'website-$language'),
        ),
        const Divider(),
        ListTile(
          key: const Key('project-guide-link'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(sharedText(context, 'User guide', 'Anleitung')),
          subtitle: Text(
            sharedText(
              context,
              'Standalone and shared-care instructions',
              'Anleitungen für Einzel- und gemeinsame Nutzung',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, 'guide-$language'),
        ),
      ],
    );
  }
}

class _SharedServerUrlDialog extends StatefulWidget {
  const _SharedServerUrlDialog({required this.initial});
  final String initial;

  @override
  State<_SharedServerUrlDialog> createState() => _SharedServerUrlDialogState();
}

class _SharedServerUrlDialogState extends State<_SharedServerUrlDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validOrigin(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    return uri.origin;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      sharedText(context, 'Open shared server', 'Gemeinsamen Server öffnen'),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sharedText(
            context,
            'The shared collection opens in your browser. Your local app collection stays separate and is not synchronized automatically.',
            'Die gemeinsame Sammlung öffnet sich im Browser. Deine lokale App-Sammlung bleibt getrennt und wird nicht automatisch synchronisiert.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('shared-server-url'),
          controller: _controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'HTTPS URL',
            hintText: 'https://192.168.1.117',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        key: const Key('open-shared-server'),
        onPressed: () {
          final value = _validOrigin(_controller.text);
          if (value == null) {
            setState(
              () => _error = sharedText(
                context,
                'Enter the server HTTPS address without a path.',
                'HTTPS-Adresse des Servers ohne Pfad eingeben.',
              ),
            );
            return;
          }
          Navigator.of(context).pop(value);
        },
        child: Text(sharedText(context, 'Open', 'Öffnen')),
      ),
    ],
  );
}
