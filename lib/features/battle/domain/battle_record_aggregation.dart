import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_service.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';
import 'package:rpg_todo/features/battle/domain/enemy_catalog.dart';

/// 敵別集計（改善提案 #96）。
///
/// [assetPath] は敵アセットパス。『不明』グループ（enemyAssetPath==null の記録）
/// は空文字 '' を sentinel として使う。
class EnemyStats {
  final String assetPath;
  final String displayName;

  /// この敵の総討伐件数。
  final int defeats;
  final int wins;
  final int losses;

  /// この敵の最新 occurredAt（無ければ null）。
  final DateTime? lastDefeatedAt;

  /// 検証付きコンストラクタ（非const・本体で不変条件を強制する）。
  ///
  /// - [displayName] が空なら [ArgumentError]。
  /// - 負値は 0 へ丸める。
  EnemyStats({
    required this.assetPath,
    required this.displayName,
    int defeats = 0,
    int wins = 0,
    int losses = 0,
    this.lastDefeatedAt,
  })  : defeats = defeats < 0 ? 0 : defeats,
        wins = wins < 0 ? 0 : wins,
        losses = losses < 0 ? 0 : losses {
    if (displayName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'must not be empty');
    }
  }

  /// 勝率（defeats==0 は 0.0）。
  double get winRate => defeats == 0 ? 0.0 : wins / defeats;

  /// 勝率の整数パーセント。
  int get winRatePercent => (winRate * 100).round();

  /// 勝率の表示用ラベル（[BattleRecordService.winRateLabel] を再利用）。
  String get winRateLabel => BattleRecordService.winRateLabel(winRate);
}

/// 月別集計（改善提案 #96）。
class MonthlyStats {
  /// 'YYYY-MM' 形式の年月キー。
  final String yearMonth;
  final int defeats;
  final int wins;
  final int losses;

  /// 検証付きコンストラクタ（非const・本体で不変条件を強制する）。
  ///
  /// - [yearMonth] が空または 'YYYY-MM' 形式でないなら [ArgumentError]。
  /// - 負値は 0 へ丸める。
  MonthlyStats({
    required this.yearMonth,
    int defeats = 0,
    int wins = 0,
    int losses = 0,
  })  : defeats = defeats < 0 ? 0 : defeats,
        wins = wins < 0 ? 0 : wins,
        losses = losses < 0 ? 0 : losses {
    if (!_isValidYearMonth(yearMonth)) {
      throw ArgumentError.value(yearMonth, 'yearMonth', 'must be YYYY-MM');
    }
  }

  static bool _isValidYearMonth(String value) {
    if (value.length != 7 || value[4] != '-') return false;
    final y = value.substring(0, 4);
    final m = value.substring(5, 7);
    if (y.isEmpty || int.tryParse(y) == null) return false;
    final month = int.tryParse(m);
    return month != null && month >= 1 && month <= 12;
  }

  /// 勝率（defeats==0 は 0.0）。
  double get winRate => defeats == 0 ? 0.0 : wins / defeats;

  /// 勝率の整数パーセント。
  int get winRatePercent => (winRate * 100).round();

  /// 勝率の表示用ラベル（[BattleRecordService.winRateLabel] を再利用）。
  String get winRateLabel => BattleRecordService.winRateLabel(winRate);

  /// 表示用ラベル（例: '2026年10月'）。
  String get label {
    final year = int.parse(yearMonth.substring(0, 4));
    final month = int.parse(yearMonth.substring(5, 7));
    return '$year年$month月';
  }
}

/// 討伐戦績の敵別・月別集計を扱う純粋サービス（改善提案 #96）。
///
/// 状態・IO・乱数を持たず、すべて静的関数で完結する（試練可能）。
class BattleRecordAggregationService {
  const BattleRecordAggregationService._();

  /// 『不明』グループの表示名。
  static const String unknownEnemyName = '不明';

  /// 既知の敵アセットパス一覧（QuestRank.values × EnemyAssetService.assetsForRank）。
  static List<String> knownEnemyAssetPaths() => [
        for (final rank in QuestRank.values) ...EnemyAssetService.assetsForRank(rank),
      ];

  /// 敵別の討伐集計を返す。
  ///
  /// - enemyAssetPath==null の記録は displayName='不明'（assetPath=''）に集約。
  /// - 非null かつ既知一覧に無いパスは「未知パス」として無視。
  /// - 並び: defeats 降順、同時 defeats は displayName 昇順、更に assetPath 昇順。
  static List<EnemyStats> buildEnemyStats(List<BattleRecord> records) {
    final known = knownEnemyAssetPaths().toSet();
    final wins = <String, int>{};
    final losses = <String, int>{};
    final names = <String, String>{};
    final lastAt = <String, DateTime>{};

    void add(String assetPath, String name, BattleRecord r) {
      wins.update(assetPath, (v) => v + (r.isVictory ? 1 : 0), ifAbsent: () => r.isVictory ? 1 : 0);
      losses.update(assetPath, (v) => v + (r.isVictory ? 0 : 1), ifAbsent: () => r.isVictory ? 0 : 1);
      names[assetPath] = name;
      final prev = lastAt[assetPath];
      if (prev == null || r.occurredAt.isAfter(prev)) {
        lastAt[assetPath] = r.occurredAt;
      }
    }

    for (final r in records) {
      final path = r.enemyAssetPath;
      if (path == null) {
        add('', unknownEnemyName, r);
      } else if (known.contains(path)) {
        final name = enemyDisplayNameFromAsset(path);
        add(path, name.isEmpty ? unknownEnemyName : name, r);
      } // 未知パスは無視
    }

    final stats = [
      for (final entry in wins.entries)
        EnemyStats(
          assetPath: entry.key,
          displayName: names[entry.key]!,
          defeats: entry.value + (losses[entry.key] ?? 0),
          wins: entry.value,
          losses: losses[entry.key] ?? 0,
          lastDefeatedAt: lastAt[entry.key],
        ),
    ];
    stats.sort((a, b) {
      final byDefeats = b.defeats.compareTo(a.defeats);
      if (byDefeats != 0) return byDefeats;
      final byName = a.displayName.compareTo(b.displayName);
      if (byName != 0) return byName;
      return a.assetPath.compareTo(b.assetPath);
    });
    return stats;
  }

  /// 月別の討伐集計を返す（occurredAt から 'YYYY-MM' を切り出す）。
  ///
  /// 並び: yearMonth 降順（新しい月が先頭）。
  static List<MonthlyStats> buildMonthlyStats(List<BattleRecord> records) {
    final wins = <String, int>{};
    final losses = <String, int>{};
    for (final r in records) {
      final key =
          '${r.occurredAt.year.toString().padLeft(4, '0')}-${r.occurredAt.month.toString().padLeft(2, '0')}';
      wins.update(key, (v) => v + (r.isVictory ? 1 : 0), ifAbsent: () => r.isVictory ? 1 : 0);
      losses.update(key, (v) => v + (r.isVictory ? 0 : 1), ifAbsent: () => r.isVictory ? 0 : 1);
    }
    final stats = [
      for (final entry in wins.keys)
        MonthlyStats(
          yearMonth: entry,
          defeats: (wins[entry] ?? 0) + (losses[entry] ?? 0),
          wins: wins[entry] ?? 0,
          losses: losses[entry] ?? 0,
        ),
    ];
    stats.sort((a, b) => b.yearMonth.compareTo(a.yearMonth));
    return stats;
  }
}
