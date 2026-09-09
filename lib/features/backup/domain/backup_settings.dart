class BackupSettings {
  final String themeMode;
  final String accent;
  final String language;
  final String animalNameOrder;
  final String boxSortOrder;

  const BackupSettings({
    required this.themeMode,
    required this.accent,
    this.language = 'system',
    this.animalNameOrder = 'commonNameFirst',
    this.boxSortOrder = 'createdOldestFirst',
  });

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode,
      'accent': accent,
      'language': language,
      'animalNameOrder': animalNameOrder,
      'boxSortOrder': boxSortOrder,
    };
  }

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    return BackupSettings(
      themeMode: json['themeMode'] as String,
      accent: json['accent'] as String,
      language: json['language'] as String? ?? 'system',
      animalNameOrder: json['animalNameOrder'] as String? ?? 'commonNameFirst',
      boxSortOrder: json['boxSortOrder'] as String? ?? 'createdOldestFirst',
    );
  }
}
