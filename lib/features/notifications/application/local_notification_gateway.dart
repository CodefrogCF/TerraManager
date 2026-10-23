import '../domain/feeding_notification_target.dart';

abstract interface class LocalNotificationGateway {
  bool get isSupported;
  Future<void> initialize(void Function(String?) onTap);
  Future<bool> isAllowed();
  Future<bool> requestPermission();
  Future<void> openSettings();
  Future<Set<int>> pendingIds();
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String languageCode,
    required FeedingNotificationTarget target,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
}
