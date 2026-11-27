// クエスト管理ハブ（寄合所 ⋯ の唯一の入口）の試練。
//
// 2026-11-28: 溢れメニューの13項目を4節の1画面へまとめ、寄合所の入口を
// 「⋯ → クエスト管理」の1本にした。ここでは
//   ① ⋯に項目が1つしかない（入口が再び増えないための回帰門）
//   ② 4節・各項目が実在し、キーが移設前と同一である
//   ③ タップで各画面へ遷移する
// を撃つ。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_keys.dart';
import 'package:rpg_todo/features/guild/presentation/quest_management_screen.dart';
import 'package:rpg_todo/features/guild/presentation/quest_streak_keys.dart';
import 'package:rpg_todo/features/habits/presentation/screens/habit_calendar_screen.dart';

import 'dart:io';

import 'package:hive/hive.dart';

import 'guild_screen_test.dart' show createViewModels, pumpGuildScreen;

void main() {
  setUpAll(() async {
    // 習慣カレンダー画面が Hive の箱を開くため、テスト用パスを初期化する
    final dir = await Directory.systemTemp.createTemp('quest_management_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(30)) {
      Hive.registerAdapter(ReflectionAdapter());
    }
    await Hive.openBox<Reflection>('reflections');
    await Hive.openBox<String>('practice_logs');
  });

  testWidgets('⋯メニューの項目は「クエスト管理」の1つだけ', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.guildQuestManagementEntry), findsOneWidget);
    // 旧・13項目が寄合所のメニューへ戻っていないこと
    expect(find.byKey(AppKeys.guildOverflowTaskTemplate), findsNothing);
    expect(find.byKey(AppKeys.taskTemplateEntry), findsNothing);
    expect(find.byKey(AppKeys.guildOverflowBulkCreate), findsNothing);
    expect(find.byKey(AppKeys.guildOverflowHabitCalendar), findsNothing);
    expect(find.byKey(AppKeys.guildOverflowReminder), findsNothing);
    expect(find.byKey(AppKeys.guildCalendarExportEntry), findsNothing);
    expect(find.byKey(EstimateAccuracyKeys.guildEntry), findsNothing);
    expect(find.byKey(QuestStreakKeys.guildEntry), findsNothing);
  });

  testWidgets('ハブに4節と全項目が並ぶ（剣士＝繰り返し任務なし）', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);
    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.guildQuestManagementEntry));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.questManagementScreen), findsOneWidget);
    for (final label in ['つくる', 'ふりかえる', 'カレンダー', 'しらせる']) {
      expect(find.text(label), findsOneWidget, reason: '$label 節が無い');
    }
    // 移設前と同一キーで辿れること
    expect(find.byKey(AppKeys.taskTemplateEntry), findsOneWidget);
    expect(find.byKey(AppKeys.guildOverflowBulkCreate), findsOneWidget);
    expect(find.byKey(AppKeys.habitCalendarEntry), findsOneWidget);
    expect(find.byKey(EstimateAccuracyKeys.guildEntry), findsOneWidget);
    expect(find.byKey(QuestStreakKeys.guildEntry), findsOneWidget);
    expect(find.byKey(AppKeys.guildCalendarExportEntry), findsOneWidget);
    expect(find.byKey(AppKeys.guildCalendarImportEntry), findsOneWidget);
    expect(find.byKey(AppKeys.reminderSettingsEntry), findsOneWidget);
    // 僧侶でなければ繰り返し任務一覧は出ない（段階開示）
    expect(find.byKey(AppKeys.guildOverflowRecurringTasks), findsNothing);
  });

  testWidgets('僧侶なら繰り返し任務一覧も出る（段階開示）', (tester) async {
    final vms = createViewModels();
    vms.player.player = vms.player.player.copyWith(
      currentJob: Job.monk,
      jobLevels: const {Job.monk: 1},
    );
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);
    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.guildQuestManagementEntry));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.guildOverflowRecurringTasks), findsOneWidget);
  });

  testWidgets('項目を押すと目的の画面へ遷移する（習慣カレンダー）', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);
    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.guildQuestManagementEntry));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.habitCalendarEntry));
    await tester.pumpAndSettle();

    expect(find.byType(HabitCalendarScreen), findsOneWidget);
  });

  test('ハブは StatefulWidget（ダイアログ二重開きの抑止を持つ）', () {
    expect(const QuestManagementScreen(), isA<StatefulWidget>());
  });
}
