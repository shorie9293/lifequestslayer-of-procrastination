// 寄合所クエスト検索画面の試練（改善提案 #80）
//
// tasksOverride / now を注入するため Provider 不要。
// flutter_test のみに依存する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';

/// 固定基準時刻（期日超過判定の境界検証に使う）
final DateTime _now = DateTime(2026, 9, 22, 12, 0, 0);

Task _task(
  String id,
  String title, {
  QuestRank rank = QuestRank.B,
  DateTime? deadline,
  int? targetTimeMinutes,
  List<String> tags = const [],
  RepeatInterval repeatInterval = RepeatInterval.none,
  bool isCompleted = false,
}) {
  return Task(
    id: id,
    title: title,
    rank: rank,
    deadline: deadline,
    targetTimeMinutes: targetTimeMinutes,
    tags: tags,
    repeatInterval: repeatInterval,
    isCompleted: isCompleted,
  );
}

/// 12件の固定クエスト一覧（id 昇順で安定ソートの期待結果を決める）
///
/// deadline順（期限順ソート時）:
///   t01 (D-1) → t02 (D+1) → t03..t10 (null) → t11 (D-2, 期限切れ) …
///   ※ null は常に末尾、期限切れも isBefore(now) のみで並ぶ点に注意
/// 実際の deadlineAsc 順: t11(超過) → t01 → t02 → t03..t10(null, id順)
List<Task> _sampleTasks() {
  return [
    _task('t01', 'ゴブリン討伐',
        rank: QuestRank.B,
        deadline: _now.add(const Duration(days: 1)),
        targetTimeMinutes: 30,
        tags: ['戦闘']),
    _task('t02', 'ドラゴン討伐',
        rank: QuestRank.S,
        deadline: _now.add(const Duration(days: 7)),
        targetTimeMinutes: 600,
        tags: ['戦闘', '冒険']),
    _task('t03', '薬草採取',
        rank: QuestRank.A,
        targetTimeMinutes: 120,
        tags: ['採集']),
    _task('t04', '書物の写経',
        rank: QuestRank.B,
        targetTimeMinutes: 90,
        tags: ['学問']),
    _task('t05', '村の見回り',
        rank: QuestRank.A,
        repeatInterval: RepeatInterval.daily),
    _task('t06', 'ガレージ掃除',
        rank: QuestRank.B,
        deadline: _now.subtract(const Duration(days: 2))),
    _task('t07', '報告書作成',
        rank: QuestRank.B,
        targetTimeMinutes: 60),
    _task('t08', '剣術の修行',
        rank: QuestRank.S,
        targetTimeMinutes: 300),
    _task('t09', '井戸の清掃',
        rank: QuestRank.A,
        targetTimeMinutes: 45),
    _task('t10', '手紙の配達',
        rank: QuestRank.B,
        targetTimeMinutes: 15),
    _task('t11', '期限切れの納税',
        rank: QuestRank.A,
        deadline: _now.subtract(const Duration(hours: 1))),
    _task('t12', '境界の同時刻クエスト',
        rank: QuestRank.B,
        deadline: _now), // 境界: now と同時刻 → 超過ではない
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  List<Task>? tasks,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: GuildQuestSearchScreen(tasksOverride: tasks ?? _sampleTasks(), now: _now),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('TextField/チップ/メニュー/一覧キーが存在する', (tester) async {
    await _pump(tester);

    expect(find.byKey(AppKeys.guildQuestSearchScreen), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestSearchField), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestSortMenu), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestSearchReset), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestResultList), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestResultCount), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestStatusChip('overdue')), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestRankChip('S')), findsOneWidget);
  });

  testWidgets('全件が表示される', (tester) async {
    await _pump(tester);

    // ListView のスクロールで全カードを走査（遅延描画対策）
    expect(find.text('12件'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('[B] 手紙の配達'),
      find.byKey(AppKeys.guildQuestResultList),
      const Offset(0, -500),
    );
    expect(find.text('[B] 手紙の配達'), findsOneWidget);
  });

  testWidgets('検索語入力で絞り込まれる', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.byKey(AppKeys.guildQuestSearchField),
      'ドラゴン',
    );
    await tester.pump();

    expect(find.text('1件'), findsOneWidget);
    expect(find.text('[S] ドラゴン討伐'), findsOneWidget);
  });

  testWidgets('クリアボタンで検索語が消えて全件に戻る', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.byKey(AppKeys.guildQuestSearchField),
      'ドラゴン',
    );
    await tester.pump();
    expect(find.text('1件'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildQuestSearchClear));
    await tester.pump();

    // 検索語が消え、全件に戻る
    expect(find.text('12件'), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestSearchClear), findsNothing);
  });

  testWidgets('状態チップ「期日超過」で期限切れのみになる（境界=now同時刻は超過でない）', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(AppKeys.guildQuestStatusChip('overdue')));
    await tester.pump();

    // isBefore(now) のみ超過: t11 は超過、t06 は2日前で超過、t12（=now）は超過でない
    expect(find.text('2件'), findsOneWidget);
    expect(find.text('[A] 期限切れの納税'), findsOneWidget);
    expect(find.text('[B] ガレージ掃除'), findsOneWidget);
    expect(find.text('[B] 境界の同時刻クエスト'), findsNothing);
  });

  testWidgets('ランクチップでランク絞り込み', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(AppKeys.guildQuestRankChip('S')));
    await tester.pump();

    expect(find.text('2件'), findsOneWidget);
    expect(find.text('[S] ドラゴン討伐'), findsOneWidget);
    expect(find.text('[S] 剣術の修行'), findsOneWidget);
  });

  testWidgets('ソートメニュー切替で先頭が変わる（期限順→難易度順）', (tester) async {
    await _pump(tester);

    // 既定: deadlineAsc。期限なしは末尾、期限ありは超過→昇順。先頭（超過2日前）は t06
    await tester.dragUntilVisible(
      find.text('[B] ガレージ掃除'),
      find.byKey(AppKeys.guildQuestResultList),
      const Offset(0, -500),
    );
    expect(find.text('[B] ガレージ掃除'), findsOneWidget);

    // 難易度順（S→A→B）に切替: 先頭は S ランク
    await tester.tap(find.byKey(AppKeys.guildQuestSortMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('難易度が高い順').last);
    await tester.pumpAndSettle();

    expect(find.text('12件'), findsOneWidget); // 全12件のまま
    final firstCardText = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(AppKeys.guildQuestResultList),
            matching: find.byType(Text),
          )
          .first,
    );
    expect(firstCardText.data, '[S] ドラゴン討伐');
  });

  testWidgets('リセットで初期状態に戻る', (tester) async {
    await _pump(tester);

    // 検索語＋ランク絞り込みを適用
    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), '討伐');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.guildQuestRankChip('S')));
    await tester.pump();
    expect(find.text('1件'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildQuestSearchReset));
    await tester.pump();

    expect(find.text('12件'), findsOneWidget);
    // 検索フィールドも空に戻っている
    final field = tester.widget<TextField>(
      find.byKey(AppKeys.guildQuestSearchField),
    );
    expect(field.controller?.text ?? '', '');
  });

  testWidgets('0件時に guildQuestEmptyState が出る', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.byKey(AppKeys.guildQuestSearchField),
      '存在しないクエスト名',
    );
    await tester.pump();

    expect(find.byKey(AppKeys.guildQuestEmptyState), findsOneWidget);
    expect(find.text('条件に合うクエストがない。'), findsOneWidget);
    expect(find.text('0件'), findsOneWidget);
  });

  testWidgets('結果件数テキストが正しい（複合条件で3件）', (tester) async {
    await _pump(tester);

    // 「討伐」を含む2件 + Aランクで「採集」札… 複合条件で安定した件数を作る
    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), '討伐');
    await tester.pump();
    // ゴブリン討伐(B) / ドラゴン討伐(S) の2件
    expect(find.text('2件'), findsOneWidget);

    // さらにランク B を追加 → 1件
    await tester.tap(find.byKey(AppKeys.guildQuestRankChip('B')));
    await tester.pump();
    expect(find.text('1件'), findsOneWidget);

    // ランク B を解除し、代わりに状態「繰り返し」は討伐と重ならないため 0件
    await tester.tap(find.byKey(AppKeys.guildQuestRankChip('B')));
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.guildQuestStatusChip('recurring')));
    await tester.pump();
    expect(find.text('0件'), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestEmptyState), findsOneWidget);
  });

  testWidgets('検索語はタグにもマッチする', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), '採集');
    await tester.pump();

    expect(find.text('1件'), findsOneWidget);
    expect(find.text('[A] 薬草採取'), findsOneWidget);
  });
}