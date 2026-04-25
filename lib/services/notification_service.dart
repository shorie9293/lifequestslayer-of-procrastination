import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  static const _boxName = 'notification_settings';
  static const _keyEnabled = 'enabled';
  static const _keyMorningHour = 'morning_hour';
  static const _keyMorningMinute = 'morning_minute';
  static const _keyEveningHour = 'evening_hour';
  static const _keyEveningMinute = 'evening_minute';

  static const int _morningId = 1;
  static const int _eveningId = 2;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    // ローカルタイムゾーンを設定（未設定だとスケジュール通知が正しく動作しない）
    tz.setLocalLocation(tz.local);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(settings);

    // 初期化時に通知権限を要求（Android 13+必須）
    await requestPermission();
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  // --- 設定の読み書き ---

  Future<Box> _openBox() => Hive.openBox(_boxName);

  Future<bool> isEnabled() async {
    final box = await _openBox();
    return box.get(_keyEnabled, defaultValue: true) as bool;
  }

  Future<int> getMorningHour() async {
    final box = await _openBox();
    return box.get(_keyMorningHour, defaultValue: 8) as int;
  }

  Future<int> getMorningMinute() async {
    final box = await _openBox();
    return box.get(_keyMorningMinute, defaultValue: 0) as int;
  }

  Future<int> getEveningHour() async {
    final box = await _openBox();
    return box.get(_keyEveningHour, defaultValue: 21) as int;
  }

  Future<int> getEveningMinute() async {
    final box = await _openBox();
    return box.get(_keyEveningMinute, defaultValue: 0) as int;
  }

  Future<void> saveSettings({
    required bool enabled,
    required int morningHour,
    required int morningMinute,
    required int eveningHour,
    required int eveningMinute,
  }) async {
    final box = await _openBox();
    await box.putAll({
      _keyEnabled: enabled,
      _keyMorningHour: morningHour,
      _keyMorningMinute: morningMinute,
      _keyEveningHour: eveningHour,
      _keyEveningMinute: eveningMinute,
    });
  }

  // --- 通知スケジュール ---

  Future<void> scheduleAll() async {
    final enabled = await isEnabled();
    if (!enabled) {
      await cancelAll();
      return;
    }
    await _scheduleMorning(
      hour: await getMorningHour(),
      minute: await getMorningMinute(),
    );
    await _scheduleEvening(
      hour: await getEveningHour(),
      minute: await getEveningMinute(),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancel(_morningId);
    await _plugin.cancel(_eveningId);
  }

  Future<void> _scheduleMorning({required int hour, required int minute}) async {
    await _plugin.cancel(_morningId);
    await _plugin.zonedSchedule(
      _morningId,
      '📜 ギルドより伝令！',
      '本日の依頼書が届いておるぞ！冒険者よ、今こそ立ち上がれ！',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rpg_morning',
          '朝の伝令',
          channelDescription: 'ギルドからの朝の通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleEvening({required int hour, required int minute}) async {
    await _plugin.cancel(_eveningId);
    await _plugin.zonedSchedule(
      _eveningId,
      '🍺 酒場より催促！',
      '今日の討伐報告を忘れるでないぞ！未完のクエストはないか確かめよ！',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rpg_evening',
          '夜の催促',
          channelDescription: 'ギルドからの夜の通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
