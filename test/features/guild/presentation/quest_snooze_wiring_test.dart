// 微睡みの加護（クエストのスヌーズ）UI接続の試練 — v1.5.47
//
// - TaskCard のスヌーズ済みバッジ（additive パラメータ）
// - 寄合所の実行導線が monkSnooze 解放時のみ出ること
// - 確認ダイアログ → 期限 +1日 → 永続化（saveTasks 到達）
// - 期限なし・未知IDは no-op（例外を投げない）

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

import 'guild_screen_test.dart' show createViewModels, pumpGuildScreen;

// ━━━ フェイクリポジトリ（Hive非依存） ━━━

class _FakePlayerRepository implements IPlayerRepository {
  Player? saved;
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => Player();
  @override
  Future<void> savePlayer(Player player) async {
    saved = player;
  }

  @override
  Future<void> close() async {}
}

class _RecordingTaskRepository implements ITaskRepository {
  int saveCount = 0;
  List<Task> lastSaved = const [];
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {
    saveCount++;
    lastSaved = List<Task>.of(tasks);
  }

  @override
  Future<void> close() async {}
}

/// 法師 Lv5（monkSnooze 解放）の Player。
Player monkLv5Player() => Player().copyWith(
      currentJob: Job.monk,
      jobLevels: const {Job.monk: 5},
    );

/// スヌーズ導線の対象になる非緊急クエスト（期限は1日以上先）。
Task snoozeTargetTask() => Task(
      id: 'q1',
      title: '修行の巻物を読み解く',
      deadline: DateTime(2030, 10, 21, 21, 0),
    );

/// 緊急セクション（期限24時間以内）の対象クエスト。相対期限で時限爆弾を避ける。
Task urgentSnoozeTask() => Task(
      id: 'urgent1',
      title: '迫る締切の討伐依頼',
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );

/// TaskCard を単体でポンプする。
Future<void> pumpTaskCard(
  WidgetTester tester, {
  required Task task,
  bool isSnoozed = false,
  String? snoozeLabel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TaskCard(
          task: task,
          actions: const [],
          isUrgent: false,
          isSnoozed: isSnoozed,
          snoozeLabel: snoozeLabel,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    // GuildScreen 配下の Hive 依存（習慣カレンダー等）の初期化
    final dir = await Directory.systemTemp.createTemp('quest_snooze_wiring');
    Hive.init(dir.path);
    Hive.registerAdapter(ReflectionAdapter());
    await Hive.openBox<Reflection>('reflections');
    await Hive.openBox<String>('practice_logs');
  });

  group('TaskCard スヌーズ済みバッジ', () {
    testWidgets('isSnoozed: true + snoozeLabel でバッジが出る', (tester) async {
      final task = snoozeTargetTask();
      await pumpTaskCard(tester,
          task: task, isSnoozed: true, snoozeLabel: '微睡み 10/21');

      expect(find.byKey(AppKeys.questSnoozeBadge(task.id)), findsOneWidget);
      expect(find.text('微睡み 10/21'), findsOneWidget);
    });

    testWidgets('既定（未指定）ではバッジが出ない', (tester) async {
      final task = snoozeTargetTask();
      await pumpTaskCard(tester, task: task);

      expect(find.byKey(AppKeys.questSnoozeBadge(task.id)), findsNothing);
      expect(find.textContaining('微睡み'), findsNothing);
    });
  });

  group('寄合所の実行導線の解放判定', () {
    testWidgets('Adventurer Lv1（monk未解放）では導線が出ない', (tester) async {
      final vms = createViewModels();
      final task = snoozeTargetTask();
      vms.task.setTasks([task]);
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);

      expect(vms.player.player.hasSkill(JobSkill.monkSnooze), isFalse);
      expect(find.byKey(AppKeys.questSnoozeButton(task.id)), findsNothing);
    });

    testWidgets('Monk Lv5 なら「微睡みの加護」導線が出る', (tester) async {
      final vms = createViewModels();
      final task = snoozeTargetTask();
      vms.task.setTasks([task]);
      vms.player.player = monkLv5Player();
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);

      expect(vms.player.player.hasSkill(JobSkill.monkSnooze), isTrue);
      await _expandCard(tester, task.id);
      expect(find.byKey(AppKeys.questSnoozeButton(task.id)), findsOneWidget);
    });
  });

  group('確認ダイアログ → 期限 +1日', () {
    testWidgets('確定で期限がちょうど1日延び、SnackBar が出る', (tester) async {
      final vms = createViewModels();
      final task = snoozeTargetTask();
      final before = task.deadline!;
      vms.task.setTasks([task]);
      vms.player.player = monkLv5Player();
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);
      await _expandCard(tester, task.id);

      await tester.tap(find.byKey(AppKeys.questSnoozeButton(task.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 延期後の日付（10/22）を含む確認文言
      expect(find.textContaining('10/22'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.questSnoozeConfirmButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(vms.task.tasks.first.deadline, before.add(const Duration(days: 1)));
      expect(vms.player.player.snoozedTasks.containsKey('q1'), isTrue);
      expect(find.text('微睡みの加護 — 期限を1日延ばした'), findsOneWidget);
    });

    testWidgets('期限なしクエストではダイアログを出さず理由を SnackBar で伝える',
        (tester) async {
      final vms = createViewModels();
      final task = Task(id: 'nodl', title: '期限なしの依頼');
      vms.task.setTasks([task]);
      vms.player.player = monkLv5Player();
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);
      await _expandCard(tester, task.id);

      await tester.tap(find.byKey(AppKeys.questSnoozeButton(task.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(AppKeys.questSnoozeConfirmButton), findsNothing);
      expect(find.text('期限が無いため微睡めません'), findsOneWidget);
      expect(vms.task.tasks.first.deadline, isNull);
    });
  });

  group('スヌーズ済み表示（寄合所）', () {
    testWidgets('snoozedTasks を注入するとカードにバッジが出る', (tester) async {
      final vms = createViewModels();
      final task = snoozeTargetTask();
      vms.task.setTasks([task]);
      vms.player.player = monkLv5Player().copyWith(
        snoozedTasks: {'q1': DateTime(2030, 10, 20)},
      );
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);

      expect(find.byKey(AppKeys.questSnoozeBadge(task.id)), findsOneWidget);
      expect(find.text('微睡み 10/20'), findsOneWidget);
    });
  });

  group('緊急セクションの微睡み', () {
    testWidgets('期限24時間以内＋Monk Lv5 なら緊急行にスヌーズ導線が出る', (tester) async {
      final vms = createViewModels();
      final task = urgentSnoozeTask();
      vms.task.setTasks([task]);
      vms.player.player = monkLv5Player();
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);

      expect(find.byKey(AppKeys.guildUrgentSection), findsOneWidget);
      expect(find.text('緊急クエスト'), findsOneWidget);
      expect(find.byKey(AppKeys.questSnoozeButton(task.id)), findsOneWidget);
      // 既存の緊急行ボタンは健在
      expect(find.byKey(AppKeys.urgentDelete), findsOneWidget);
    });

    testWidgets('monkSnooze 未解放なら緊急行にスヌーズ導線は出ない', (tester) async {
      final vms = createViewModels();
      final task = urgentSnoozeTask();
      vms.task.setTasks([task]);
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);

      expect(vms.player.player.hasSkill(JobSkill.monkSnooze), isFalse);
      expect(find.byKey(AppKeys.guildUrgentSection), findsOneWidget);
      expect(find.byKey(AppKeys.questSnoozeButton(task.id)), findsNothing);
      expect(find.byKey(AppKeys.urgentDelete), findsOneWidget);
    });

    testWidgets('緊急行で確定すると期限がちょうど+1日され、緊急セクションが消える',
        (tester) async {
      final vms = createViewModels();
      final task = urgentSnoozeTask();
      final before = task.deadline!;
      vms.task.setTasks([task]);
      vms.player.player = monkLv5Player();
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);

      await tester.tap(find.byKey(AppKeys.questSnoozeButton(task.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(AppKeys.questSnoozeConfirmButton), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.questSnoozeConfirmButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(vms.task.tasks.first.deadline, before.add(const Duration(days: 1)));
      // 期限が24時間超へ退避したため緊急セクションは消える
      expect(find.byKey(AppKeys.guildUrgentSection), findsNothing);
      expect(find.text('緊急クエスト'), findsNothing);
    });

    testWidgets('スヌーズ記録を注入すると緊急行にバッジが出る', (tester) async {
      final vms = createViewModels();
      final task = urgentSnoozeTask();
      vms.task.setTasks([task]);
      vms.player.player = monkLv5Player().copyWith(
        snoozedTasks: {task.id: DateTime(2030, 10, 20)},
      );
      await tester.pump();
      await pumpGuildScreen(
          tester,
          taskVM: vms.task,
          playerVM: vms.player,
          settingsVM: vms.settings);

      expect(find.byKey(AppKeys.guildUrgentSection), findsOneWidget);
      expect(find.byKey(AppKeys.questSnoozeBadge(task.id)), findsOneWidget);
      expect(find.text('微睡み 10/20'), findsOneWidget);
    });
  });

  group('TaskViewModel.snoozeTask の永続化と no-op', () {
    test('リポジトリの saveTasks に到達し、プレイヤーも保存される', () async {
      final playerRepo = _FakePlayerRepository();
      final taskRepo = _RecordingTaskRepository();
      final playerVM = PlayerViewModel(playerRepo);
      final taskVM = TaskViewModel(taskRepo, playerVM);
      final task = snoozeTargetTask();
      taskVM.setTasks([task]);
      await playerVM.load();
      playerVM.player = monkLv5Player();

      final ok = taskVM.snoozeTask('q1', now: DateTime(2026, 10, 21, 12));

      expect(ok, isTrue);
      expect(task.deadline, DateTime(2030, 10, 22, 21, 0));
      expect(taskVM.tasks.first.deadline, DateTime(2030, 10, 22, 21, 0));
      // saveTasks は save() 経由で1回以上到達する
      await Future<void>.delayed(Duration.zero);
      expect(taskRepo.saveCount, greaterThanOrEqualTo(1));
      expect(taskRepo.lastSaved.first.deadline, DateTime(2030, 10, 22, 21, 0));

      // プレイヤー側の記録も永続化対象になっている（autoSave は非同期）
      await Future<void>.delayed(Duration.zero);
      expect(playerVM.player.snoozedTasks['q1'], DateTime(2026, 10, 21, 12));
    });

    test('未知IDは false を返し例外を投げない', () {
      final playerVM = PlayerViewModel(_FakePlayerRepository());
      final taskVM = TaskViewModel(_RecordingTaskRepository(), playerVM);
      taskVM.setTasks([snoozeTargetTask()]);
      playerVM.player = monkLv5Player();

      expect(() => taskVM.snoozeTask('missing-id'), returnsNormally);
      expect(taskVM.snoozeTask('missing-id'), isFalse);
      expect(playerVM.player.snoozedTasks, isEmpty);
    });

    test('期限なしは false（期限もスヌーズ記録も変化しない）', () {
      final playerVM = PlayerViewModel(_FakePlayerRepository());
      final taskVM = TaskViewModel(_RecordingTaskRepository(), playerVM);
      final task = Task(id: 'nodl', title: '期限なし');
      taskVM.setTasks([task]);
      playerVM.player = monkLv5Player();

      expect(taskVM.snoozeTask('nodl'), isFalse);
      expect(taskVM.tasks.first.deadline, isNull);
      expect(playerVM.player.snoozedTasks, isEmpty);
    });

    test('monkSnooze 未解放なら false（期限は変わらない）', () {
      final playerVM = PlayerViewModel(_FakePlayerRepository());
      final taskVM = TaskViewModel(_RecordingTaskRepository(), playerVM);
      final task = snoozeTargetTask();
      taskVM.setTasks([task]);

      expect(taskVM.snoozeTask('q1'), isFalse);
      expect(taskVM.tasks.first.deadline, DateTime(2030, 10, 21, 21, 0));
    });
  });
}

/// 寄合所のカードを展開して actions（実行導線）を可視化する。
Future<void> _expandCard(WidgetTester tester, String taskId) async {
  await tester.tap(find.byKey(Key('card_task_$taskId')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
