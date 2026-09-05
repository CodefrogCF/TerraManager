import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n {
    return AppLocalizations.of(this) ??
        lookupAppLocalizations(const Locale('en'));
  }
}
