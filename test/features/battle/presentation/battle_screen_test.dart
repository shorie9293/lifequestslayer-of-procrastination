import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

// ━━━ DI Mock リポジトリ（Hive非依存） ━━━

class _MockPlayerRepository implements IPlayerRepository {
  @override
  Future<Player?> loadPlayer() async => Player();
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class _MockTaskRepository implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

/// SettingsRepository は具象クラスのため extend して全Hiveメソッドをオーバーライド
class _MockSettingsRepository extends SettingsRepository {
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<void> setFontSizeScale(double scale) async {}
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<void> setKnowledgeQuestEnabled(bool enabled) async {}
  @override
  Future<void> saveFatiguePopupDate(DateTime date) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<void> setTutorialStep(int step) async {}
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<void> setHasSeenConcept(bool value) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool value) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<void> setTutorialChoiceMade(bool value) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<void> setJobTutorialCompleted(bool value) async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
}

/// テスト用のDI注入済みViewModel群を生成
({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings})
    createViewModels() {
  final playerVM = PlayerViewModel(_MockPlayerRepository());
  final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(_MockSettingsRepository());
  return (task: taskVM, player: playerVM, settings: settingsVM);
}

/// BattleScreen をポンプするヘルパー
Future<void> pumpBattleScreen(
  WidgetTester tester, {
  required TaskViewModel taskVM,
  required PlayerViewModel playerVM,
  required SettingsViewModel settingsVM,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
      ],
      child: const MaterialApp(
        home: BattleScreen(),
      ),
    ),
  );
  // 画面が完全に描画されるのを待つ
  await tester.pump();
  await tester.pump();
}

void main() {
  group('BattleScreen 見積もり時間表示テスト', () {
    // ━━━ 見積もり表示あり ━━━

    testWidgets(
        'activeTasks に targetTimeMinutes がある場合、'
        '「今日の戦い（見積もり）: XX分」が表示される', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      // runAsync 内でVMを生成
      await tester.runAsync(() async {
        vms = createViewModels();

        // 見積もり時間付きのタスクを追加して受注（active 状態にする）
        vms.task.addTask('テストクエスト', rank: QuestRank.B, targetTimeMinutes: 30);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // 見積もり時間のテキストが表示されていることを確認（完全一致）
      expect(find.text('今日の戦い（見積もり）: 30分'), findsOneWidget);
    });

    testWidgets('複数タスクの見積もり時間が合計表示される', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();

        // 2つのタスク（30分 + 45分 = 75分、両方Bランクで受注可能）
        // デフォルトLv1ではBランク1枠しかないのでLv2に昇格
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('クエストA', rank: QuestRank.B, targetTimeMinutes: 30);
        vms.task.addTask('クエストB', rank: QuestRank.B, targetTimeMinutes: 45);
        for (final t in List<Task>.from(vms.task.tasks)) {
          vms.task.acceptTask(t.id);
        }
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // 合計75分が表示されていることを確認
      expect(find.text('今日の戦い（見積もり）: 75分'), findsOneWidget);
    });

    // ━━━ 見積もり表示なし ━━━

    testWidgets(
        'activeTasks の targetTimeMinutes が null の場合、見積もり表示は出ない',
        (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();

        // targetTimeMinutes なしのタスクを追加して受注
        vms.task.addTask('テストクエスト', rank: QuestRank.B);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // 見積もり時間のテキストが表示されていないことを確認
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('今日の戦い（見積もり）'),
        ),
        findsNothing,
      );
    });

    testWidgets('見積もり0分（タスクなし）の場合は表示されない', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();
        // タスクを追加しない → dailyEstimatedMinutes = 0
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // 見積もり表示は存在しない
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('今日の戦い（見積もり）'),
        ),
        findsNothing,
      );

      // 空状態が表示されている（AppKeyで検証）
      expect(find.byKey(AppKeys.battleEmptyState), findsOneWidget);
    });
  });

  // ━━━ M4禍津: タスク連打でダイアログ多重表示 ━━━

  group('M4 タスク連打ガードテスト', () {
    testWidgets('タスク完了ボタンを連打してもダイアログは1つだけ表示される',
        (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;
      late String taskId;

      await tester.runAsync(() async {
        vms = createViewModels();
        // Lv2に上げてBランク受注可能にする
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('連打テスト', rank: QuestRank.B);
        taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTile を展開して完了ボタンを表示させる
      final taskTitle = find.text('[B] 連打テスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 完了ボタン（⚔️）を探す
      final completeButton = find.byTooltip('討つ！');
      expect(completeButton, findsOneWidget);

      // 連打: 2回連続でタップ（同一フレーム内で2度実行されるように）
      await tester.tap(completeButton);
      await tester.tap(completeButton);
      await tester.pump();

      // パーティクルエフェクトが1つだけ存在することを確認
      // 連打ガードにより2つ目がブロックされ、1つの ParticleBurst のみ表示
      await tester.pump(const Duration(milliseconds: 100));
      final particleTexts = find.text('討伐完了\n💥');
      expect(particleTexts, findsOneWidget);
    });
  });

  // ━━━ M5禍津: maybePop() が無関係ダイアログを閉じる ━━━

  group('M5 maybePop 無関係ダイアログテスト', () {
    testWidgets('タスク完了後、先に開いていたダイアログが閉じられない',
        (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;
      late String taskId;

      await tester.runAsync(() async {
        vms = createViewModels();
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('M5テスト', rank: QuestRank.B);
        taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTile を展開して完了ボタンを表示させる
      final taskTitle = find.text('[B] M5テスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 完了ボタン（⚔️）をタップしてタスク完了
      // ParticleBurst 完了後に Navigator.pop(ctx) が呼ばれることを検証
      final completeButton = find.byTooltip('討つ！');
      expect(completeButton, findsOneWidget);
      await tester.tap(completeButton);
      await tester.pump();

      // ParticleBurst が表示されるのを待つ
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('討伐完了\n💥'), findsOneWidget);

      // ParticleBurst のアニメーション完了を待つ（pumpAndSettle で確実に）
      // Navigator.of(ctx).pop() が呼ばれ ParticleBurst ダイアログが閉じられる
      await tester.pumpAndSettle(const Duration(milliseconds: 2000));

      // ParticleBurst ダイアログが閉じられたことを確認
      expect(find.text('討伐完了\n💥'), findsNothing);
    });
  });
}
