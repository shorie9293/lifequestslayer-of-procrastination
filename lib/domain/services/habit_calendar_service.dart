import 'package:rpg_todo/domain/models/habit_calendar.dart';

/// 勤行の習慣カレンダー（道標§五 #31）を構築する純粋サービス。
///
/// 状態・IO・乱数を持たず、テスト可能。勤行の完了履歴を表す日付リスト
/// （[Task.lastCompletedAt] と [Reflection.date] を合成したもの）から、
/// 月別の出席マップと連続日数（ストリーク）を算出する。
class HabitCalendarService {
  const HabitCalendarService();

  /// 観測日 [now] を含む月のカレンダーを構築する。
  static HabitCalendar compute({
    required List<DateTime> activityDates,
    required DateTime now,
  }) {
    return buildMonth(
      activityDates: activityDates,
      year: now.year,
      month: now.month,
      today: now,
    );
  }

  /// 指定した年月 [year]/[month] のカレンダーを構築する。
  ///
  /// [activityDates] は勤行・討伐が行われた日時のリスト（時刻は無視）。
  /// 未来日付（[today] より後）は統計から除外する。
  static HabitCalendar buildMonth({
    required List<DateTime> activityDates,
    required int year,
    required int month,
    required DateTime today,
  }) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be 1..12');
    }

    final todayKey = dayKey(today);

    // 全期間の活動日（未来を除外）を日キーに正規化。
    final allKeys = <int>{};
    for (final d in activityDates) {
      final k = dayKey(d);
      if (k <= todayKey) allKeys.add(k);
    }

    // 対象月の日別件数（未来日付は除外＝統計の整合を保つ）。
    final monthCounts = <int, int>{};
    for (final d in activityDates) {
      if (d.year == year && d.month == month && dayKey(d) <= todayKey) {
        monthCounts[d.day] = (monthCounts[d.day] ?? 0) + 1;
      }
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;
    // 月初の曜日（日曜=0）まで空白を詰める。
    final leading = DateTime(year, month, 1).weekday % 7;
    final cells = <HabitDay?>[];
    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    var elapsedDays = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      if (!date.isAfter(DateTime(today.year, today.month, today.day))) {
        elapsedDays++;
      }
      cells.add(HabitDay(
        date: date,
        activityCount: monthCounts[day] ?? 0,
        isToday: isToday,
      ));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final monthModel = HabitMonth(
      year: year,
      month: month,
      cells: cells,
      elapsedDays: elapsedDays,
    );

    return HabitCalendar(
      month: monthModel,
      currentStreak: currentStreakOf(allKeys, todayKey),
      longestStreak: longestStreakOf(allKeys),
      totalActiveDays: allKeys.length,
    );
  }

  /// 日付を日単位の連番キーへ正規化する（時刻・夏時間の影響を排除）。
  static int dayKey(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;

  /// 現在の連続日数。[todayKey] が活動日ならそこから、未活動なら昨日から遡る。
  static int currentStreakOf(Set<int> activeKeys, int todayKey) {
    var start = todayKey;
    if (!activeKeys.contains(start)) {
      start = todayKey - 1;
      if (!activeKeys.contains(start)) return 0;
    }
    var count = 0;
    var k = start;
    while (activeKeys.contains(k)) {
      count++;
      k--;
    }
    return count;
  }

  /// 全期間の最長連続日数。
  static int longestStreakOf(Set<int> activeKeys) {
    if (activeKeys.isEmpty) return 0;
    final sorted = activeKeys.toList()..sort();
    var longest = 1;
    var current = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == sorted[i - 1] + 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
    }
    return longest;
  }
}
