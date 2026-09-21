import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_accent.dart';
import 'app_language.dart';
import 'animal_name_order.dart';
import 'animal_sort_order.dart';
import 'box_sort_order.dart';
import 'archive_sort_order.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentKey = 'accent';
  static const String _languageKey = 'language';
  static const String _animalNameOrderKey = 'animal_name_order';
  static const String _animalSortOrderKey = 'animal_sort_order';
  static const String _animalCategoryViewEnabledKey =
      'animal_category_view_enabled';
  static const String _bigPictureModeEnabledKey = 'big_picture_mode_enabled';
  static const String _boxSortOrderKey = 'box_sort_order';
  static const String _animalArchiveSortOrderKey = 'animal_archive_sort_order';

  static const String _boxArchiveSortOrderKey = 'box_archive_sort_order';

  ThemeMode _themeMode = ThemeMode.system;
  AppAccent _accent = AppAccent.green;
  AppLanguage _language = AppLanguage.system;
  AnimalNameOrder _animalNameOrder = AnimalNameOrder.commonNameFirst;
  AnimalSortOrder _animalSortOrder = AnimalSortOrder.createdOldestFirst;
  bool _animalCategoryViewEnabled = false;
  bool _bigPictureModeEnabled = false;
  BoxSortOrder _boxSortOrder = BoxSortOrder.labelAscending;
  ArchiveSortOrder _animalArchiveSortOrder =
      ArchiveSortOrder.archivedNewestFirst;

  ArchiveSortOrder _boxArchiveSortOrder = ArchiveSortOrder.archivedNewestFirst;

  ThemeMode get themeMode => _themeMode;
  AppAccent get accent => _accent;
  AppLanguage get language => _language;
  AnimalNameOrder get animalNameOrder => _animalNameOrder;
  AnimalSortOrder get animalSortOrder => _animalSortOrder;
  bool get animalCategoryViewEnabled => _animalCategoryViewEnabled;
  bool get bigPictureModeEnabled => _bigPictureModeEnabled;
  BoxSortOrder get boxSortOrder => _boxSortOrder;
  ArchiveSortOrder get animalArchiveSortOrder => _animalArchiveSortOrder;

  ArchiveSortOrder get boxArchiveSortOrder => _boxArchiveSortOrder;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _themeMode = _parseThemeMode(preferences.getString(_themeModeKey));

    _accent = _parseAccent(preferences.getString(_accentKey));

    _language = _parseLanguage(preferences.getString(_languageKey));

    _animalNameOrder = _parseAnimalNameOrder(
      preferences.getString(_animalNameOrderKey),
    );

    final storedAnimalSortOrder = preferences.getString(_animalSortOrderKey);
    final parsedAnimalSortOrder = _parseAnimalSortOrder(storedAnimalSortOrder);
    _animalSortOrder = parsedAnimalSortOrder.normalized;
    _animalCategoryViewEnabled =
        preferences.getBool(_animalCategoryViewEnabledKey) ??
        parsedAnimalSortOrder.isLegacyCategoryOrder;

    _bigPictureModeEnabled =
        preferences.getBool(_bigPictureModeEnabledKey) ?? false;

    if (parsedAnimalSortOrder.isLegacyCategoryOrder) {
      await preferences.setString(_animalSortOrderKey, _animalSortOrder.name);
      if (!preferences.containsKey(_animalCategoryViewEnabledKey)) {
        await preferences.setBool(
          _animalCategoryViewEnabledKey,
          _animalCategoryViewEnabled,
        );
      }
    }

    final storedBoxSortOrder = preferences.getString(_boxSortOrderKey);
    _boxSortOrder = _parseBoxSortOrder(storedBoxSortOrder);

    if (storedBoxSortOrder == 'createdOldestFirst' ||
        storedBoxSortOrder == 'createdNewestFirst') {
      await preferences.setString(_boxSortOrderKey, _boxSortOrder.name);
    }

    _animalArchiveSortOrder = _parseArchiveSortOrder(
      preferences.getString(_animalArchiveSortOrderKey),
    );

    _boxArchiveSortOrder = _parseArchiveSortOrder(
      preferences.getString(_boxArchiveSortOrderKey),
    );

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

  Future<void> setAnimalSortOrder(AnimalSortOrder animalSortOrder) async {
    final normalizedSortOrder = animalSortOrder.normalized;
    final enableCategoryView = animalSortOrder.isLegacyCategoryOrder;
    if (_animalSortOrder == normalizedSortOrder &&
        (!enableCategoryView || _animalCategoryViewEnabled)) {
      return;
    }

    _animalSortOrder = normalizedSortOrder;
    if (enableCategoryView) {
      _animalCategoryViewEnabled = true;
    }
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_animalSortOrderKey, normalizedSortOrder.name);
    if (enableCategoryView) {
      await preferences.setBool(_animalCategoryViewEnabledKey, true);
    }
  }

  Future<void> setAnimalArchiveSortOrder(
    ArchiveSortOrder archiveSortOrder,
  ) async {
    if (_animalArchiveSortOrder == archiveSortOrder) {
      return;
    }

    _animalArchiveSortOrder = archiveSortOrder;

    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _animalArchiveSortOrderKey,
      archiveSortOrder.name,
    );
  }

  Future<void> setBoxArchiveSortOrder(ArchiveSortOrder archiveSortOrder) async {
    if (_boxArchiveSortOrder == archiveSortOrder) {
      return;
    }

    _boxArchiveSortOrder = archiveSortOrder;

    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_boxArchiveSortOrderKey, archiveSortOrder.name);
  }

  Future<void> setAnimalCategoryViewEnabled(bool enabled) async {
    if (_animalCategoryViewEnabled == enabled) {
      return;
    }

    _animalCategoryViewEnabled = enabled;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_animalCategoryViewEnabledKey, enabled);
  }

  Future<void> setBigPictureModeEnabled(bool enabled) async {
    if (_bigPictureModeEnabled == enabled) {
      return;
    }

    _bigPictureModeEnabled = enabled;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_bigPictureModeEnabledKey, enabled);
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
    return switch (value) {
      'labelAscending' || 'createdOldestFirst' => BoxSortOrder.labelAscending,
      'labelDescending' || 'createdNewestFirst' => BoxSortOrder.labelDescending,
      'nameAscending' => BoxSortOrder.nameAscending,
      'nameDescending' => BoxSortOrder.nameDescending,
      'volumeAscending' => BoxSortOrder.volumeAscending,
      'volumeDescending' => BoxSortOrder.volumeDescending,
      _ => BoxSortOrder.labelAscending,
    };
  }

  AnimalSortOrder _parseAnimalSortOrder(String? value) {
    if (value == null) {
      return AnimalSortOrder.createdOldestFirst;
    }

    for (final order in AnimalSortOrder.values) {
      if (order.name == value) {
        return order;
      }
    }

    return AnimalSortOrder.createdOldestFirst;
  }

  ArchiveSortOrder _parseArchiveSortOrder(String? value) {
    if (value == null) {
      return ArchiveSortOrder.archivedNewestFirst;
    }

    for (final order in ArchiveSortOrder.values) {
      if (order.name == value) {
        return order;
      }
    }

    return ArchiveSortOrder.archivedNewestFirst;
  }

  Future<void> replaceSettings({
    required ThemeMode themeMode,
    required AppAccent accent,
    required AppLanguage language,
    required AnimalNameOrder animalNameOrder,
    required AnimalSortOrder animalSortOrder,
    bool animalCategoryViewEnabled = false,
    bool bigPictureModeEnabled = false,
    required BoxSortOrder boxSortOrder,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final previousThemeMode = _themeMode;
    final previousAccent = _accent;
    final previousLanguage = _language;
    final previousAnimalNameOrder = _animalNameOrder;
    final previousAnimalSortOrder = _animalSortOrder;
    final previousAnimalCategoryViewEnabled = _animalCategoryViewEnabled;
    final previousBigPictureModeEnabled = _bigPictureModeEnabled;
    final previousBoxSortOrder = _boxSortOrder;

    final previousStoredTheme = preferences.getString(_themeModeKey);

    final previousStoredAccent = preferences.getString(_accentKey);

    final previousStoredLanguage = preferences.getString(_languageKey);
    final previousStoredAnimalNameOrder = preferences.getString(
      _animalNameOrderKey,
    );
    final previousStoredAnimalSortOrder = preferences.getString(
      _animalSortOrderKey,
    );
    final previousStoredAnimalCategoryViewEnabled = preferences.getBool(
      _animalCategoryViewEnabledKey,
    );
    final previousStoredBigPictureModeEnabled = preferences.getBool(
      _bigPictureModeEnabledKey,
    );
    final previousStoredBoxSortOrder = preferences.getString(_boxSortOrderKey);

    final normalizedAnimalSortOrder = animalSortOrder.normalized;
    final normalizedAnimalCategoryViewEnabled =
        animalCategoryViewEnabled || animalSortOrder.isLegacyCategoryOrder;

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

      final animalSortOrderSaved = await preferences.setString(
        _animalSortOrderKey,
        normalizedAnimalSortOrder.name,
      );

      if (!animalSortOrderSaved) {
        throw StateError('Failed to persist Animal sort order');
      }

      final animalCategoryViewEnabledSaved = await preferences.setBool(
        _animalCategoryViewEnabledKey,
        normalizedAnimalCategoryViewEnabled,
      );

      if (!animalCategoryViewEnabledSaved) {
        throw StateError('Failed to persist Animal category view');
      }

      final bigPictureModeEnabledSaved = await preferences.setBool(
        _bigPictureModeEnabledKey,
        bigPictureModeEnabled,
      );

      if (!bigPictureModeEnabledSaved) {
        throw StateError('Failed to persist Big Picture Mode');
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
      _animalSortOrder = normalizedAnimalSortOrder;
      _animalCategoryViewEnabled = normalizedAnimalCategoryViewEnabled;
      _bigPictureModeEnabled = bigPictureModeEnabled;
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

      if (previousStoredAnimalSortOrder == null) {
        await preferences.remove(_animalSortOrderKey);
      } else {
        await preferences.setString(
          _animalSortOrderKey,
          previousStoredAnimalSortOrder,
        );
      }

      if (previousStoredAnimalCategoryViewEnabled == null) {
        await preferences.remove(_animalCategoryViewEnabledKey);
      } else {
        await preferences.setBool(
          _animalCategoryViewEnabledKey,
          previousStoredAnimalCategoryViewEnabled,
        );
      }

      if (previousStoredBigPictureModeEnabled == null) {
        await preferences.remove(_bigPictureModeEnabledKey);
      } else {
        await preferences.setBool(
          _bigPictureModeEnabledKey,
          previousStoredBigPictureModeEnabled,
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
      _animalSortOrder = previousAnimalSortOrder;
      _animalCategoryViewEnabled = previousAnimalCategoryViewEnabled;
      _bigPictureModeEnabled = previousBigPictureModeEnabled;
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
