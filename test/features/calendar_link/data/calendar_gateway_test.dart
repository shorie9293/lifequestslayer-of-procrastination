import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/calendar_link/data/calendar_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelCalendarGateway.channelName);

  late MethodChannelCalendarGateway gateway;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    gateway = MethodChannelCalendarGateway();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  void mockHandler(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  test('Android 以外は未対応として扱い、端末APIを呼ばない', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(gateway.isSupported, isFalse);
    expect(await gateway.ensureAccess(), CalendarAccessStatus.unsupported);
    expect(
      await gateway.readEvents(from: DateTime(2026, 11, 3), to: DateTime(2026, 11, 4)),
      isEmpty,
    );
    expect(calls, isEmpty);
  });

  test('ensureAccess は granted / denied を正しく写像する', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mockHandler((call) async => call.method == 'ensureAccess' ? 'granted' : null);

    expect(await gateway.ensureAccess(), CalendarAccessStatus.granted);
    expect(calls.single.method, 'ensureAccess');
  });

  test('未知の戻り値は denied として扱う（権限なしで読ませない）', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mockHandler((call) async => 'something-else');

    expect(await gateway.ensureAccess(), CalendarAccessStatus.denied);
  });

  test('readEvents はミリ秒を送り、マップを LinkedCalendarEvent へ変換する', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final start = DateTime(2026, 11, 3, 10);
    mockHandler((call) async {
      if (call.method != 'readEvents') return null;
      return <Object?>[
        <Object?, Object?>{
          'eventId': '1',
          'calendarId': 'cal',
          'title': '朝会',
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': start.add(const Duration(minutes: 45)).millisecondsSinceEpoch,
          'allDay': false,
          'location': '会議室A',
        },
      ];
    });

    final events = await gateway.readEvents(
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 4),
    );

    expect(events.single.title, '朝会');
    expect(events.single.durationMinutes, 45);
    expect(events.single.location, '会議室A');
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['fromMillis'], DateTime(2026, 11, 3).millisecondsSinceEpoch);
    expect(args['toMillis'], DateTime(2026, 11, 4).millisecondsSinceEpoch);
  });

  test('null が返っても例外にしない（予定0件）', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mockHandler((call) async => null);

    expect(
      await gateway.readEvents(from: DateTime(2026, 11, 3), to: DateTime(2026, 11, 4)),
      isEmpty,
    );
  });
}
