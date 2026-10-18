/// iCalendar の 1 イベント（日付のみ意味を持つ終日イベント）。
class CalendarEvent {
  const CalendarEvent({
    required this.uid,
    required this.date,
    required this.summary,
    this.description,
  });

  final String uid;

  /// 日付のみ意味を持つ（時刻は無視される）。
  final DateTime date;
  final String summary;
  final String? description;

  /// 'YYYYMMDD'（ゼロ埋め）。
  String get dateStamp => '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}
