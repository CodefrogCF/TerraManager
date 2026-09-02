class BackupFormat {
  BackupFormat._();

  static const int currentVersion = 1;

  static const String fileExtension = 'tmbackup';

  static const String manifestFileName = 'manifest.json';
  static const String dataFileName = 'data.json';
  static const String settingsFileName = 'settings.json';

  static const String mediaDirectory = 'media';
  static const String animalMediaDirectory = 'media/animals';
}
