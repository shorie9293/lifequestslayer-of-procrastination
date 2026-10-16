// クエスト別ストリーク画面の試練。
//
// - 固定 now で tasksOverride/streaksOverride 注入し、サマリー・行表示を検証
// - 検索・ボーナス絞り込み・空状態
// - オーバーフローメニューからの遷移配線

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/presentation/quest_streak_keys.dart';
import 'package:rpg_todo/features/guild/presentation/quest_streak_screen.dart';

import 'guild_screen_test.dart' show createViewModels, pumpGuildScreen;

final DateTime fixedNow = DateTime(2026, 10, 16);

Task task(String id, String title) => Task(id: id, title: title);

List<Task> sampleTasks() => [
      task('t1', '魔物討伐'),
      task('t2', '読書'),
      task('t3', '日記'),
    ];

Map<String, TaskStreak> sampleStreaks() => {
      't1': TaskStreak(
        currentStreak: 9,
        lastCompletedDate: DateTime(2026, 10, 16),
      ),
      // 非ボーナス
      't2': TaskStreak(
        currentStreak: 3,
        lastCompletedDate: DateTime(2026, 10, 15),
      ),
      // t3 には streak なし → 表示されない
    };

Future<void> pumpScreen(
  WidgetTester tester, {
  List<Task>? tasks,
  Map<String, TaskStreak>? streaks,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: QuestStreakScreen(
      tasksOverride: tasks ?? sampleTasks(),
      streaksOverride: streaks ?? sampleStreaks(),
      now: fixedNow,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('サマリーカードに追跡件数・最長・ボーナス件数が出る', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(QuestStreakKeys.screen), findsOneWidget);
    expect(find.byKey(QuestStreakKeys.summaryCard), findsOneWidget);
    expect(find.text('追跡中 2件'), findsOneWidget);
    expect(find.text('最長 9日'), findsOneWidget);
    expect(find.text('ボーナス中 1件'), findsOneWidget);
  });

  testWidgets('一覧には streak 付きクエストのみが連続日数つきで並ぶ', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(QuestStreakKeys.list), findsOneWidget);
    expect(find.text('魔物討伐'), findsOneWidget);
    expect(find.text('読書'), findsOneWidget);
    expect(find.text('日記'), findsNothing, reason: 'streak 無しは除外');
    expect(find.text('連続 9日'), findsOneWidget);
    expect(find.text('連続 3日'), findsOneWidget);
    expect(find.text('2026-10-16'), findsOneWidget);
    expect(find.text('2026-10-15'), findsOneWidget);
  });

  testWidgets('ボーナス中の行にはボーナスバッジが出る', (tester) async {
    await pumpScreen(tester);

    expect(find.text('+20% EXP'), findsOneWidget,
        reason: '連続9日の魔物討伐のみボーナス中');
  });

  testWidgets('tasks/streaks が空なら空状態が出る', (tester) async {
    await pumpScreen(tester, tasks: const [], streaks: const {});

    expect(find.byKey(QuestStreakKeys.emptyState), findsOneWidget);
    expect(find.text('まだストリークがありません。'), findsOneWidget);
  });

  testWidgets('検索で行が絞り込まれる', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byKey(QuestStreakKeys.searchField), '魔物');
    await tester.pumpAndSettle();

    expect(find.text('魔物討伐'), findsOneWidget);
    expect(find.text('読書'), findsNothing);
  });

  testWidgets('ボーナス中のみ FilterChip で絞り込まれる', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(QuestStreakKeys.bonusFilterChip));
    await tester.pumpAndSettle();

    expect(find.text('魔物討伐'), findsOneWidget);
    expect(find.text('読書'), findsNothing);
  });

  testWidgets('⋯メニューにクエスト別ストリークの項目があり遷移できる', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.guildOverflowQuestStreak), findsOneWidget);
    expect(find.byKey(QuestStreakKeys.guildEntry), findsOneWidget);
    expect(find.text('クエスト別ストリーク'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildOverflowQuestStreak));
    await tester.pumpAndSettle();

    expect(find.byType(QuestStreakScreen), findsOneWidget);
    expect(find.byKey(QuestStreakKeys.screen), findsOneWidget);
    expect(find.byKey(QuestStreakKeys.emptyState), findsOneWidget,
        reason: '既定VMは streak 未記録のため空状態');
  });

  testWidgets('QuestStreakService.sortEntries の表示順（連続降順）が反映される',
      (tester) async {
    await pumpScreen(tester);

    final listFinder = find.byKey(QuestStreakKeys.list);
    final listWidget = tester.widget<ListView>(listFinder);
    expect(listWidget.childrenDelegate, isNotNull);

    // 先頭行（魔物討伐・連続9日）が読書より上に来ること
    final monsterY = tester.getTopLeft(find.text('魔物討伐')).dy;
    final bookY = tester.getTopLeft(find.text('読書')).dy;
    expect(monsterY < bookY, isTrue);
  });
}