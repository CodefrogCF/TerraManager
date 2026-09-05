import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_accent.dart';
import 'app_language.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentKey = 'accent';
  static const String _languageKey = 'language';

  ThemeMode _themeMode = ThemeMode.system;
  AppAccent _accent = AppAccent.green;
  AppLanguage _language = AppLanguage.system;

  ThemeMode get themeMode => _themeMode;
  AppAccent get accent => _accent;
  AppLanguage get language => _language;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _themeMode = _parseThemeMode(preferences.getString(_themeModeKey));

    _accent = _parseAccent(preferences.getString(_accentKey));

    _language = _parseLanguage(preferences.getString(_languageKey));

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }

    _themeMode = themeMode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_themeModeKey, themeMode.name);
  }

  Future<void> setAccent(AppAccent accent) async {
    if (_accent == accent) {
      return;
    }

    _accent = accent;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_accentKey, accent.name);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_languageKey, language.name);
  }

  ThemeMode _parseThemeMode(String? value) {
    if (value == null) {
      return ThemeMode.system;
    }

    for (final themeMode in ThemeMode.values) {
      if (themeMode.name == value) {
        return themeMode;
      }
    }

    return ThemeMode.system;
  }

  AppAccent _parseAccent(String? value) {
    if (value == null) {
      return AppAccent.green;
    }

    for (final accent in AppAccent.values) {
      if (accent.name == value) {
        return accent;
      }
    }

    return AppAccent.green;
  }

  AppLanguage _parseLanguage(String? value) {
    if (value == null) {
      return AppLanguage.system;
    }

    for (final language in AppLanguage.values) {
      if (language.name == value) {
        return language;
      }
    }

    return AppLanguage.system;
  }

  Future<void> replaceSettings({
    required ThemeMode themeMode,
    required AppAccent accent,
    required AppLanguage language,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final previousThemeMode = _themeMode;
    final previousAccent = _accent;
    final previousLanguage = _language;

    final previousStoredTheme = preferences.getString(_themeModeKey);

    final previousStoredAccent = preferences.getString(_accentKey);

    final previousStoredLanguage = preferences.getString(_languageKey);

    try {
      final themeSaved = await preferences.setString(
        _themeModeKey,
        themeMode.name,
      );

      if (!themeSaved) {
        throw StateError('Failed to persist theme mode');
      }

      final accentSaved = await preferences.setString(_accentKey, accent.name);

      if (!accentSaved) {
        throw StateError('Failed to persist accent');
      }

      final languageSaved = await preferences.setString(
        _languageKey,
        language.name,
      );

      if (!languageSaved) {
        throw StateError('Failed to persist language');
      }

      _themeMode = themeMode;
      _accent = accent;
      _language = language;

      notifyListeners();
    } catch (_) {
      if (previousStoredTheme == null) {
        await preferences.remove(_themeModeKey);
      } else {
        await preferences.setString(_themeModeKey, previousStoredTheme);
      }

      if (previousStoredAccent == null) {
        await preferences.remove(_accentKey);
      } else {
        await preferences.setString(_accentKey, previousStoredAccent);
      }

      if (previousStoredLanguage == null) {
        await preferences.remove(_languageKey);
      } else {
        await preferences.setString(_languageKey, previousStoredLanguage);
      }

      _themeMode = previousThemeMode;
      _accent = previousAccent;
      _language = previousLanguage;

      notifyListeners();

      rethrow;
    }
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();

    assert(scope != null, 'No AppSettingsScope found in context');

    return scope!.notifier!;
  }
}
