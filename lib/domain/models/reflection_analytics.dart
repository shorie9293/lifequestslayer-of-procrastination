/// 1か月分の振り返り件数（時系列俯瞰用の月別バケット）。
class ReflectionMonthlyCount {
  final int year;
  final int month; // 1-12
  final int count;

  const ReflectionMonthlyCount({
    required this.year,
    required this.month,
    required this.count,
  });
}

/// 残心の質的内訳（会心/戒め/未指定）。
class ReflectionSentimentBreakdown {
  final int kaishin;
  final int imashime;
  final int unspecified;

  int get total => kaishin + imashime + unspecified;

  const ReflectionSentimentBreakdown({
    this.kaishin = 0,
    this.imashime = 0,
    this.unspecified = 0,
  });
}

/// 振り返り（残心）の蓄積を月間/年間で俯瞰するための解析結果。
///
/// [ReflectionAnalyticsService] が純粋関数として算出する不変の値オブジェクト。
class ReflectionAnalytics {
  /// 対象期間（直近Nか月）のバケット。古い順に並ぶ。0件の月も含む。
  final List<ReflectionMonthlyCount> lastMonths;

  /// 当年（now.year）の振り返り総数。
  final int currentYearTotal;

  /// 前年（now.year - 1）の振り返り総数。
  final int previousYearTotal;

  /// lastMonths 内で振り返りが1件以上ある月数（活動の広がり）。
  final int activeMonths;

  /// 現在から遡った、振り返りのある月が連続する最長の月数（継続傾向）。
  final int currentMonthlyStreak;

  /// 残心の質的内訳。
  final ReflectionSentimentBreakdown sentiment;

  /// 全振り返り総数。
  final int totalCount;

  const ReflectionAnalytics({
    required this.lastMonths,
    required this.currentYearTotal,
    required this.previousYearTotal,
    required this.activeMonths,
    required this.currentMonthlyStreak,
    required this.sentiment,
    required this.totalCount,
  });
}
