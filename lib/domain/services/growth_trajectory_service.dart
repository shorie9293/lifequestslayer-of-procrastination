import 'package:rpg_todo/domain/models/growth_trajectory.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// 成長軌跡（レベル/EXP/勤行完了数/討伐勝利数の時系列推移）を算出する純粋サービス。
///
/// 道標§五 #26 の中核ロジック。状態・IO・乱数を持たず、テスト可能。
///
/// 時系列の元データ:
/// - 勤行完了数: [Task.lastCompletedAt]（クエスト完了日時）
/// - 討伐勝利数: [Reflection.date]（討伐後の振り返り記録日時）
///
/// レベル/EXPそのものは履歴を保持していないため、成長の量的指標として
/// 「累積完了数」「累積討伐数」を時系列で描画する（現在のLv/EXPは画面側で
/// スナップショット表示する）。
class GrowthTrajectoryService {
  /// 既定の表示窓（月数）。
  static const int defaultWindowMonths = 12;

  const GrowthTrajectoryService();

  /// 直近 [months] か月（[now] の月を含む）の成長軌跡を算出する。
  ///
  /// 累積値は**窓の外の過去も含めて**全期間から算出するため、途中の月を
  /// 表示しても累積線の絶対値は正しい。[months] は1以上であること。
  /// 未来日付の記録は無視する。
  static GrowthTrajectory compute({
    required List<Task> tasks,
    required List<Reflection> reflections,
    required DateTime now,
    int months = defaultWindowMonths,
  }) {
    if (months < 1) {
      throw ArgumentError.value(months, 'months', 'must be >= 1');
    }

    final questDates = <DateTime>[
      for (final t in tasks)
        if (t.lastCompletedAt != null) t.lastCompletedAt!,
    ];
    final defeatDates = <DateTime>[
      for (final r in reflections) r.date,
    ];

    // 窓の先頭月（古い側）を求める。
    final start = _shiftMonth(now.year, now.month, -(months - 1));
    final nowIndex = _monthIndex(now.year, now.month);

    final points = <GrowthMonthlyPoint>[];
    for (var i = 0; i < months; i++) {
      final ym = _shiftMonth(start.year, start.month, i);
      final index = _monthIndex(ym.year, ym.month);

      final quests = _countInMonth(questDates, ym.year, ym.month);
      final defeats = _countInMonth(defeatDates, ym.year, ym.month);

      points.add(GrowthMonthlyPoint(
        year: ym.year,
        month: ym.month,
        questsCompleted: quests,
        defeats: defeats,
        cumulativeQuests: _countUpTo(questDates, index, nowIndex),
        cumulativeDefeats: _countUpTo(defeatDates, index, nowIndex),
      ));
    }

    return GrowthTrajectory(
      points: points,
      totalQuestsCompleted:
          questDates.where((d) => !_isFuture(d, nowIndex)).length,
      totalDefeats: defeatDates.where((d) => !_isFuture(d, nowIndex)).length,
      activeMonths: points.where((p) => !p.isEmpty).length,
      longestActiveStreak: _longestStreak(points),
      bestMonth: _bestMonth(points),
    );
  }

  // ── 内部ヘルパ ──

  static int _monthIndex(int year, int month) => year * 12 + (month - 1);

  static ({int year, int month}) _shiftMonth(int year, int month, int delta) {
    final total = _monthIndex(year, month) + delta;
    return (year: total ~/ 12, month: total % 12 + 1);
  }

  static bool _isFuture(DateTime d, int nowIndex) =>
      _monthIndex(d.year, d.month) > nowIndex;

  static int _countInMonth(
    List<DateTime> dates,
    int year,
    int month,
  ) {
    var count = 0;
    for (final d in dates) {
      if (d.year == year && d.month == month) count++;
    }
    return count;
  }

  /// [index] 月末までの累積件数（未来日付は含めない）。
  static int _countUpTo(List<DateTime> dates, int index, int nowIndex) {
    var count = 0;
    for (final d in dates) {
      final idx = _monthIndex(d.year, d.month);
      if (idx <= index && idx <= nowIndex) count++;
    }
    return count;
  }

  static int _longestStreak(List<GrowthMonthlyPoint> points) {
    var longest = 0;
    var current = 0;
    for (final p in points) {
      if (p.isEmpty) {
        current = 0;
      } else {
        current++;
        if (current > longest) longest = current;
      }
    }
    return longest;
  }

  static GrowthMonthlyPoint? _bestMonth(List<GrowthMonthlyPoint> points) {
    GrowthMonthlyPoint? best;
    for (final p in points) {
      if (p.isEmpty) continue;
      if (best == null || p.activity >= best.activity) best = p;
    }
    return best;
  }
}
