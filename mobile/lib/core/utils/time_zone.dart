import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// The device's IANA time zone (e.g. "Africa/Algiers"), sent to endpoints that
/// group by calendar day. Falls back to UTC if the platform can't tell us.
final timeZoneProvider = FutureProvider<String>((ref) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object catch (e) {
    debugPrint('Time zone unavailable, using UTC: $e');
    return 'UTC';
  }
});
