// 親探針: 敵別・月別集計の合成不変条件（改善提案 #96）。
//
// 眷属の試練は各機能を個別に検証しがちで、以下の「合成の不変条件」は誰も撃たない:
//  1) 未知パスの記録は敵別から除外されるが、月別には含まれる（軸ごとに母集合が異なる）
//  2) 敵別 defeats 合計 + 未知パス件数 == 全記録件数（取りこぼし・二重計上なし）
//  3) 集計は入力リストを破壊しない（非破壊）
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_aggregation.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';

BattleRecord _rec(
  String id,
  DateTime at, {
  bool victory = true,
  String? enemyAssetPath,
}) =>
    BattleRecord(
      id: id,
      title: 'q$id',
      occurredAt: at,
      isVictory: victory,
      enemyAssetPath: enemyAssetPath,
    );

void main() {
  test('敵別の母集合（既知＋不明）から未知パスが漏れ、月別は全件を数える', () {
    final known = EnemyAssetService.assetsForRank(QuestRank.S).first;
    final records = [
      _rec('a', DateTime(2026, 9, 1), enemyAssetPath: known),
      _rec('b', DateTime(2026, 9, 2), victory: false, enemyAssetPath: known),
      _rec('c', DateTime(2026, 8, 5)), // null -> 不明
      _rec('d', DateTime(2026, 8, 6), enemyAssetPath: 'assets/nope/ghost.png'),
    ];

    final enemies = BattleRecordAggregationService.buildEnemyStats(records);
    final months = BattleRecordAggregationService.buildMonthlyStats(records);

    final enemyTotal = enemies.fold<int>(0, (s, e) => s + e.defeats);
    final monthTotal = months.fold<int>(0, (s, m) => s + m.defeats);

    // 未知パス1件は敵別から抜け、月別には残る
    expect(enemyTotal, 3);
    expect(monthTotal, 4);
    // 未知パスの月（8月）も依然として集計に現れる
    expect(months.map((m) => m.yearMonth), containsAll(['2026-09', '2026-08']));
  });

  test('敵別 defeats 合計 + 未知パス件数 == 全記録件数（取りこぼし・二重計上なし）', () {
    final known = EnemyAssetService.assetsForRank(QuestRank.S).first;
    final records = [
      _rec('a', DateTime(2026, 9, 1), enemyAssetPath: known),
      _rec('b', DateTime(2026, 9, 1), victory: false, enemyAssetPath: known),
      _rec('c', DateTime(2026, 9, 1)),
      _rec('d', DateTime(2026, 9, 1), enemyAssetPath: 'x/unknown.png'),
      _rec('e', DateTime(2026, 9, 1), enemyAssetPath: 'y/unknown.png'),
    ];
    final enemies = BattleRecordAggregationService.buildEnemyStats(records);
    final enemyTotal = enemies.fold<int>(0, (s, e) => s + e.defeats);
    expect(enemyTotal, records.length - 2); // 未知パス2件を除く
  });

  test('集計は入力リストを破壊しない（非破壊）', () {
    final known = EnemyAssetService.assetsForRank(QuestRank.S).first;
    final input = [
      _rec('a', DateTime(2026, 9, 3), enemyAssetPath: known),
      _rec('b', DateTime(2026, 9, 1)),
      _rec('c', DateTime(2026, 9, 2), victory: false, enemyAssetPath: known),
    ];
    final snapshot = input.map((r) => r.id).toList();
    BattleRecordAggregationService.buildEnemyStats(input);
    BattleRecordAggregationService.buildMonthlyStats(input);
    expect(input.map((r) => r.id).toList(), snapshot);
  });
}
