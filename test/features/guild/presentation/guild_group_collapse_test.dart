// 寄合所のパネル開閉（既定は「全て畳む」）の試練。
//
// 2026-11-28: クエストが増えると一覧が長くなり「今日どれをやるか」が
// 読み取れなくなるため、起動時は見出しだけを並べる既定へ変えた。
// ここでは既定・手動開閉・全開/全閉・端末への保存と復元を撃つ。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_grouping.dart';
import 'package:rpg_todo/features/guild/presentation/quest_group_keys.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

import 'guild_screen_test.dart' show createViewModels, pumpGuildScreen;

void main() {
  setUp(() {
    // 未保存＝全パネル畳み（保存キーを入れない）
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<
      ({
        TaskViewModel task,
        PlayerViewModel player,
        SettingsViewModel settings
      })> pumpWithTwoTasks(WidgetTester tester) async {
    late ({
      TaskViewModel task,
      PlayerViewModel player,
      SettingsViewModel settings
    }) vms;
    await tester.runAsync(() async {
      vms = createViewModels();
      vms.task.addTask('期限なしの討伐', rank: QuestRank.B);
      vms.task.addTask('期限なしの討伐2', rank: QuestRank.S);
    });
    await pumpGuildScreen(
      tester,
      taskVM: vms.task,
      playerVM: vms.player,
      settingsVM: vms.settings,
      expandAllGroups: false,
    );
    return vms;
  }

  testWidgets('初回起動はパネルが畳まれていて、見出しだけが並ぶ', (tester) async {
    await pumpWithTwoTasks(tester);

    // 見出しは出る
    expect(find.byKey(QuestGroupKeys.header(QuestGroupBand.none)),
        findsOneWidget);
    expect(find.text('期限なし'), findsOneWidget);
    // 中身（カード）は出ない
    expect(find.byType(TaskCard), findsNothing);
  });

  testWidgets('見出しを押すと開き、もう一度押すと畳める', (tester) async {
    await pumpWithTwoTasks(tester);

    await tester.tap(find.byKey(QuestGroupKeys.header(QuestGroupBand.none)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsNWidgets(2));

    await tester.tap(find.byKey(QuestGroupKeys.header(QuestGroupBand.none)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsNothing);
  });

  testWidgets('全開ボタンで全て開き、もう一度で全て畳む', (tester) async {
    await pumpWithTwoTasks(tester);

    expect(find.byKey(AppKeys.guildToggleAllGroups), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildToggleAllGroups));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsNWidgets(2));

    await tester.tap(find.byKey(AppKeys.guildToggleAllGroups));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsNothing);
  });

  testWidgets('開いた状態は端末に保存され、次の起動で復元される', (tester) async {
    final vms = await pumpWithTwoTasks(tester);

    await tester.tap(find.byKey(QuestGroupKeys.header(QuestGroupBand.none)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsNWidgets(2));

    // 保存は非同期なので、書き込みが終わるまで進める
    await tester.pump(const Duration(milliseconds: 20));
    // 保存されていることを実測（空文字＝全て開いた）
    final prefs = await SharedPreferences.getInstance();
    // 開いた束（none）だけが保存値から外れ、他の束は畳んだまま残る
    final saved = prefs.getString('guild.collapsedGroups');
    expect(saved, isNotNull);
    expect(saved!.split(','), isNot(contains('none')));
    expect(saved.split(','), contains('overdue'));

    // 画面を作り直す＝次の起動
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpGuildScreen(
      tester,
      taskVM: vms.task,
      playerVM: vms.player,
      settingsVM: vms.settings,
      expandAllGroups: false,
    );
    expect(find.byType(TaskCard), findsNWidgets(2));
  });

  testWidgets('カレンダー表示の選択も保存され、次の起動で復元される', (tester) async {
    final vms = await pumpWithTwoTasks(tester);

    await tester.tap(find.byKey(AppKeys.guildViewCalendarToggle));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(AppKeys.questCalendarView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guild.viewMode'), 'calendar');

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpGuildScreen(
      tester,
      taskVM: vms.task,
      playerVM: vms.player,
      settingsVM: vms.settings,
      expandAllGroups: false,
    );
    expect(find.byKey(AppKeys.questCalendarView), findsOneWidget);
  });

  testWidgets('歯車は設定ハブへ直接遷移する（旧・設定メニューは廃止）', (tester) async {
    await pumpWithTwoTasks(tester);

    await tester.tap(find.byKey(AppKeys.settingsButton));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
    // 寄合所に残っていないこと（設定ハブ側のタイルのみ）
    expect(find.text('遊び方・ヘルプ'), findsNothing);
  });
}
