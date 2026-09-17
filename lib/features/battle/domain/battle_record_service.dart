import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_summary.dart';

/// 討伐戦績（改善提案 #56）を扱う純粋サービス。
///
/// 状態・IO・乱数を持たず、すべて静的関数で完結する（試練可能）。
class BattleRecordService {
  const BattleRecordService._();

  /// 戦績を古い順（occurredAt 昇順・同時刻は id 昇順）に正規化する。
  static List<BattleRecord> sortedOldestFirst(List<BattleRecord> records) {
    final list = records.toList()
      ..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    return list;
  }

  /// 全戦績を集計して [BattleRecordSummary] を返す。
  ///
  /// 空リストでも例外を投げず（0除算ガード）、total=0・winRate=0.0 の要約を返す。
  /// 現在の連勝/連敗は新しい方から、最長連勝/連敗は古い方から走査して求める。
  static BattleRecordSummary summarize(List<BattleRecord> records) {
    if (records.isEmpty) {
      return const BattleRecordSummary(
        total: 0,
        wins: 0,
        losses: 0,
        winRate: 0.0,
        winRatePercent: 0,
        currentWinStreak: 0,
        currentLoseStreak: 0,
        longestWinStreak: 0,
        longestLoseStreak: 0,
        hasRecords: false,
        lastRecord: null,
      );
    }
    final oldestFirst = sortedOldestFirst(records);
    final total = oldestFirst.length;
    final wins = oldestFirst.where((r) => r.isVictory).length;
    final losses = total - wins;
    final winRate = wins / total;
    final winRatePercent = (winRate * 100).round();

    // 最長連勝/連敗: 古い方から走査して最大値を求める。
    var longestWin = 0;
    var longestLose = 0;
    var winRun = 0;
    var loseRun = 0;
    for (final r in oldestFirst) {
      if (r.isVictory) {
        winRun++;
        loseRun = 0;
      } else {
        loseRun++;
        winRun = 0;
      }
      if (winRun > longestWin) longestWin = winRun;
      if (loseRun > longestLose) longestLose = loseRun;
    }

    // 現在の連勝/連敗: 新しい方（末尾）から数える。
    var currentWin = 0;
    var currentLose = 0;
    for (var i = oldestFirst.length - 1; i >= 0; i--) {
      if (oldestFirst[i].isVictory) {
        if (currentLose > 0) break;
        currentWin++;
      } else {
        if (currentWin > 0) break;
        currentLose++;
      }
    }

    return BattleRecordSummary(
      total: total,
      wins: wins,
      losses: losses,
      winRate: winRate,
      winRatePercent: winRatePercent,
      currentWinStreak: currentWin,
      currentLoseStreak: currentLose,
      longestWinStreak: longestWin,
      longestLoseStreak: longestLose,
      hasRecords: true,
      lastRecord: oldestFirst.last,
    );
  }

  /// 新しい順（occurredAt 降順・同時刻は id 昇順）に [n] 件返す。
  /// [n] が0以下なら空リスト。
  static List<BattleRecord> recent(List<BattleRecord> records, int n) {
    if (n <= 0) return const [];
    final list = records.toList()
      ..sort((a, b) {
        final byTime = b.occurredAt.compareTo(a.occurredAt);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    return list.take(n).toList();
  }

  /// 勝敗で絞り込む（順序を保持）。
  static List<BattleRecord> filterByResult(
    List<BattleRecord> records,
    bool victory,
  ) =>
      records.where((r) => r.isVictory == victory).toList();

  /// 勝率の表示用ラベル（例: `62.5%`）。範囲外の値は 0.0〜1.0 にクランプする。
  static String winRateLabel(double ratio) {
    final clamped = ratio.clamp(0.0, 1.0);
    return '${(clamped * 100).toStringAsFixed(1)}%';
  }
}
