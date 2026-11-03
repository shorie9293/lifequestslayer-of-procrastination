/// 端末カレンダー（Android CalendarContract）から読み取った予定の値オブジェクト。
///
/// プラットフォーム非依存に保つため、`MethodChannel` の生データは
/// [LinkedCalendarEvent.fromMap] でここへ変換する。
class LinkedCalendarEvent {
  const LinkedCalendarEvent({
    required this.eventId,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location,
  });

  /// カレンダー側のイベントID（端末内で一意）。重複判定には使わない
  /// （Task に外部IDを持たせるとデータモデル変更になるため）。
  final String eventId;
  final String calendarId;
  final String title;

  /// 開始日時（ローカル時刻）。
  final DateTime start;

  /// 終了日時（ローカル時刻）。終日予定では翌日0時。
  final DateTime end;

  /// 終日予定か。
  final bool allDay;

  final String? location;

  /// 予定の長さ（分）。終了が開始以前なら 0。
  int get durationMinutes {
    final diff = end.difference(start).inMinutes;
    return diff > 0 ? diff : 0;
  }

  factory LinkedCalendarEvent.fromMap(Map<Object?, Object?> map) {
    return LinkedCalendarEvent(
      eventId: '${map['eventId'] ?? ''}',
      calendarId: '${map['calendarId'] ?? ''}',
      title: '${map['title'] ?? ''}',
      start: _toLocal(map['startMillis']),
      end: _toLocal(map['endMillis']),
      allDay: map['allDay'] == true,
      location: map['location'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'eventId': eventId,
        'calendarId': calendarId,
        'title': title,
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
        'allDay': allDay,
        'location': location,
      };

  static DateTime _toLocal(Object? millis) {
    final value = millis is int ? millis : int.tryParse('${millis ?? 0}') ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
}
