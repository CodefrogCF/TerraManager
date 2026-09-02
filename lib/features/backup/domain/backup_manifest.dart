class BackupManifest {
  final int backupFormatVersion;
  final String appVersion;
  final int databaseSchemaVersion;
  final DateTime createdAt;

  const BackupManifest({
    required this.backupFormatVersion,
    required this.appVersion,
    required this.databaseSchemaVersion,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'backupFormatVersion': backupFormatVersion,
      'appVersion': appVersion,
      'databaseSchemaVersion': databaseSchemaVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      backupFormatVersion: json['backupFormatVersion'] as int,
      appVersion: json['appVersion'] as String,
      databaseSchemaVersion: json['databaseSchemaVersion'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
