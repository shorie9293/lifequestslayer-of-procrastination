import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
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

/// テスト用のDI注入済みGameViewModelを生成し、ロード完了まで待つ
/// tester.runAsync() 内で呼び出す必要あり（非同期loadDataとの衝突回避）
Future<GameViewModel> createLoadedViewModel() async {
  final vm = GameViewModel(
    pr: _MockPlayerRepository(),
    tr: _MockTaskRepository(),
    sr: _MockSettingsRepository(),
  );

  final start = DateTime.now();
  while (!vm.isLoaded) {
    if (DateTime.now().difference(start) > const Duration(seconds: 5)) {
      throw Exception('GameViewModel のロードがタイムアウトしました');
    }
    await Future.delayed(const Duration(milliseconds: 10));
  }
  // loadData() 内の後続処理（autoDeploy等）の完了を待つ
  await Future.delayed(const Duration(milliseconds: 50));
  return vm;
}

/// BattleScreen をポンプするヘルパー
Future<void> pumpBattleScreen(WidgetTester tester, GameViewModel vm) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<GameViewModel>.value(
      value: vm,
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
      late GameViewModel vm;

      // runAsync 内でVMを生成し loadData() の非同期処理を完了させる
      await tester.runAsync(() async {
        vm = await createLoadedViewModel();

        // 見積もり時間付きのタスクを追加して受注（active 状態にする）
        vm.addTask('テストクエスト', rank: QuestRank.B, targetTimeMinutes: 30);
        final taskId = vm.tasks.first.id;
        vm.acceptTask(taskId);
      });

      await pumpBattleScreen(tester, vm);

      // 見積もり時間のテキストが表示されていることを確認（完全一致）
      expect(find.text('今日の戦い（見積もり）: 30分'), findsOneWidget);
    });

    testWidgets('複数タスクの見積もり時間が合計表示される', (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();

        // 2つのタスク（30分 + 45分 = 75分、両方Bランクで受注可能）
        // デフォルトLv1ではBランク1枠しかないのでLv2に昇格
        vm.player.jobLevels[vm.player.currentJob] = 2;
        vm.addTask('クエストA', rank: QuestRank.B, targetTimeMinutes: 30);
        vm.addTask('クエストB', rank: QuestRank.B, targetTimeMinutes: 45);
        for (final t in List<Task>.from(vm.tasks)) {
          vm.acceptTask(t.id);
        }
      });

      await pumpBattleScreen(tester, vm);

      // 合計75分が表示されていることを確認
      expect(find.text('今日の戦い（見積もり）: 75分'), findsOneWidget);
    });

    // ━━━ 見積もり表示なし ━━━

    testWidgets(
        'activeTasks の targetTimeMinutes が null の場合、見積もり表示は出ない',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();

        // targetTimeMinutes なしのタスクを追加して受注
        vm.addTask('テストクエスト', rank: QuestRank.B);
        final taskId = vm.tasks.first.id;
        vm.acceptTask(taskId);
      });

      await pumpBattleScreen(tester, vm);

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
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
        // タスクを追加しない → dailyEstimatedMinutes = 0
      });

      await pumpBattleScreen(tester, vm);

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
}
