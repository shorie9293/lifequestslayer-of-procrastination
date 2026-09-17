import 'package:rpg_todo/features/battle/domain/battle_record.dart';

/// 討伐戦績の集計結果（改善提案 #56）。
///
/// 状態・IO・乱数を持たない純粋な値オブジェクト。
/// [BattleRecordService.summarize] が生成する。
class BattleRecordSummary {
  /// 記録された討伐の総件数。
  final int total;

  /// 勝利件数。
  final int wins;

  /// 敗北件数。
  final int losses;

  /// 勝率（0.0〜1.0）。記録が無い場合は 0.0。
  final double winRate;

  /// 勝率のパーセント表現（0〜100 の整数・四捨五入）。
  final int winRatePercent;

  /// 現在の連勝数（最新が敗北なら 0）。
  final int currentWinStreak;

  /// 現在の連敗数（最新が勝利なら 0）。
  final int currentLoseStreak;

  /// 歴代最長の連勝数。
  final int longestWinStreak;

  /// 歴代最長の連敗数。
  final int longestLoseStreak;

  /// 戦績が1件でも存在するか。
  final bool hasRecords;

  /// 最新の戦績1件（無ければ null）。
  final BattleRecord? lastRecord;

  const BattleRecordSummary({
    required this.total,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.winRatePercent,
    required this.currentWinStreak,
    required this.currentLoseStreak,
    required this.longestWinStreak,
    required this.longestLoseStreak,
    required this.hasRecords,
    required this.lastRecord,
  });
}
