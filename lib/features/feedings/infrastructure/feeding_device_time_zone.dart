import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/feeding_weekday_schedule.dart';
import 'feeding_browser_time_zone_stub.dart'
    if (dart.library.js_interop) 'feeding_browser_time_zone_web.dart'
    as web;

/// Captures the local IANA zone when a weekly plan is first configured.
Future<String> currentFeedingTimeZone() async {
  String? value;
  if (kIsWeb) {
    value = web.browserFeedingTimeZone();
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      value = await const MethodChannel('com.codefrog.terramanager/browser')
          .invokeMethod<String>('deviceTimeZoneId');
    } on PlatformException {
      // The selector still works on platforms without the Android channel.
    } on MissingPluginException {
      // Widget tests and unsupported platforms use UTC until configured.
    }
  }
  return value != null && FeedingWeekdaySchedule.isValidTimeZone(value)
      ? value
      : 'UTC';
}
