import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_aggregation.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';
import 'package:rpg_todo/features/battle/domain/enemy_catalog.dart';

/// 討伐戦績の敵別・月別集計（改善提案 #96）の試練。
void main() {
  const knownPath = 'assets/sprites/monsters/demons/demon_red_winged.png';
  const unknownPath = 'assets/sprites/monsters/nope.png';

  BattleRecord rec(
    String id,
    DateTime at,
    bool victory, {
    String? enemy,
  }) =>
      BattleRecord(
        id: id,
        title: '討伐',
        occurredAt: at,
        isVictory: victory,
        enemyAssetPath: enemy,
      );

  group('knownEnemyAssetPaths', () {
    test('全ランクの既知アセットパスを返す', () {
      final paths = BattleRecordAggregationService.knownEnemyAssetPaths();
      expect(paths, contains(knownPath));
      expect(paths.length, 17);
      final perRank = [
        for (final rank in QuestRank.values) ...EnemyAssetService.assetsForRank(rank),
      ];
      expect(paths, perRank);
    });
  });

  group('buildEnemyStats', () {
    test('空リストは空で例外を投げない', () {
      expect(BattleRecordAggregationService.buildEnemyStats(const []), isEmpty);
    });

    test('同一パス複数件の defeats/wins/losses を集計する', () {
      final stats = BattleRecordAggregationService.buildEnemyStats([
        rec('a', DateTime(2026, 10, 1), true, enemy: knownPath),
        rec('b', DateTime(2026, 10, 2), false, enemy: knownPath),
        rec('c', DateTime(2026, 10, 3), true, enemy: knownPath),
      ]);
      expect(stats.length, 1);
      expect(stats.first.assetPath, knownPath);
      expect(stats.first.defeats, 3);
      expect(stats.first.wins, 2);
      expect(stats.first.losses, 1);
      expect(stats.first.winRate, closeTo(2 / 3, 1e-9));
      expect(stats.first.winRatePercent, 67);
      expect(stats.first.winRateLabel, '66.7%');
    });

    test('lastDefeatedAt は最新の occurredAt', () {
      final stats = BattleRecordAggregationService.buildEnemyStats([
        rec('a', DateTime(2026, 10, 1), true, enemy: knownPath),
        rec('b', DateTime(2026, 10, 5), true, enemy: knownPath),
        rec('c', DateTime(2026, 10, 3), true, enemy: knownPath),
      ]);
      expect(stats.first.lastDefeatedAt, DateTime(2026, 10, 5));
    });

    test('enemyAssetPath==null は 不明 に集約される', () {
      final stats = BattleRecordAggregationService.buildEnemyStats([
        rec('a', DateTime(2026, 10, 1), true),
        rec('b', DateTime(2026, 10, 2), false),
      ]);
      expect(stats.length, 1);
      expect(stats.first.displayName, BattleRecordAggregationService.unknownEnemyName);
      expect(stats.first.displayName, '不明');
      expect(stats.first.assetPath, '');
      expect(stats.first.defeats, 2);
      expect(stats.first.wins, 1);
    });

    test('未知パスは結果に含まれない', () {
      final stats = BattleRecordAggregationService.buildEnemyStats([
        rec('a', DateTime(2026, 10, 1), true, enemy: unknownPath),
      ]);
      expect(stats, isEmpty);
    });

    test('既知パスの displayName は enemyDisplayNameFromAsset と一致', () {
      final stats = BattleRecordAggregationService.buildEnemyStats([
        rec('a', DateTime(2026, 10, 1), true, enemy: knownPath),
      ]);
      expect(stats.first.displayName, enemyDisplayNameFromAsset(knownPath));
      expect(stats.first.displayName, 'Demon Red Winged');
    });

    test('並び順: defeats 降順、同時は displayName 昇順', () {
      const a = 'assets/sprites/monsters/beasts/beast_grey_armored.png';
      const b = 'assets/sprites/monsters/demons/demon_red_winged.png';
      const c = 'assets/sprites/monsters/beasts/owl_creature_small.png';
      final stats = BattleRecordAggregationService.buildEnemyStats([
        // a: 1件 → 'Beast Grey Armored'
        rec('1', DateTime(2026, 10, 1), true, enemy: a),
        // c: 3件 → 'Owl Creature Small'
        rec('2', DateTime(2026, 10, 1), true, enemy: c),
        rec('3', DateTime(2026, 10, 2), false, enemy: c),
        rec('4', DateTime(2026, 10, 3), true, enemy: c),
        // b: 1件 → 'Demon Red Winged'
        rec('5', DateTime(2026, 10, 4), true, enemy: b),
      ]);
      expect(
        stats.map((s) => s.assetPath).toList(),
        [c, a, b], // Owl(3) > Beast(1) と Demon(1) は displayName 昇順: B < O
      );
      expect(stats[1].displayName, 'Beast Grey Armored');
      expect(stats[2].displayName, 'Demon Red Winged');
    });
  });

  group('buildMonthlyStats', () {
    test('空リストは空で例外を投げない', () {
      expect(BattleRecordAggregationService.buildMonthlyStats(const []), isEmpty);
    });

    test('同日時・別月を正しく切り分ける', () {
      final stats = BattleRecordAggregationService.buildMonthlyStats([
        rec('a', DateTime(2026, 9, 30, 23, 59), true),
        rec('b', DateTime(2026, 10, 1, 0, 0), false),
      ]);
      expect(stats.length, 2);
      expect(stats.map((s) => s.yearMonth), ['2026-10', '2026-09']);
      expect(stats[0].losses, 1);
      expect(stats[1].wins, 1);
    });

    test('月跨ぎの記録を月ごとに集計し yearMonth 降順', () {
      final stats = BattleRecordAggregationService.buildMonthlyStats([
        rec('a', DateTime(2026, 8, 10), true),
        rec('b', DateTime(2026, 10, 1), true),
        rec('c', DateTime(2026, 9, 15), false),
        rec('d', DateTime(2026, 10, 20), true),
        rec('e', DateTime(2026, 10, 20), false),
      ]);
      expect(stats.map((s) => s.yearMonth).toList(), ['2026-10', '2026-09', '2026-08']);
      expect(stats[0].defeats, 3);
      expect(stats[0].wins, 2);
      expect(stats[0].losses, 1);
      expect(stats[0].winRate, closeTo(2 / 3, 1e-9));
      expect(stats[0].winRatePercent, 67);
      expect(stats[1].defeats, 1);
      expect(stats[1].wins, 0);
      expect(stats[1].winRate, 0.0);
    });

    test('label が YYYY年M月 形式', () {
      final stats = BattleRecordAggregationService.buildMonthlyStats([
        rec('a', DateTime(2026, 10, 1), true),
        rec('b', DateTime(2026, 1, 1), true),
      ]);
      expect(stats.map((s) => s.label).toList(), ['2026年10月', '2026年1月']);
    });

    test('winRateLabel は BattleRecordService.winRateLabel と同一', () {
      final stats = BattleRecordAggregationService.buildMonthlyStats([
        rec('a', DateTime(2026, 10, 1), true),
        rec('b', DateTime(2026, 10, 2), true),
        rec('c', DateTime(2026, 10, 3), false),
      ]);
      expect(stats.first.winRateLabel, '66.7%');
    });
  });

  group('モデル検証', () {
    test('EnemyStats: displayName 空は ArgumentError', () {
      expect(
        () => EnemyStats(assetPath: '', displayName: ''),
        throwsArgumentError,
      );
    });

    test('MonthlyStats: yearMonth 形式不正は ArgumentError', () {
      expect(
        () => MonthlyStats(yearMonth: '2026/10'),
        throwsArgumentError,
      );
      expect(
        () => MonthlyStats(yearMonth: ''),
        throwsArgumentError,
      );
      expect(
        () => MonthlyStats(yearMonth: '2026-13'),
        throwsArgumentError,
      );
      // 正常系
      expect(MonthlyStats(yearMonth: '2026-10').yearMonth, '2026-10');
    });

    test('負値は 0 に丸める', () {
      final e = EnemyStats(
        assetPath: knownPath,
        displayName: 'X',
        defeats: -5,
        wins: -1,
        losses: -2,
      );
      expect(e.defeats, 0);
      expect(e.wins, 0);
      expect(e.losses, 0);
      expect(e.winRate, 0.0);
      expect(e.winRatePercent, 0);

      final m = MonthlyStats(yearMonth: '2026-10', defeats: -3, wins: -1, losses: -1);
      expect(m.defeats, 0);
      expect(m.wins, 0);
      expect(m.losses, 0);
      expect(m.winRate, 0.0);
    });
  });
}
