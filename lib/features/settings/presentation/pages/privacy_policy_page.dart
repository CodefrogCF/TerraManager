import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations_context.dart';
import 'legal_document_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  static const englishAssetPath = 'PRIVACY.md';
  static const germanAssetPath = 'PRIVACY.de.md';

  final String title;
  final String? policyText;

  const PrivacyPolicyPage({super.key, required this.title, this.policyText});

  static String assetPathForLocale(Locale locale) {
    return locale.languageCode.toLowerCase() == 'de'
        ? germanAssetPath
        : englishAssetPath;
  }

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: title,
      assetPath: assetPathForLocale(Localizations.localeOf(context)),
      loadErrorText: context.l10n.privacyPolicyLoadError,
      pageKey: const Key('privacy-policy-page'),
      contentKey: const Key('privacy-policy-content'),
      loadingKey: const Key('privacy-policy-loading'),
      loadErrorKey: const Key('privacy-policy-load-error'),
      documentText: policyText,
    );
  }
}
