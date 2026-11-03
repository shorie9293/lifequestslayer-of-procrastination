import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/linked_calendar_event.dart';

/// カレンダー読み取り権限の状態。
enum CalendarAccessStatus {
  /// 読み取り可能。
  granted,

  /// 拒否された（再要求できる）。
  denied,

  /// この端末・このプラットフォームでは未対応。
  unsupported,
}

/// 端末カレンダーへのアクセス抽象。
///
/// 実装（MethodChannel）を差し替えられるようにして、ウィジェット試練では
/// フェイクを注入する。端末APIに触るのはこの層だけ。
abstract class CalendarGateway {
  /// このプラットフォームでカレンダー連携が使えるか。
  bool get isSupported;

  /// 権限を確認し、必要なら要求する。
  Future<CalendarAccessStatus> ensureAccess();

  /// [from]〜[to] の予定を読み取る（両端を含む）。
  Future<List<LinkedCalendarEvent>> readEvents({
    required DateTime from,
    required DateTime to,
  });
}

/// 非対応プラットフォーム用（Web / Desktop / iOS）。
///
/// 例外を投げず「使えない」を返すことで、UI 側は理由表示に倒せる。
class UnsupportedCalendarGateway implements CalendarGateway {
  const UnsupportedCalendarGateway();

  @override
  bool get isSupported => false;

  @override
  Future<CalendarAccessStatus> ensureAccess() async =>
      CalendarAccessStatus.unsupported;

  @override
  Future<List<LinkedCalendarEvent>> readEvents({
    required DateTime from,
    required DateTime to,
  }) async =>
      const <LinkedCalendarEvent>[];
}

/// 端末カレンダー読み取りの失敗（権限以外の異常）。
class CalendarGatewayException implements Exception {
  const CalendarGatewayException(this.message);

  final String message;

  @override
  String toString() => 'CalendarGatewayException: $message';
}

/// Android の `CalendarBridge.kt` を叩く実装。
class MethodChannelCalendarGateway implements CalendarGateway {
  MethodChannelCalendarGateway({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.shorie.lifequest/calendar';

  final MethodChannel _channel;

  @override
  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<CalendarAccessStatus> ensureAccess() async {
    if (!isSupported) return CalendarAccessStatus.unsupported;
    final status = await _channel.invokeMethod<String>('ensureAccess');
    switch (status) {
      case 'granted':
        return CalendarAccessStatus.granted;
      case 'denied':
        return CalendarAccessStatus.denied;
      default:
        return CalendarAccessStatus.denied;
    }
  }

  @override
  Future<List<LinkedCalendarEvent>> readEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!isSupported) return const <LinkedCalendarEvent>[];
    final raw = await _channel.invokeMethod<List<Object?>>('readEvents', <String, Object?>{
      'fromMillis': from.millisecondsSinceEpoch,
      'toMillis': to.millisecondsSinceEpoch,
    });
    if (raw == null) return const <LinkedCalendarEvent>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(LinkedCalendarEvent.fromMap)
        .toList(growable: false);
  }
}
