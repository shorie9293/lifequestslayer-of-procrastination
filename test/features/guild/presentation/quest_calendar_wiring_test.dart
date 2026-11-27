// 寄合所のカレンダー表示（配線）の試練。
//
// 純粋関数側は domain/quest_calendar_test.dart が撃つ。ここは
// 「切替チップ → カレンダーが描かれる → マスを押すとその日が出る →
//  月送りが効く → 一覧へ戻れる」という配線だけを撃つ。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_grouping.dart';
import 'package:rpg_todo/features/guild/presentation/quest_group_keys.dart';

import 'guild_screen_test.dart' show createViewModels, pumpGuildScreen;

String dateId(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('切替チップでカレンダーが描かれ、見出しが当月になる', (tester) async {
    final vms = createViewModels();
    await tester.runAsync(() async {
      vms.task.addTask('期限つきの討伐', rank: QuestRank.A);
    });
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    // 既定は一覧
    expect(find.byKey(AppKeys.questCalendarView), findsNothing);
    expect(find.byKey(AppKeys.guildViewCalendarToggle), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildViewCalendarToggle));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(AppKeys.questCalendarView), findsOneWidget);
    final now = DateTime.now();
    expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
    // マスは常に42（6週×7日）
    final cells = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('cell_quest_calendar_'));
    expect(tester.widgetList(cells).length, 42);
  });

  testWidgets('マスを押すとその日のクエストが下から出る', (tester) async {
    final today = DateTime.now();
    final vms = createViewModels();
    await tester.runAsync(() async {
      vms.task.addTask('今日が期限の討伐', rank: QuestRank.S, deadline: today);
    });
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildViewCalendarToggle));
    await tester.pump();
    await tester.pump();

    final cellFinder = find.byKey(AppKeys.questCalendarCell(dateId(today)));
    // マスは縦に伸びるので、画面外なら先にスクロールして見えるようにする
    await tester.ensureVisible(cellFinder);
    await tester.pump();
    await tester.tap(cellFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.questCalendarDaySheet), findsOneWidget);
    expect(find.text('今日が期限の討伐'), findsOneWidget);
    expect(find.textContaining('${today.month}月${today.day}日'), findsWidgets);
  });

  testWidgets('期限の無いクエストは「期限のないクエスト」行に出る', (tester) async {
    final vms = createViewModels();
    await tester.runAsync(() async {
      vms.task.addTask('期限なしの討伐', rank: QuestRank.B);
    });
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildViewCalendarToggle));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(AppKeys.questCalendarUndatedRow), findsOneWidget);
    expect(find.text('期限のないクエスト: 1件'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.questCalendarUndatedRow));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.questCalendarDaySheet), findsOneWidget);
    expect(find.text('期限のないクエスト'), findsWidgets);
  });

  testWidgets('月送りが効き、「今日」で当月へ戻る', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildViewCalendarToggle));
    await tester.pump();
    await tester.pump();

    final now = DateTime.now();
    String labelOf(int delta) {
      final m = DateTime(now.year, now.month + delta, 1);
      return '${m.year}年${m.month}月';
    }

    await tester.tap(find.byKey(AppKeys.questCalendarNextMonth));
    await tester.pump();
    expect(find.text(labelOf(1)), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.questCalendarPrevMonth));
    await tester.pump();
    expect(find.text(labelOf(0)), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.questCalendarPrevMonth));
    await tester.pump();
    expect(find.text(labelOf(-1)), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.questCalendarToday));
    await tester.pump();
    expect(find.text(labelOf(0)), findsOneWidget);
  });

  testWidgets('一覧へ戻るとカレンダーは消え、束ね方チップが戻る', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildViewCalendarToggle));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(AppKeys.questCalendarView), findsOneWidget);
    // 束ね方（期日/ランク）はカレンダーでは意味を持たないので出さない
    expect(find.byKey(QuestGroupKeys.modeButton(QuestGroupMode.rank)), findsNothing);

    await tester.tap(find.byKey(AppKeys.guildViewListToggle));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(AppKeys.questCalendarView), findsNothing);
    expect(find.byKey(QuestGroupKeys.modeButton(QuestGroupMode.rank)), findsOneWidget);
  });
}
