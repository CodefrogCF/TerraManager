import 'package:flutter/widgets.dart';

enum AppLanguage {
  system,
  english,
  german;

  Locale? get locale {
    return switch (this) {
      AppLanguage.system => null,
      AppLanguage.english => const Locale('en'),
      AppLanguage.german => const Locale('de'),
    };
  }
}

const supportedAppLocales = <Locale>[Locale('en'), Locale('de')];
