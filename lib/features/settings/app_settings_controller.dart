import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_accent.dart';
import 'app_language.dart';
import 'animal_name_order.dart';
import 'box_sort_order.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentKey = 'accent';
  static const String _languageKey = 'language';
  static const String _animalNameOrderKey = 'animal_name_order';
  static const String _boxSortOrderKey = 'box_sort_order';

  ThemeMode _themeMode = ThemeMode.system;
  AppAccent _accent = AppAccent.green;
  AppLanguage _language = AppLanguage.system;
  AnimalNameOrder _animalNameOrder = AnimalNameOrder.commonNameFirst;
  BoxSortOrder _boxSortOrder = BoxSortOrder.createdOldestFirst;

  ThemeMode get themeMode => _themeMode;
  AppAccent get accent => _accent;
  AppLanguage get language => _language;
  AnimalNameOrder get animalNameOrder => _animalNameOrder;
  BoxSortOrder get boxSortOrder => _boxSortOrder;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _themeMode = _parseThemeMode(preferences.getString(_themeModeKey));

    _accent = _parseAccent(preferences.getString(_accentKey));

    _language = _parseLanguage(preferences.getString(_languageKey));

    _animalNameOrder = _parseAnimalNameOrder(
      preferences.getString(_animalNameOrderKey),
    );

    _boxSortOrder = _parseBoxSortOrder(preferences.getString(_boxSortOrderKey));

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

  Future<void> setAnimalNameOrder(AnimalNameOrder animalNameOrder) async {
    if (_animalNameOrder == animalNameOrder) {
      return;
    }

    _animalNameOrder = animalNameOrder;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_animalNameOrderKey, animalNameOrder.name);
  }

  Future<void> setBoxSortOrder(BoxSortOrder boxSortOrder) async {
    if (_boxSortOrder == boxSortOrder) {
      return;
    }

    _boxSortOrder = boxSortOrder;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_boxSortOrderKey, boxSortOrder.name);
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

  AnimalNameOrder _parseAnimalNameOrder(String? value) {
    if (value == null) {
      return AnimalNameOrder.commonNameFirst;
    }

    for (final order in AnimalNameOrder.values) {
      if (order.name == value) {
        return order;
      }
    }

    return AnimalNameOrder.commonNameFirst;
  }

  BoxSortOrder _parseBoxSortOrder(String? value) {
    if (value == null) {
      return BoxSortOrder.createdOldestFirst;
    }

    for (final order in BoxSortOrder.values) {
      if (order.name == value) {
        return order;
      }
    }

    return BoxSortOrder.createdOldestFirst;
  }

  Future<void> replaceSettings({
    required ThemeMode themeMode,
    required AppAccent accent,
    required AppLanguage language,
    required AnimalNameOrder animalNameOrder,
    required BoxSortOrder boxSortOrder,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final previousThemeMode = _themeMode;
    final previousAccent = _accent;
    final previousLanguage = _language;
    final previousAnimalNameOrder = _animalNameOrder;
    final previousBoxSortOrder = _boxSortOrder;

    final previousStoredTheme = preferences.getString(_themeModeKey);

    final previousStoredAccent = preferences.getString(_accentKey);

    final previousStoredLanguage = preferences.getString(_languageKey);
    final previousStoredAnimalNameOrder = preferences.getString(
      _animalNameOrderKey,
    );
    final previousStoredBoxSortOrder = preferences.getString(_boxSortOrderKey);

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

      final animalNameOrderSaved = await preferences.setString(
        _animalNameOrderKey,
        animalNameOrder.name,
      );

      if (!animalNameOrderSaved) {
        throw StateError('Failed to persist Animal name order');
      }

      final boxSortOrderSaved = await preferences.setString(
        _boxSortOrderKey,
        boxSortOrder.name,
      );

      if (!boxSortOrderSaved) {
        throw StateError('Failed to persist Box sort order');
      }

      _themeMode = themeMode;
      _accent = accent;
      _language = language;
      _animalNameOrder = animalNameOrder;
      _boxSortOrder = boxSortOrder;

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

      if (previousStoredAnimalNameOrder == null) {
        await preferences.remove(_animalNameOrderKey);
      } else {
        await preferences.setString(
          _animalNameOrderKey,
          previousStoredAnimalNameOrder,
        );
      }

      if (previousStoredBoxSortOrder == null) {
        await preferences.remove(_boxSortOrderKey);
      } else {
        await preferences.setString(
          _boxSortOrderKey,
          previousStoredBoxSortOrder,
        );
      }

      _themeMode = previousThemeMode;
      _accent = previousAccent;
      _language = previousLanguage;
      _animalNameOrder = previousAnimalNameOrder;
      _boxSortOrder = previousBoxSortOrder;

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
    final controller = maybeOf(context);

    assert(controller != null, 'No AppSettingsScope found in context');

    return controller!;
  }

  static AppSettingsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
        ?.notifier;
  }
}
