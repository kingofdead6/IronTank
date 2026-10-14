import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the rest-timer alarm so it fires (with sound + vibration) even
/// when the app is backgrounded or the screen is locked.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  bool _exactAllowed = false;

  static const _restId = 4201;
  static const _channelId = 'rest_timer';
  static const _channelName = 'Rest timer';

  /// Safe to call repeatedly; failures (e.g. in tests) leave the service inert.
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested when the first workout starts, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Alerts you when your rest between sets is over',
          importance: Importance.high,
        ),
      );
      _ready = true;
    } on Object catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Asks for notification (and, on Android, exact alarm) permission.
  Future<void> requestPermissions() async {
    await init();
    if (!_ready) return;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
        await android.requestNotificationsPermission();
        _exactAllowed = await android.canScheduleExactNotifications() ?? false;
        if (!_exactAllowed) {
          await android.requestExactAlarmsPermission();
          _exactAllowed = await android.canScheduleExactNotifications() ?? false;
        }
      } else if (!kIsWeb && Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true);
      }
    } on PlatformException catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Schedules (or reschedules) the "rest over" alarm at [at].
  Future<void> scheduleRestEnd(DateTime at, {required String nextLabel, required bool sound}) async {
    await init();
    if (!_ready) return;
    await cancelRestEnd();
    if (!at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _restId,
        title: 'Rest over — time to lift',
        body: nextLabel,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        androidScheduleMode: _exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            playSound: sound,
            enableVibration: true,
            ticker: 'Rest over',
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: sound),
        ),
      );
    } on Object catch (e) {
      debugPrint('Could not schedule rest alarm: $e');
    }
  }

  Future<void> cancelRestEnd() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _restId);
    } on Object catch (e) {
      debugPrint('Could not cancel rest alarm: $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
