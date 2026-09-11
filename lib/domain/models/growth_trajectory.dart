/// 成長軌跡の月次バケット（時系列俯瞰用）。
///
/// 「勤行完了数」と「討伐勝利数」を月ごとに集計し、全期間累積値も保持する。
/// 道標§五 #26（成長軌跡の量的可視化）の中核値オブジェクト。
class GrowthMonthlyPoint {
  final int year;
  final int month; // 1-12

  /// 当月のクエスト完了数（勤行）。
  final int questsCompleted;

  /// 当月の討伐勝利数（振り返り/残心の記録件数）。
  final int defeats;

  /// 全期間の累積完了数（この月の末日時点）。
  final int cumulativeQuests;

  /// 全期間の累積討伐勝利数（この月の末日時点）。
  final int cumulativeDefeats;

  const GrowthMonthlyPoint({
    required this.year,
    required this.month,
    required this.questsCompleted,
    required this.defeats,
    required this.cumulativeQuests,
    required this.cumulativeDefeats,
  });

  /// 軸ラベル用の短い表記（例: 8月）。
  String get label => '$month月';

  /// 当月の活動量（完了＋討伐）。
  int get activity => questsCompleted + defeats;

  /// 当月に活動が一切なかったか。
  bool get isEmpty => questsCompleted == 0 && defeats == 0;

  @override
  String toString() =>
      'GrowthMonthlyPoint($year-$month, quests=$questsCompleted, '
      'defeats=$defeats, cumQ=$cumulativeQuests, cumD=$cumulativeDefeats)';
}

/// 成長軌跡の集計結果。
///
/// [GrowthTrajectoryService.compute] が純粋関数として算出する不変オブジェクト。
class GrowthTrajectory {
  /// 直近Nか月のバケット（古い順）。0件の月も含む。
  final List<GrowthMonthlyPoint> points;

  /// 全期間の累積クエスト完了数。
  final int totalQuestsCompleted;

  /// 全期間の累積討伐勝利数。
  final int totalDefeats;

  /// [points] 内で活動のあった月数。
  final int activeMonths;

  /// [points] 内で活動が連続した最長月数。
  final int longestActiveStreak;

  /// [points] 内で最も活動量が多かった月（同点なら新しい月を優先）。活動ゼロならnull。
  final GrowthMonthlyPoint? bestMonth;

  const GrowthTrajectory({
    required this.points,
    required this.totalQuestsCompleted,
    required this.totalDefeats,
    required this.activeMonths,
    required this.longestActiveStreak,
    this.bestMonth,
  });

  /// 対象期間に活動が一切ないか。
  bool get isEmpty => points.every((p) => p.isEmpty);

  /// 対象期間の月数。
  int get windowMonths => points.length;

  /// 対象期間内のクエスト完了合計。
  int get windowQuestsCompleted =>
      points.fold(0, (sum, p) => sum + p.questsCompleted);

  /// 対象期間内の討伐勝利合計。
  int get windowDefeats => points.fold(0, (sum, p) => sum + p.defeats);
}
