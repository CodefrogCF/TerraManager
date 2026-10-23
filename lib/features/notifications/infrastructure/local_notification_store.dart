import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalNotificationStore {
  Future<String?> read();
  Future<void> write(String value);
}

/// Device preference and delivery ledger; deliberately outside portable backups.
class PreferenceNotificationStore implements LocalNotificationStore {
  static const key = 'local_feeding_notifications_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Could not save device notification settings');
    }
  }
}
