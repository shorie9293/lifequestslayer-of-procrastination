// 寄合所のグルーピング（純粋関数）。
//
// 画面はここで作った「パネル（見出し＋クエスト群）」を並べるだけにする。
// 期限の境界判定・見積の合計・内訳は全てこの層で試練する。

import 'package:rpg_todo/domain/models/task.dart';

/// 寄合所の並べ方。
enum QuestGroupMode {
  deadline('期日'),
  rank('ランク');

  const QuestGroupMode(this.label);
  final String label;
}

/// 寄合所の表示形式（一覧 / カレンダー）。
enum QuestViewMode {
  list('一覧'),
  calendar('カレンダー');

  const QuestViewMode(this.label);
  final String label;
}

/// パネルの種類（並び順の正は [groupQuests] が決める）。
enum QuestGroupBand {
  overdue,
  today,
  tomorrow,
  thisWeek,
  later,
  none,
  rankS,
  rankA,
  rankB,
}

/// 1つのパネル。
class QuestGroup {
  const QuestGroup({
    required this.band,
    required this.label,
    required this.tasks,
  });

  /// 折りたたみ状態の識別子（band.name と一致）。
  final QuestGroupBand band;
  final String label;
  final List<Task> tasks;

  String get id => band.name;
  int get count => tasks.length;

  /// 見積の合計（分）。未設定は0として数える。
  int get totalEstimateMinutes =>
      tasks.fold(0, (sum, t) => sum + (t.targetTimeMinutes ?? 0));

  /// ランクの内訳（例: S1・A2）。0件のランクは出さない。
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

  /// 見出しの補足（例: 「見積 1h20m」）。見積が無ければ「—」。
  String get estimateLabel =>
      totalEstimateMinutes <= 0 ? '—' : formatEstimate(totalEstimateMinutes);

  /// 見出しに出す補足の合成（期限パネルは内訳、ランクパネルは見積）。
  String get summary => rankBreakdown.isEmpty
      ? estimateLabel
      : '$rankBreakdown ・ $estimateLabel';
}

/// 分を「1h20m」「45分」の形へ。
String formatEstimate(int minutes) {
  if (minutes <= 0) return '—';
  if (minutes < 60) return '$minutes分';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}m';
}

int _rankWeight(QuestRank rank) => switch (rank) {
      QuestRank.S => 3,
      QuestRank.A => 2,
      QuestRank.B => 1,
    };

int _compareDeadline(Task a, Task b) {
  final da = a.deadline;
  final db = b.deadline;
  if (da == null && db == null) {
    final r = _rankWeight(b.rank).compareTo(_rankWeight(a.rank));
    return r != 0 ? r : a.title.compareTo(b.title);
  }
  if (da == null) return 1;
  if (db == null) return -1;
  final cmp = da.compareTo(db);
  return cmp != 0 ? cmp : a.title.compareTo(b.title);
}

String _mmdd(DateTime d) => '${d.month}/${d.day}';

/// クエストを寄合所のパネルへ束ねる。
///
/// - 期限なしは最後に沈める（既定は期限順）。
/// - 空のパネルは返さない。
/// - 期限切れは「期限切れ」として最上段に出す（延鬼を隠さない）。
List<QuestGroup> groupQuests(
  List<Task> tasks, {
  required QuestGroupMode mode,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final sorted = List<Task>.from(tasks)..sort(_compareDeadline);

  if (mode == QuestGroupMode.rank) {
    final byRank = <QuestRank, List<Task>>{};
    for (final t in sorted) {
      byRank.putIfAbsent(t.rank, () => <Task>[]).add(t);
    }
    const bands = <QuestRank, QuestGroupBand>{
      QuestRank.S: QuestGroupBand.rankS,
      QuestRank.A: QuestGroupBand.rankA,
      QuestRank.B: QuestGroupBand.rankB,
    };
    return [
      for (final rank in QuestRank.values)
        if ((byRank[rank] ?? const <Task>[]).isNotEmpty)
          QuestGroup(
            band: bands[rank]!,
            label: '${rank.name} 級',
            tasks: byRank[rank]!,
          ),
    ];
  }

  final startOfToday = DateTime(clock.year, clock.month, clock.day);
  final endOfToday = startOfToday.add(const Duration(days: 1));
  final endOfTomorrow = endOfToday.add(const Duration(days: 1));
  // 週の終わり＝次の日曜 23:59（今日が日曜なら今日まで）。
  final daysToSunday = (DateTime.sunday - clock.weekday) % 7;
  final endOfWeek = startOfToday.add(Duration(days: daysToSunday + 1));

  final buckets = <QuestGroupBand, List<Task>>{};
  void add(QuestGroupBand band, Task task) =>
      buckets.putIfAbsent(band, () => <Task>[]).add(task);

  for (final t in sorted) {
    final d = t.deadline;
    if (d == null) {
      add(QuestGroupBand.none, t);
    } else if (d.isBefore(clock)) {
      add(QuestGroupBand.overdue, t);
    } else if (d.isBefore(endOfToday)) {
      add(QuestGroupBand.today, t);
    } else if (d.isBefore(endOfTomorrow)) {
      add(QuestGroupBand.tomorrow, t);
    } else if (d.isBefore(endOfWeek)) {
      add(QuestGroupBand.thisWeek, t);
    } else {
      add(QuestGroupBand.later, t);
    }
  }

  String labelFor(QuestGroupBand band) => switch (band) {
        QuestGroupBand.overdue => '期限切れ',
        QuestGroupBand.today => '今日（${_mmdd(startOfToday)}）',
        QuestGroupBand.tomorrow =>
          '明日（${_mmdd(startOfToday.add(const Duration(days: 1)))}）',
        QuestGroupBand.thisWeek =>
          '今週（〜${_mmdd(endOfWeek.subtract(const Duration(seconds: 1)))}）',
        QuestGroupBand.later => 'それ以降',
        QuestGroupBand.none => '期限なし',
        _ => '',
      };

  const order = <QuestGroupBand>[
    QuestGroupBand.overdue,
    QuestGroupBand.today,
    QuestGroupBand.tomorrow,
    QuestGroupBand.thisWeek,
    QuestGroupBand.later,
    QuestGroupBand.none,
  ];

  return [
    for (final band in order)
      if ((buckets[band] ?? const <Task>[]).isNotEmpty)
        QuestGroup(
          band: band,
          label: labelFor(band),
          tasks: buckets[band]!,
        ),
  ];
}
