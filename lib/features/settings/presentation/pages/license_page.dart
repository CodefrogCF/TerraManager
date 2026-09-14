import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations_context.dart';
import 'legal_document_page.dart';

class AppLicensePage extends StatelessWidget {
  static const licenseAssetPath = 'LICENSE';

  final String title;
  final String? licenseText;

  const AppLicensePage({super.key, required this.title, this.licenseText});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: title,
      assetPath: licenseAssetPath,
      loadErrorText: context.l10n.licenseLoadError,
      documentPreamble: '# TerraManager\n\n${context.l10n.licenseNotice}',
      pageKey: const Key('license-page'),
      contentKey: const Key('license-content'),
      loadingKey: const Key('license-loading'),
      loadErrorKey: const Key('license-load-error'),
      documentText: licenseText,
    );
  }
}
