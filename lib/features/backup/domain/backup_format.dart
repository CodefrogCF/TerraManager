class BackupFormat {
  BackupFormat._();

  static const int currentVersion = 2;
  static const int minimumSupportedVersion = 1;

  static bool isSupportedVersion(int version) {
    return version >= minimumSupportedVersion && version <= currentVersion;
  }

  static const String fileExtension = 'tmbackup';

  static const String manifestFileName = 'manifest.json';
  static const String dataFileName = 'data.json';
  static const String settingsFileName = 'settings.json';

  static const String mediaDirectory = 'media';
  static const String animalMediaDirectory = 'media/animals';
  static const String boxMediaDirectory = 'media/boxes';
}
