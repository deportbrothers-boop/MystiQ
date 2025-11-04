import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _dailyEnabledKey = 'dailyNotifEnabled';

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

    // iOS izinleri
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+ çalışma zamanı izni (varsa)
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}

    // Timezone init (zonedSchedule için)
    try { tz.initializeTimeZones(); } catch (_) {}
  }

  static Future<void> setDailyEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_dailyEnabledKey, enabled);
    if (enabled) {
      await scheduleDaily(const TimeOfDay(hour: 9, minute: 0));
    } else {
      await _plugin.cancel(1001);
    }
  }

  static Future<bool> isDailyEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_dailyEnabledKey) ?? false;
  }

  static Future<void> scheduleDaily(TimeOfDay time) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('mystiq_daily', 'Daily', importance: Importance.defaultImportance),
      iOS: DarwinNotificationDetails(),
    );
    try {
      final next = _nextInstanceOf(time);
      await _plugin.zonedSchedule(
        1001,
        'MystiQ',
        'Bugünün enerjisini keşfet',
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  static Future<void> scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required int secondsFromNow,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('mystiq_one_shot', 'OneShot', importance: Importance.defaultImportance),
      iOS: DarwinNotificationDetails(),
    );
    try {
      final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static Future<void> cancelOneShot(int id) async {
    try { await _plugin.cancel(id); } catch (_) {}
  }

  static tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
