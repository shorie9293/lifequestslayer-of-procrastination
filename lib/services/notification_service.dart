import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter/foundation.dart';

class NotificationService {
  static const _boxName = 'notification_settings';
  static const _keyEnabled = 'enabled';
  static const _keyMorningHour = 'morning_hour';
  static const _keyMorningMinute = 'morning_minute';
  static const _keyEveningHour = 'evening_hour';
  static const _keyEveningMinute = 'evening_minute';

  static const int _morningId = 1;
  static const int _eveningId = 2;
  static const int _testNotificationId = 999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    tzdata.initializeTimeZones();

    // 端末の実際のタイムゾーンオフセットを取得
    final deviceOffset = DateTime.now().timeZoneOffset;
    final tzLocalOffset = tz.TZDateTime.now(tz.local).timeZoneOffset;

    debugPrint('[NotificationService] 端末オフセット: $deviceOffset');
    debugPrint('[NotificationService] tz.local: ${tz.local.name} (offset: $tzLocalOffset)');

    // tz.local が端末の実際のオフセットと一致しない場合、
    // オフセットから正しいタイムゾーンを探索して上書きする
    if (deviceOffset != tzLocalOffset) {
      final correctTzName = _findTimezoneByOffset(deviceOffset);
      if (correctTzName != null) {
        debugPrint('[NotificationService] タイムゾーンを上書き: ${tz.local.name} → $correctTzName');
        tz.setLocalLocation(tz.getLocation(correctTzName));
      } else {
        debugPrint('[NotificationService] 警告: オフセット $deviceOffset に一致するタイムゾーンが見つかりません');
      }
    } else {
      debugPrint('[NotificationService] タイムゾーンは正しいです: ${tz.local.name}');
    }

    debugPrint('[NotificationService] 使用タイムゾーン: ${tz.local.name}');
    debugPrint('[NotificationService] 現在時刻: ${tz.TZDateTime.now(tz.local)}');

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint(
          '[NotificationService] 通知タップ: id=${response.id}, payload=${response.payload}',
        );
      },
    );

    // Android 8+ 用に通知チャンネルを明示的に作成
    await _createNotificationChannels();

    // 権限リクエストは行わない（runApp()前にActivityがないためダイアログが表示できない）
    // 権限リクエストはユーザーが通知設定画面で「保存」または「テスト通知」を押した時に行う
  }

  /// Android 8+ の通知チャンネルを明示的に作成する。
  /// flutter_local_notifications は内部的にチャンネルを作成するが、
  /// 明示的に作成することで確実にチャンネルが存在することを保証する。
  Future<void> _createNotificationChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'rpg_morning',
        '朝の伝令',
        description: 'ギルドからの朝の通知',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'rpg_evening',
        '夜の催促',
        description: 'ギルドからの夜の通知',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'rpg_test',
        'テスト通知',
        description: '通知機能のテスト用',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    debugPrint('[NotificationService] 通知チャンネルを作成しました');
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      debugPrint('[NotificationService] 通知権限: $granted');
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

  /// Android 12+ で SCHEDULE_EXACT_ALARM 権限があるか確認する。
  /// 権限がない場合、正確な時刻の通知は保証されない。
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      final canSchedule = await android.canScheduleExactNotifications();
      debugPrint('[NotificationService] SCHEDULE_EXACT_ALARM 権限: $canSchedule');
      return canSchedule ?? false;
    } catch (e) {
      debugPrint('[NotificationService] SCHEDULE_EXACT_ALARM 確認エラー: $e');
      return false;
    }
  }

  /// 使用するスケジュールモードを決定する。
  /// exact 権限があれば exactAllowWhileIdle、なければ inexactAllowWhileIdle にフォールバック。
  Future<AndroidScheduleMode> _getScheduleMode() async {
    final canExact = await canScheduleExactAlarms();
    if (canExact) {
      debugPrint('[NotificationService] exact モードを使用します');
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    debugPrint('[NotificationService] inexact モードにフォールバックします');
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

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
    debugPrint('[NotificationService] 通知をスケジュールしました');
  }

  Future<void> cancelAll() async {
    await _plugin.cancel(_morningId);
    await _plugin.cancel(_eveningId);
    await _plugin.cancel(_testNotificationId);
    debugPrint('[NotificationService] 全ての通知をキャンセルしました');
  }

  Future<void> _scheduleMorning({required int hour, required int minute}) async {
    await _plugin.cancel(_morningId);
    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final scheduleMode = await _getScheduleMode();
    debugPrint(
      '[NotificationService] 朝の通知をスケジュール: $hour:$minute → $scheduledDate (mode: $scheduleMode)',
    );
    await _plugin.zonedSchedule(
      _morningId,
      '📜 ギルドより伝令！',
      '本日の依頼書が届いておるぞ！冒険者よ、今こそ立ち上がれ！',
      scheduledDate,
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
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleEvening({required int hour, required int minute}) async {
    await _plugin.cancel(_eveningId);
    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final scheduleMode = await _getScheduleMode();
    debugPrint(
      '[NotificationService] 夜の通知をスケジュール: $hour:$minute → $scheduledDate (mode: $scheduleMode)',
    );
    await _plugin.zonedSchedule(
      _eveningId,
      '🍺 酒場より催促！',
      '今日の討伐報告を忘れるでないぞ！未完のクエストはないか確かめよ！',
      scheduledDate,
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
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Android のアプリ設定画面（通知設定）を開く。
  /// ユーザーが通知権限を拒否した後に、手動で許可できるようにする。
  Future<void> openAppNotificationSettings() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await android.requestNotificationsPermission();
      debugPrint('[NotificationService] アプリ設定画面を開きました');
    } catch (e) {
      debugPrint('[NotificationService] アプリ設定画面を開けませんでした: $e');
    }
  }

  /// Android の「正確なアラーム」設定画面を開く。
  /// ユーザーが SCHEDULE_EXACT_ALARM 権限を付与できるようにする。
  Future<void> openAlarmSettings() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await android.requestExactAlarmsPermission();
      debugPrint('[NotificationService] 正確なアラーム設定画面を開きました');
    } catch (e) {
      debugPrint('[NotificationService] 正確なアラーム設定画面を開けませんでした: $e');
    }
  }

  /// テスト通知を即座に送信する。
  /// 通知機能が正しく動作しているか確認するために使用する。
  Future<void> sendTestNotification() async {
    debugPrint('[NotificationService] テスト通知を送信します');
    await _plugin.show(
      _testNotificationId,
      '🔔 テスト通知',
      '通知機能は正常に動作しています！',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rpg_test',
          'テスト通知',
          channelDescription: '通知機能のテスト用',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// 指定されたオフセットに一致するIANAタイムゾーンを探索する。
  /// 優先順位: Asia/Tokyo (JST) > Asia/Seoul > その他
  /// 完全一致するものがなければ null を返す。
  String? _findTimezoneByOffset(Duration offset) {
    // よく使われるタイムゾーンを優先的にチェック
    final preferredZones = [
      'Asia/Tokyo',
      'Asia/Seoul',
      'Asia/Shanghai',
      'Asia/Taipei',
      'Asia/Hong_Kong',
      'Asia/Singapore',
      'Asia/Kolkata',
      'Europe/London',
      'Europe/Berlin',
      'Europe/Paris',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'Pacific/Auckland',
      'Australia/Sydney',
      'UTC',
    ];

    // 優先ゾーンから一致するものを探す
    for (final zoneName in preferredZones) {
      try {
        final location = tz.getLocation(zoneName);
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == offset) {
          return zoneName;
        }
      } catch (_) {
        // 無効なゾーン名はスキップ
      }
    }

    // 全データベースから探索
    for (final entry in tz.timeZoneDatabase.locations.entries) {
      try {
        final location = entry.value;
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == offset) {
          return entry.key;
        }
      } catch (_) {
        // 無効なゾーンはスキップ
      }
    }

    return null;
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
