/// 勤行の習慣カレンダー（道標§五 #31）の表示モデル。
///
/// 「連続勤行日数（ストリーク）」と「日別の出席マップ」を俯瞰するための
/// 不変モデル。状態・IO・乱数を持たず、純粋サービスで構築する。
library;

/// カレンダー上の1日。
class HabitDay {
  /// この日の日付（年月日のみ有効）。
  final DateTime date;

  /// この日に行われた勤行・討伐の合計件数。
  final int activityCount;

  /// 観測基準日（[HabitCalendarService] に渡した now）と同一の日か。
  final bool isToday;

  const HabitDay({
    required this.date,
    required this.activityCount,
    this.isToday = false,
  });

  /// 何らかの活動があったか。
  bool get isActive => activityCount > 0;

  /// 曜日（0=日, 1=月, ..., 6=土）。日曜始まりのグリッド配置用。
  int get weekday => date.weekday % 7;

  String get label => '${date.day}';
}

/// 1か月分の出席マップ。
class HabitMonth {
  final int year;
  final int month;

  /// 先頭の空白（月初の曜日合わせ）と末尾パディング（7の倍数化）を含む
  /// セル列。null は「月外の空白セル」を表す。
  final List<HabitDay?> cells;

  /// この月のうち、観測基準日までに経過した日数。
  /// 当月の達成率が「途中経過で不当に低く出る」のを防ぐための分母。
  final int elapsedDays;

  const HabitMonth({
    required this.year,
    required this.month,
    required this.cells,
    required this.elapsedDays,
  });

  /// 実在する日のみ。長さは月の日数に一致する。
  List<HabitDay> get days => cells.whereType<HabitDay>().toList();

  int get daysInMonth => days.length;

  /// 活動があった日数。
  int get activeDays => days.where((d) => d.isActive).length;

  /// 経過日数に対する達成率（0.0〜1.0）。経過日数0なら0。
  double get completionRate =>
      elapsedDays <= 0 ? 0.0 : (activeDays / elapsedDays).clamp(0.0, 1.0);

  /// この月に活動が一件も無いか。
  bool get isEmpty => activeDays == 0;

  /// 先頭の空白セル数（月初の曜日）。
  int get leadingBlanks => cells.takeWhile((c) => c == null).length;

  String get label => '$year年$month月';
}

/// 勤行カレンダー全体（対象月＋通算ストリーク）。
class HabitCalendar {
  final HabitMonth month;

  /// 今日時点の連続勤行日数。今日が未活動なら昨日を起点に数える
  /// （今日はまだ終わっていないため）。昨日も未活動なら0。
  final int currentStreak;

  /// 全期間の最長連続勤行日数。
  final int longestStreak;

  /// 全期間の活動日数（未来日付は除外）。
  final int totalActiveDays;

  const HabitCalendar({
    required this.month,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
  });

  bool get isEmpty => totalActiveDays == 0;
}
