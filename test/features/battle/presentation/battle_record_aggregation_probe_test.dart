// 親探針: 集計セクションは履歴の絞り込みに影響されない（改善提案 #96）。
//
// 眷属の画面試練は絞込と集計を別々にしか撃たない。
// 「絞り込みチップを切り替えても敵別・月別の集計行は不変（集計は全記録が母集合）」
// という合成の不変条件を親が撃つ。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';

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
  testWidgets('絞り込みを切り替えても敵別・月別の集計行は不変', (tester) async {
    final known = EnemyAssetService.assetsForRank(QuestRank.S).first;
    final repo = InMemoryBattleRecordRepository();
    for (final r in [
      _rec('a', DateTime(2026, 9, 1, 10), enemyAssetPath: known),
      _rec('b', DateTime(2026, 9, 2, 10), victory: false, enemyAssetPath: known),
      _rec('c', DateTime(2026, 8, 1, 10)), // 不明
    ]) {
      await repo.add(r);
    }
    await tester.pumpWidget(
      MaterialApp(home: BattleRecordScreen(repository: repo)),
    );
    await tester.pumpAndSettle();

    final enemyRowsBefore = find
        .byKey(AppKeys.battleRecordEnemyStatRow(known))
        .evaluate()
        .length;
    final monthlyBefore = find
        .byKey(AppKeys.battleRecordMonthlyStatRow('2026-09'))
        .evaluate()
        .length;
    expect(enemyRowsBefore, 1);
    expect(monthlyBefore, 1);

    // 敗北のみで絞り込んでも集計は全記録が母集合ゆえ不変
    await tester.tap(find.byKey(AppKeys.battleRecordFilterDefeat));
    await tester.pumpAndSettle();

    expect(
      find.byKey(AppKeys.battleRecordEnemyStatRow(known)).evaluate().length,
      enemyRowsBefore,
    );
    expect(
      find.byKey(AppKeys.battleRecordMonthlyStatRow('2026-09')).evaluate().length,
      monthlyBefore,
    );
    // 絞込後も履歴には勝利行が出ない
    expect(find.text('qa'), findsNothing);
  });
}
