import 'package:flutter/material.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

/// Shared Care never reads browser preferences or silently imports another user.
class SharedAccountSettings extends AppSettingsController {
  SharedAccountSettings(this.api) {
    api.addListener(_sessionChanged);
    _sessionChanged();
  }
  final SharedApiClient api;
  SharedSession? _owner;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  Object? saveError;

  void _sessionChanged() {
    if (identical(_owner, api.session)) return;
    _owner = api.session;
    saveError = null;
    applyStoredSettings(_owner?.preferences ?? const {});
  }

  @override
  Future<void> load() async {}

  Future<void> _save(Map<String, Object> patch) {
    final owner = _owner;
    // Serialize rapid changes; a late response from a previous login is ignored.
    return _pending = _pending.then((_) async {
      if (_disposed || owner == null || !identical(owner, api.session)) return;
      try {
        final saved = await api.updatePreferences(patch);
        if (_disposed || !identical(owner, api.session)) return;
        saveError = null;
        applyStoredSettings(saved);
      } catch (error) {
        if (_disposed || !identical(owner, api.session)) return;
        saveError = error;
        notifyListeners();
      }
    });
  }

  void dismissError() {
    saveError = null;
    notifyListeners();
  }

  @override
  Future<void> setThemeMode(ThemeMode themeMode) =>
      _save({'theme_mode': themeMode.name});
  @override
  Future<void> setAccent(AppAccent accent) => _save({'accent': accent.name});
  @override
  Future<void> setLanguage(AppLanguage language) =>
      _save({'language': language.name});
  @override
  Future<void> setAnimalNameOrder(AnimalNameOrder animalNameOrder) =>
      _save({'animal_name_order': animalNameOrder.name});
  @override
  Future<void> setAnimalSortOrder(AnimalSortOrder animalSortOrder) => _save({
    'animal_sort_order': animalSortOrder.normalized.name,
    if (animalSortOrder.isLegacyCategoryOrder)
      'animal_category_view_enabled': true,
  });
  @override
  Future<void> setBoxSortOrder(BoxSortOrder boxSortOrder) =>
      _save({'box_sort_order': boxSortOrder.name});
  @override
  Future<void> setAnimalArchiveSortOrder(ArchiveSortOrder archiveSortOrder) =>
      _save({'animal_archive_sort_order': archiveSortOrder.name});
  @override
  Future<void> setBoxArchiveSortOrder(ArchiveSortOrder archiveSortOrder) =>
      _save({'box_archive_sort_order': archiveSortOrder.name});
  @override
  Future<void> setAnimalCategoryViewEnabled(bool enabled) =>
      _save({'animal_category_view_enabled': enabled});
  @override
  Future<void> setNextFeedingSummaryEnabled(bool enabled) =>
      _save({'next_feeding_summary_enabled': enabled});
  @override
  Future<void> setBigPictureModeEnabled(bool enabled) =>
      _save({'big_picture_mode_enabled': enabled});

  @override
  Future<void> replaceSettings({
    required ThemeMode themeMode,
    required AppAccent accent,
    required AppLanguage language,
    required AnimalNameOrder animalNameOrder,
    required AnimalSortOrder animalSortOrder,
    bool animalCategoryViewEnabled = false,
    required bool nextFeedingSummaryEnabled,
    bool bigPictureModeEnabled = false,
    required BoxSortOrder boxSortOrder,
  }) => _save({
    'theme_mode': themeMode.name,
    'accent': accent.name,
    'language': language.name,
    'animal_name_order': animalNameOrder.name,
    'animal_sort_order': animalSortOrder.normalized.name,
    'animal_category_view_enabled':
        animalCategoryViewEnabled || animalSortOrder.isLegacyCategoryOrder,
    'next_feeding_summary_enabled': nextFeedingSummaryEnabled,
    'big_picture_mode_enabled': bigPictureModeEnabled,
    'box_sort_order': boxSortOrder.name,
  });

  @override
  void dispose() {
    _disposed = true;
    api.removeListener(_sessionChanged);
    super.dispose();
  }
}
