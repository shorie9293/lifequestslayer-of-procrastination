// 討伐戦績 敵別・月別集計セクションのUI試練（改善提案 #96）。
//
// - 敵別セクションが既知2種＋不明グループの行を出すこと
// - 月別セクションが月ごとの行を yearMonth 降順で出すこと
// - 行キー（AppKeys.battleRecordEnemyStatRow / MonthlyStatRow）で個別行が特定できること
// - 記録が空なら両セクションとも出ないこと

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

Future<void> _pump(
  WidgetTester tester,
  List<BattleRecord> records, {
  DateTime? now,
}) async {
  final repo = InMemoryBattleRecordRepository();
  for (final r in records) {
    await repo.add(r);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: BattleRecordScreen(repository: repo, now: now),
    ),
  );
  await tester.pumpAndSettle();
}

BattleRecord _rec(
  String id,
  DateTime at, {
  bool victory = true,
  String? enemyAssetPath,
}) =>
    BattleRecord(
      id: id,
      title: 'クエスト$id',
      occurredAt: at,
      isVictory: victory,
      enemyAssetPath: enemyAssetPath,
    );

void main() {
  testWidgets('敵別・月別セクションが見出し・行を表示する', (tester) async {
    final known = EnemyAssetService.assetsForRank(QuestRank.S);
    final pathA = known.first;
    final pathB = known.length > 1 ? known[1] : known.first;
    await _pump(
      tester,
      [
        _rec('a', DateTime(2026, 9, 1, 10), enemyAssetPath: pathA),
        _rec('b', DateTime(2026, 9, 2, 10),
            victory: false, enemyAssetPath: pathA),
        _rec('c', DateTime(2026, 8, 15, 10), enemyAssetPath: pathB),
        _rec('d', DateTime(2026, 8, 20, 10)),
      ],
    );

    // 敵別セクション
    expect(find.byKey(AppKeys.battleRecordEnemyStatsSection), findsOneWidget);
    expect(find.text('敵別戦績'), findsOneWidget);
    expect(
        find.byKey(AppKeys.battleRecordEnemyStatRow(pathA)), findsOneWidget);
    expect(
        find.byKey(AppKeys.battleRecordEnemyStatRow(pathB)), findsOneWidget);
    expect(
        find.byKey(AppKeys.battleRecordEnemyStatRow('')), findsOneWidget);
    expect(find.text('不明'), findsOneWidget);

    // 月別セクション（yearMonth 降順: 2026-09 が先頭）
    expect(find.byKey(AppKeys.battleRecordMonthlyStatsSection),
        findsOneWidget);
    expect(find.text('月別戦績'), findsOneWidget);
    expect(
        find.byKey(AppKeys.battleRecordMonthlyStatRow('2026-09')),
        findsOneWidget);
    expect(
        find.byKey(AppKeys.battleRecordMonthlyStatRow('2026-08')),
        findsOneWidget);
    expect(find.text('2026年9月'), findsOneWidget);
    expect(find.text('2026年8月'), findsOneWidget);
  });

  testWidgets('敵別セクションの最終討伐日は日付のみで表示する', (tester) async {
    final path = EnemyAssetService.assetsForRank(QuestRank.S).first;
    await _pump(
      tester,
      [
        _rec('a', DateTime(2026, 9, 2, 11, 30), enemyAssetPath: path),
      ],
    );
    expect(find.textContaining('最終: 2026/09/02'), findsOneWidget);
    // 時刻を含む完全一致は履歴行にのみ存在する
    expect(find.text('2026/09/02 11:30'), findsOneWidget);
  });

  testWidgets('記録が空なら両セクションとも表示しない', (tester) async {
    await _pump(tester, []);
    expect(find.byKey(AppKeys.battleRecordEnemyStatsSection), findsNothing);
    expect(find.byKey(AppKeys.battleRecordMonthlyStatsSection), findsNothing);
  });
}
