import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_accent.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentKey = 'accent';

  ThemeMode _themeMode = ThemeMode.system;
  AppAccent _accent = AppAccent.green;

  ThemeMode get themeMode => _themeMode;
  AppAccent get accent => _accent;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _themeMode = _parseThemeMode(preferences.getString(_themeModeKey));

    _accent = _parseAccent(preferences.getString(_accentKey));

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

  Future<void> replaceSettings({
    required ThemeMode themeMode,
    required AppAccent accent,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final previousThemeMode = _themeMode;
    final previousAccent = _accent;

    final previousStoredTheme = preferences.getString(_themeModeKey);

    final previousStoredAccent = preferences.getString(_accentKey);

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

      _themeMode = themeMode;
      _accent = accent;

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

      _themeMode = previousThemeMode;
      _accent = previousAccent;

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
