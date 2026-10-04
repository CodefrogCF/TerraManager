import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/feeding_weekday_schedule.dart';
import 'feeding_browser_time_zone_stub.dart'
    if (dart.library.js_interop) 'feeding_browser_time_zone_web.dart'
    as web;

/// Returns the current IANA zone, or null when it cannot be determined.
Future<String?> currentFeedingTimeZone() async {
  String? value;
  if (kIsWeb) {
    try {
      value = web.browserFeedingTimeZone();
    } catch (_) {
      return null;
    }
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      value = await const MethodChannel('com.codefrog.terramanager/browser')
          .invokeMethod<String>('deviceTimeZoneId');
    } on PlatformException {
      // An unavailable device zone must not silently become UTC.
    } on MissingPluginException {
      // Widget tests and unsupported platforms have no reliable IANA zone.
    } catch (_) {
      return null;
    }
  }
  return value != null && FeedingWeekdaySchedule.isValidTimeZone(value)
      ? value
      : null;
}

/// Preserve an existing weekly plan's zone when editing it on another device.
Future<String?> resolveFeedingTimeZone(String? existing) async {
  if (existing != null) {
    return FeedingWeekdaySchedule.isValidTimeZone(existing) ? existing : null;
  }
  return currentFeedingTimeZone();
}
