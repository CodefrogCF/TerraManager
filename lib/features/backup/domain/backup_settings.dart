class BackupSettings {
  /// `collectionOnly` marks server exports: importing them must not replace
  /// preferences belonging to the person using the receiving device.
  final String scope;
  final String themeMode;
  final String accent;
  final String language;
  final String animalNameOrder;
  final String animalSortOrder;
  final bool animalCategoryViewEnabled;
  final bool nextFeedingSummaryEnabled;
  final bool bigPictureModeEnabled;
  final String boxSortOrder;

  const BackupSettings({
    this.scope = 'personal',
    required this.themeMode,
    required this.accent,
    this.language = 'system',
    this.animalNameOrder = 'commonNameFirst',
    this.animalSortOrder = 'createdOldestFirst',
    this.animalCategoryViewEnabled = false,
    this.nextFeedingSummaryEnabled = false,
    this.bigPictureModeEnabled = false,
    this.boxSortOrder = 'labelAscending',
  });

  Map<String, dynamic> toJson() {
    return {
      'scope': scope,
      'themeMode': themeMode,
      'accent': accent,
      'language': language,
      'animalNameOrder': animalNameOrder,
      'animalSortOrder': animalSortOrder,
      'animalCategoryViewEnabled': animalCategoryViewEnabled,
      'nextFeedingSummaryEnabled': nextFeedingSummaryEnabled,
      'bigPictureModeEnabled': bigPictureModeEnabled,
      'boxSortOrder': boxSortOrder,
    };
  }

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    return BackupSettings(
      scope: json['scope'] as String? ?? 'personal',
      themeMode: json['themeMode'] as String,
      accent: json['accent'] as String,
      language: json['language'] as String? ?? 'system',
      animalNameOrder: json['animalNameOrder'] as String? ?? 'commonNameFirst',
      animalSortOrder:
          json['animalSortOrder'] as String? ?? 'createdOldestFirst',
      animalCategoryViewEnabled:
          json['animalCategoryViewEnabled'] as bool? ??
          const {
            'categoryAscending',
            'categoryDescending',
          }.contains(json['animalSortOrder']),
      nextFeedingSummaryEnabled:
          json['nextFeedingSummaryEnabled'] as bool? ?? false,
      bigPictureModeEnabled: json['bigPictureModeEnabled'] as bool? ?? false,
      boxSortOrder: json['boxSortOrder'] as String? ?? 'labelAscending',
    );
  }
}
