// 寄合所 AppBar 3+1 集約・職業チップ・プロジェクト欄の試練（v1.5.23）
//
// - ⋯オーバーフローメニューに集約された項目が従来の遷移を果たすこと
// - 職業チップが描画され、タップでスキルプルダウンが開くこと
// - 未解放スキルはタップ不可、計画の陣（解放済み）は ProjectListScreen へ遷移
// - クエスト作成ダイアログのプロジェクト欄（canUseProjectSkill true/false）

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/create_task_dialog.dart';
import 'package:rpg_todo/features/project/domain/project_service.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

import 'guild_screen_test.dart' show createViewModels, pumpGuildScreen;

/// Mystic Lv12 の Player（計画の陣=解放、俯瞰の魔眼=未解放）。
Player mysticPlayer() => Player().copyWith(
      currentJob: Job.mystic,
      jobLevels: const {Job.mystic: 12},
    );

/// 法師の Player（繰り返し任務一覧の解放条件）。
Player monkPlayer() => Player().copyWith(
      currentJob: Job.monk,
      jobLevels: const {Job.monk: 1},
    );

void main() {
  setUpAll(() async {
    // HabitCalendarScreen が Hive box を開くためテスト用パスを初期化
    final dir = await Directory.systemTemp.createTemp('guild_agg_test');
    Hive.init(dir.path);
    Hive.registerAdapter(ReflectionAdapter());
    await Hive.openBox<Reflection>('reflections');
    await Hive.openBox<String>('practice_logs');
  });

  testWidgets('AppBar バージョン標識が v1.5.24+120 に同期している', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);
    expect(find.text('v1.5.24+120'), findsOneWidget);
  });

  testWidgets('⋯メニューから勤行の定型へ遷移できる', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.guildOverflowTaskTemplate), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.taskTemplateEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.taskTemplateScreen), findsOneWidget);
    expect(find.text('勤行の定型'), findsOneWidget);
  });

  testWidgets('⋯メニューから勤行の習慣カレンダーへ遷移でき、リマインダー項目もある', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.guildOverflowHabitCalendar), findsOneWidget);
    expect(find.byKey(AppKeys.guildOverflowReminder), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.habitCalendarEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.habitCalendarScreen), findsOneWidget);
  });

  testWidgets('monk では⋯メニューに繰り返し任務一覧が出る', (tester) async {
    final vms = createViewModels();
    vms.player.player = monkPlayer();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.guildOverflowRecurringTasks), findsOneWidget);
  });

  testWidgets('職業チップが描画される', (tester) async {
    final vms = createViewModels();
    vms.player.player = mysticPlayer();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);
    expect(find.byKey(AppKeys.guildJobChip), findsOneWidget);
    expect(find.text('陰陽師'), findsOneWidget);
  });

  testWidgets('職業チップをタップするとスキルプルダウンが開き、解放状態が正しい', (tester) async {
    final vms = createViewModels();
    vms.player.player = mysticPlayer();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildJobChip));
    await tester.pumpAndSettle();

    // Mystic の4スキルが揃う
    for (final s in JobSkill.values.where((s) => s.job == Job.mystic)) {
      expect(find.byKey(AppKeys.guildJobSkillItem(s)), findsOneWidget,
          reason: '${s.name} がメニューに存在すること');
    }
    // 解放済み: 分割の理(Lv1)・札の掌握(Lv5)・計画の陣(Lv10)
    final unlockedMenu = tester.widget<PopupMenuItem<JobSkill>>(
      find.byKey(AppKeys.guildJobSkillItem(JobSkill.mysticSubtask)),
    );
    expect(unlockedMenu.enabled, isTrue);
    // 未解放: 俯瞰の魔眼(Lv15)
    final lockedMenu = tester.widget<PopupMenuItem<JobSkill>>(
      find.byKey(AppKeys.guildJobSkillItem(JobSkill.mysticOverview)),
    );
    expect(lockedMenu.enabled, isFalse);
  });

  testWidgets('解放済みスキル（計画の陣）で ProjectListScreen へ遷移する', (tester) async {
    final vms = createViewModels();
    vms.player.player = mysticPlayer();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildJobChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.guildJobSkillItem(JobSkill.mysticProject)));
    await tester.pumpAndSettle();

    expect(find.text('計画の陣'), findsWidgets,
        reason: 'ProjectListScreen の AppBar タイトルへ遷移していること');
  });

  testWidgets('解放済みの他スキルは説明文の SnackBar を出す', (tester) async {
    final vms = createViewModels();
    vms.player.player = mysticPlayer();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildJobChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.guildJobSkillItem(JobSkill.mysticSubtask)));
    await tester.pump();

    expect(find.textContaining('サブクエスト'), findsOneWidget,
        reason: 'JobSkillMeta.description が SnackBar で表示されること');
  });

  testWidgets('未解放スキルはタップ不可（メニューが閉じず遷移もしない）', (tester) async {
    final vms = createViewModels();
    vms.player.player = mysticPlayer();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildJobChip));
    await tester.pumpAndSettle();

    final item = find.byKey(AppKeys.guildJobSkillItem(JobSkill.mysticOverview));
    await tester.tap(item, warnIfMissed: false);
    await tester.pump();

    // enabled:false なので onSelected は呼ばれず、SnackBar も出ない
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('計画の陣が使えるときダイアログにプロジェクト欄が出る', (tester) async {
    final vms = createViewModels();
    vms.player.player = mysticPlayer();
    expect(ProjectService.canUseProjectSkill(vms.player.player), isTrue);
    await _pumpDialog(tester, vms);
    expect(find.byKey(AppKeys.createTaskProjectField), findsOneWidget);
  });

  testWidgets('計画の陣が使えないときプロジェクト欄は出ない', (tester) async {
    final vms = createViewModels();
    expect(ProjectService.canUseProjectSkill(vms.player.player), isFalse);
    await _pumpDialog(tester, vms);
    expect(find.byKey(AppKeys.createTaskProjectField), findsNothing);
  });
}

/// CreateTaskDialog を直接ポンプする（GuildScreen の FAB は画面下で視野外のため）。
Future<void> _pumpDialog(
  WidgetTester tester,
  ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: vms.task),
        ChangeNotifierProvider<PlayerViewModel>.value(value: vms.player),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const CreateTaskDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}