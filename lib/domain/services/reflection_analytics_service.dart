import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/reflection_analytics.dart';

/// 振り返り（残心）の質的蓄積を月間/年間で時系列俯瞰するための解析サービス。
///
/// 純粋関数 [compute] で、与えられた [List<Reflection>] と基準日 [now] から
/// [ReflectionAnalytics] を算出する。状態・IOを持たず、テスト可能。
///
/// 道標§五 #24（振り返りの質的蓄積ダッシュボード）の中核解析ロジック。
class ReflectionAnalyticsService {
  static const int defaultWindowMonths = 12;

  /// 会心（良い内省）のsentiment文字列。
  static const String sentimentKaishin = 'kaishin';

  /// 戒め（改善内省）のsentiment文字列。
  static const String sentimentImashime = 'imashime';

  /// 直近 [months] か月（now の月を含む）で振り返りを集計する。
  ///
  /// [months] は1以上であること（それ以下は常に空結果の可能性があるため呼出側で制約）。
  static ReflectionAnalytics compute({
    required List<Reflection> reflections,
    required DateTime now,
    int months = defaultWindowMonths,
  }) {
    // ── 月別バケット（直近 months か月、古い順）──
    final buckets = <ReflectionMonthlyCount>[];
    final anchorYear = now.year;
    final anchorMonth = now.month;
    for (int i = months - 1; i >= 0; i--) {
      final ym = _shiftMonth(anchorYear, anchorMonth, -i);
      final count = reflections
          .where((r) => r.date.year == ym.year && r.date.month == ym.month)
          .length;
      buckets.add(ReflectionMonthlyCount(
        year: ym.year,
        month: ym.month,
        count: count,
      ));
    }

    final lastMonths = buckets;

    // ── 年間集計 ──
    final currentYearTotal = reflections
        .where((r) => r.date.year == now.year)
        .length;
    final previousYearTotal = reflections
        .where((r) => r.date.year == now.year - 1)
        .length;

    // ── 活動の広がり ──
    final activeMonths = lastMonths.where((m) => m.count > 0).length;

    // ── 継続傾向（最新の活動月から遡る連続run）──
    int currentMonthlyStreak = 0;
    for (int i = lastMonths.length - 1; i >= 0; i--) {
      if (lastMonths[i].count > 0) {
        currentMonthlyStreak++;
      } else if (currentMonthlyStreak > 0) {
        // 一度runに入って途切れたら終了（未来側の空月はrunに含めない）
        break;
      }
    }

    // ── 質的内訳（sentiment）──
    var kaishin = 0;
    var imashime = 0;
    var unspecified = 0;
    for (final r in reflections) {
      if (r.sentiment == sentimentKaishin) {
        kaishin++;
      } else if (r.sentiment == sentimentImashime) {
        imashime++;
      } else {
        unspecified++;
      }
    }

    return ReflectionAnalytics(
      lastMonths: lastMonths,
      currentYearTotal: currentYearTotal,
      previousYearTotal: previousYearTotal,
      activeMonths: activeMonths,
      currentMonthlyStreak: currentMonthlyStreak,
      sentiment: ReflectionSentimentBreakdown(
        kaishin: kaishin,
        imashime: imashime,
        unspecified: unspecified,
      ),
      totalCount: reflections.length,
    );
  }

  /// (year, month) を n か月ずらす（年跨ぎ対応）。
  static ({int year, int month}) _shiftMonth(
    int year,
    int month,
    int delta,
  ) {
    final total = year * 12 + (month - 1) + delta;
    final y = total ~/ 12;
    final m = (total % 12) + 1;
    return (year: y, month: m);
  }
}
