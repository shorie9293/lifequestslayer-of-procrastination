/// 勤行リマインダーの純粋スケジュール計算サービス。
///
/// Flutter / IO 依存なし。全メソッドは入力のみから決定的に算出する。
library;

import 'reminder_settings.dart';

class ReminderScheduleService {
  const ReminderScheduleService();

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  /// [now] 以降で次に通知が発火する時刻。
  /// 無効または通知日なし（weekdays 空）なら null。
  DateTime? nextOccurrence(ReminderSettings s, DateTime now) {
    if (!s.enabled || s.weekdays.isEmpty) return null;
    final todayAtTime =
        DateTime(now.year, now.month, now.day, s.hour, s.minute);
    if (s.weekdays.contains(now.weekday) && !now.isAfter(todayAtTime)) {
      return todayAtTime;
    }
    for (var i = 1; i <= 7; i++) {
      final day = todayAtTime.add(Duration(days: i));
      if (s.weekdays.contains(day.weekday)) {
        return DateTime(day.year, day.month, day.day, s.hour, s.minute);
      }
    }
    return null;
  }

  /// [day] の日が通知対象曜日か。
  bool occursOn(ReminderSettings s, DateTime day) =>
      s.weekdays.contains(day.weekday);

  /// [now] 時点で本日の通知時刻が到来しているか。
  bool isReminderDue(ReminderSettings s, DateTime now) {
    if (!s.enabled || !occursOn(s, now)) return false;
    final todayAtTime =
        DateTime(now.year, now.month, now.day, s.hour, s.minute);
    return now.isAfter(todayAtTime) ||
        (now.year == todayAtTime.year &&
            now.month == todayAtTime.month &&
            now.day == todayAtTime.day &&
            now.hour == todayAtTime.hour &&
            now.minute == todayAtTime.minute);
  }

  /// 通知すべきか: 有効・本日対象曜日・時刻到来・本日の勤行が未完了。
  bool shouldNotify({
    required ReminderSettings settings,
    required DateTime now,
    DateTime? lastCompletedAt,
  }) {
    if (!isReminderDue(settings, now)) return false;
    if (lastCompletedAt != null && isSameDay(lastCompletedAt, now)) {
      return false;
    }
    return true;
  }

  /// 同一日か（ローカル日付単位の比較）。
  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 曜日リストの表示ラベル。
  /// 空→'なし'、7件→'毎日'、[1..5]→'平日'、[6,7]→'土日'、
  /// それ以外→'月・水・金' 形式。
  String weekdayLabel(List<int> weekdays) {
    if (weekdays.isEmpty) return 'なし';
    if (weekdays.length == 7) return '毎日';
    if (_listEquals(weekdays, const [1, 2, 3, 4, 5])) return '平日';
    if (_listEquals(weekdays, const [6, 7])) return '土日';
    final sorted = List<int>.of(weekdays)..sort();
    return sorted.map((w) => _weekdayLabels[w - 1]).join('・');
  }

  /// 'HH:mm' 形式（ゼロ埋め）。
  String timeLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 現在時刻より後の発火時刻を [count] 件、昇順で返す。
  /// [count] < 1 は ArgumentError。
  List<DateTime> upcomingOccurrences(
    ReminderSettings s,
    DateTime now,
    int count,
  ) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', '1以上を指定せよ');
    }
    final result = <DateTime>[];
    var cursor = now;
    while (result.length < count) {
      final next = nextOccurrence(s, cursor);
      if (next == null) break;
      result.add(next);
      cursor = next.add(const Duration(minutes: 1));
    }
    return result;
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
