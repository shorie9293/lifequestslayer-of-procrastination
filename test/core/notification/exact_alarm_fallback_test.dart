import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

void main() {
  const deadlineId = 200;

  late _MockNotificationsPlugin plugin;
  late _MockAndroidPlugin android;

  setUpAll(() {
    tzdata.initializeTimeZones();
    registerFallbackValue(tz.TZDateTime.now(tz.local));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(
      const AndroidNotificationChannel('rpg_test', 'テスト通知'),
    );
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  setUp(() {
    plugin = _MockNotificationsPlugin();
    android = _MockAndroidPlugin();
    when(() => plugin.cancel(any())).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    ).thenAnswer((_) async {});
    when(() => android.createNotificationChannel(any()))
        .thenAnswer((_) async {});
    when(() => plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()).thenReturn(android);
  });

  /// 実呼出経路（scheduleDeadlineReminder）を通して zonedSchedule の
  /// androidScheduleMode を撃つ。
  Future<void> runSchedule({required bool exactAlarmAllowed}) {
    final service = NotificationService.forTesting(
      plugin: plugin,
      exactAlarmAllowed: () async => exactAlarmAllowed,
    );
    return service.scheduleDeadlineReminder(
      hour: 7,
      minute: 30,
      title: '締切の刻',
      body: '期限間近のクエストがある',
    );
  }

  void verifyMode(AndroidScheduleMode mode) {
    verify(
      () => plugin.zonedSchedule(
        deadlineId,
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
        payload: any(named: 'payload'),
        matchDateTimeComponents: DateTimeComponents.time,
      ),
    ).called(1);
  }

  test('シーム=false なら inexactAllowWhileIdle で予約する（権限APIがtrueでも）', () async {
    // 権限APIは true を返すよう仕込む。シームが優先されなければ exact になり失敗する。
    when(() => android.canScheduleExactNotifications())
        .thenAnswer((_) async => true);

    await runSchedule(exactAlarmAllowed: false);

    verifyMode(AndroidScheduleMode.inexactAllowWhileIdle);
    verifyNever(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    );
  });

  test('シーム=true なら exactAllowWhileIdle で予約する（権限APIがfalseでも）', () async {
    // 権限APIは false を返すよう仕込む。シームが優先されなければ inexact になり失敗する。
    when(() => android.canScheduleExactNotifications())
        .thenAnswer((_) async => false);

    await runSchedule(exactAlarmAllowed: true);

    verifyMode(AndroidScheduleMode.exactAllowWhileIdle);
    verifyNever(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    );
  });

  test('シーム未指定なら実機の権限API（false）に従い inexact へフォールバックする', () async {
    when(() => android.canScheduleExactNotifications())
        .thenAnswer((_) async => false);

    final service = NotificationService.forTesting(plugin: plugin);
    await service.scheduleDeadlineReminder(
      hour: 7,
      minute: 30,
      title: '締切の刻',
      body: '期限間近のクエストがある',
    );

    verifyMode(AndroidScheduleMode.inexactAllowWhileIdle);
    verify(() => android.canScheduleExactNotifications()).called(1);
  });
}
