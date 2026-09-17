import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

BattleRecord _rec(
  String id,
  DateTime at, {
  bool victory = true,
  int combo = 0,
  int remaining = 0,
  String title = 'クエスト',
}) =>
    BattleRecord(
      id: id,
      title: title,
      occurredAt: at,
      isVictory: victory,
      comboCount: combo,
      remainingSubTasks: remaining,
    );

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

void main() {
  testWidgets('戦績が無い場合は空状態を表示する', (tester) async {
    await _pump(tester, []);
    expect(find.byKey(AppKeys.battleRecordScreen), findsOneWidget);
    expect(find.byKey(AppKeys.battleRecordEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.battleRecordHistoryList), findsNothing);
  });

  testWidgets('ロード後にサマリー（勝利数・敗北数・勝率・最長連勝）を表示する', (tester) async {
    await _pump(
      tester,
      [
        _rec('a', DateTime(2026, 9, 1, 10)),
        _rec('b', DateTime(2026, 9, 2, 10), victory: false, remaining: 2),
        _rec('c', DateTime(2026, 9, 3, 10), combo: 3),
      ],
    );
    expect(find.byKey(AppKeys.battleRecordEmpty), findsNothing);
    expect(find.textContaining('2'), findsWidgets);
    expect(find.textContaining('勝率'), findsOneWidget);
    expect(find.textContaining('66.7%'), findsOneWidget);
    expect(find.textContaining('最長連勝'), findsOneWidget);
  });

  testWidgets('現在連勝を表示する（最新が勝利なら連勝、敗北なら連敗）', (tester) async {
    await _pump(
      tester,
      [
        _rec('a', DateTime(2026, 9, 1, 10), victory: false),
        _rec('b', DateTime(2026, 9, 2, 10)),
        _rec('c', DateTime(2026, 9, 3, 10)),
      ],
    );
    expect(find.textContaining('現在の連勝'), findsOneWidget);
    expect(find.textContaining('連敗'), findsNothing);
  });

  testWidgets('絞り込みチップ: 勝利のみで敗北行が消える', (tester) async {
    await _pump(
      tester,
      [
        _rec('a', DateTime(2026, 9, 1, 10), title: 'クエスト'),
        _rec('b', DateTime(2026, 9, 2, 10),
            victory: false, remaining: 1, title: '敗北クエスト'),
      ],
    );
    expect(find.text('敗北クエスト'), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.battleRecordFilterVictory));
    await tester.pumpAndSettle();
    expect(find.text('敗北クエスト'), findsNothing);
    expect(find.text('クエスト'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.battleRecordFilterDefeat));
    await tester.pumpAndSettle();
    expect(find.text('敗北クエスト'), findsOneWidget);
    expect(find.text('クエスト'), findsNothing);
  });

  testWidgets('履歴行に題目・日時・コンボ・残サブタスクを表示する', (tester) async {
    await _pump(
      tester,
      [
        _rec(
          'a',
          DateTime(2026, 9, 1, 10, 5),
          victory: false,
          combo: 0,
          remaining: 3,
          title: '残敗クエスト',
        ),
        _rec('b', DateTime(2026, 9, 2, 11, 30), combo: 5, title: '勝利クエスト'),
      ],
    );
    // 新しい順
    expect(find.text('勝利クエスト'), findsOneWidget);
    expect(find.text('残敗クエスト'), findsOneWidget);
    expect(find.text('2026/09/02 11:30'), findsOneWidget);
    expect(find.text('2026/09/01 10:05'), findsOneWidget);
    expect(find.textContaining('5コンボ'), findsOneWidget);
    expect(find.textContaining('残り3件'), findsOneWidget);
  });

  testWidgets('履歴は最大50件まで表示する', (tester) async {
    final records = List.generate(
      60,
      (i) => _rec('r${i.toString().padLeft(3, '0')}',
          DateTime(2026, 9, 1).add(Duration(minutes: i)), title: '敵$i'),
    );
    await _pump(tester, records, now: DateTime(2026, 9, 2));
    expect(find.text('敵59'), findsOneWidget);
    // 新しい50件 = 敵10〜敵59 が表示対象、敵9以前は対象外。
    // ListView は遅延描画のため、最も古い表示対象までスクロールして実体化させる。
    await tester.scrollUntilVisible(find.text('敵10'), 300);
    expect(find.text('敵10'), findsOneWidget);
    expect(find.text('敵9'), findsNothing);
  });
}
