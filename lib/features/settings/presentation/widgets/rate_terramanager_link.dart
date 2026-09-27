import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations_context.dart';

/// A user-initiated external link; it never requests or submits a review.
class RateTerraManagerLink extends StatefulWidget {
  const RateTerraManagerLink({super.key});

  @override
  State<RateTerraManagerLink> createState() => _RateTerraManagerLinkState();
}

class _RateTerraManagerLinkState extends State<RateTerraManagerLink> {
  static const _channel = MethodChannel('com.codefrog.terramanager/browser');
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await _channel.invokeMethod<void>('openStoreListing');
    } on PlatformException {
      _showFailure();
    } on MissingPluginException {
      _showFailure();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.failedToOpenStoreListing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const Key('rate-terramanager-link'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.star_outline),
      title: Text(context.l10n.rateTerraManager),
      subtitle: Text(context.l10n.rateTerraManagerDescription),
      trailing: _opening
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.open_in_new),
      onTap: _opening ? null : _open,
    );
  }
}
