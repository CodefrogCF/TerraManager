class BackupSettings {
  final String themeMode;
  final String accent;

  const BackupSettings({required this.themeMode, required this.accent});

  Map<String, dynamic> toJson() {
    return {'themeMode': themeMode, 'accent': accent};
  }

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    return BackupSettings(
      themeMode: json['themeMode'] as String,
      accent: json['accent'] as String,
    );
  }
}
