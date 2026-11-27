// 寄合所のカレンダー表示（純粋関数）。
//
// 画面はここで作った 6週×7日 のマス目を描くだけにする。
// 月初・月末・閏年・週の開始曜日の境界は全てこの層で試練する。
//
// 不変条件:
// - 常に 42 マス（6週）。月によって高さが変わると、月送りで画面が跳ねる。
// - 週の開始は日曜（日本の暦の慣習に合わせる）。
// - 期限の無いクエストはマスに入れず [QuestCalendarMonth.undated] に分ける。
// - 例外を投げない（壊れた日付・null は静かに落とす）。

import 'package:rpg_todo/domain/models/task.dart';

/// カレンダーの1マス（1日）。
class QuestCalendarCell {
  const QuestCalendarCell({
    required this.date,
    required this.inMonth,
    required this.tasks,
  });

  /// その日の 0:00（ローカル）。
  final DateTime date;

  /// 表示中の月に属する日か（前後の月のマスは false）。
  final bool inMonth;

  /// その日が期限のクエスト（ランク→期限→題名の順で安定）。
  final List<Task> tasks;

  int get count => tasks.length;
  bool get isEmpty => tasks.isEmpty;

  /// 表示用の識別子（yyyy-MM-dd）。
  String get id =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// その日のランク内訳（例: S1・B2）。0件なら空文字。
  String get rankBreakdown {
    final counts = <QuestRank, int>{};
    for (final t in tasks) {
      counts[t.rank] = (counts[t.rank] ?? 0) + 1;
    }
    final parts = <String>[];
    for (final rank in QuestRank.values) {
      final n = counts[rank] ?? 0;
      if (n > 0) parts.add('${rank.name}$n');
    }
    return parts.join('・');
  }
}

/// 1ヶ月分のカレンダー。
class QuestCalendarMonth {
  const QuestCalendarMonth({
    required this.month,
    required this.cells,
    required this.undated,
  });

  /// 月初の 0:00。
  final DateTime month;

  /// 42マス（6週×7日）。先頭は月初を含む週の日曜。
  final List<QuestCalendarCell> cells;

  /// 期限の無いクエスト（カレンダーに入らない）。
  final List<Task> undated;

  /// 表示中の月に属するクエストの総数。
  int get inMonthTaskCount => cells
      .where((c) => c.inMonth)
      .fold(0, (sum, c) => sum + c.count);

  /// 表示用の見出し（例: 2026年11月）。
  String get label => '${month.year}年${month.month}月';

  /// 7マスずつの週（描画用）。
  List<List<QuestCalendarCell>> get weeks {
    final result = <List<QuestCalendarCell>>[];
    for (var i = 0; i < cells.length; i += 7) {
      result.add(cells.sublist(i, (i + 7).clamp(0, cells.length)));
    }
    return result;
  }
}

/// 日付だけを取り出した 0:00。
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 月の加減算（月末を跨いでも月初へ正規化する）。
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta, 1);

/// 指定月のカレンダーを組み立てる。
///
/// [month] は任意の日付でよい（月初へ正規化する）。
QuestCalendarMonth buildQuestCalendar({
  required DateTime month,
  required List<Task> tasks,
}) {
  final first = DateTime(month.year, month.month, 1);
  // 日曜始まり: 月初の曜日は weekday(月=1..日=7) なので 日=0 に写す。
  final leading = first.weekday % 7;
  final gridStart = first.subtract(Duration(days: leading));

  final byDate = <String, List<Task>>{};
  final undated = <Task>[];
  for (final task in tasks) {
    final deadline = task.deadline;
    if (deadline == null) {
      undated.add(task);
      continue;
    }
    final key = dateOnly(deadline).toIso8601String();
    byDate.putIfAbsent(key, () => <Task>[]).add(task);
  }
  for (final list in byDate.values) {
    list.sort(_compareTask);
  }
  undated.sort(_compareTask);

  final cells = <QuestCalendarCell>[];
  for (var i = 0; i < 42; i++) {
    final date = gridStart.add(Duration(days: i));
    final key = date.toIso8601String();
    cells.add(
      QuestCalendarCell(
        date: date,
        inMonth: date.year == first.year && date.month == first.month,
        tasks: byDate[key] ?? const <Task>[],
      ),
    );
  }

  return QuestCalendarMonth(month: first, cells: cells, undated: undated);
}

/// マス内の並び: ランク（S→A→B）→ 期限時刻 → 題名。
int _compareTask(Task a, Task b) {
  final rankOrder = a.rank.index.compareTo(b.rank.index);
  if (rankOrder != 0) return rankOrder;
  final aDeadline = a.deadline;
  final bDeadline = b.deadline;
  if (aDeadline != null && bDeadline != null) {
    final order = aDeadline.compareTo(bDeadline);
    if (order != 0) return order;
  } else if (aDeadline != null) {
    return -1;
  } else if (bDeadline != null) {
    return 1;
  }
  return a.title.compareTo(b.title);
}
