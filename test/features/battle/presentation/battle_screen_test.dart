import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/data/player_repository.dart';
import 'package:rpg_todo/features/guild/data/task_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// TypeAdapter を安全に登録する（他テストで登録済みの場合は無視）
void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
  try {
    Hive.registerAdapter(adapter);
  } on HiveError {
    // 既に登録済み
  }
}

void main() {
  group('BattleScreen 見積もり時間表示テスト', () {
    late Directory testDir;

    setUpAll(() async {
      testDir = Directory(
          '${Directory.systemTemp.path}/battle_screen_test_${DateTime.now().millisecondsSinceEpoch}');
      Hive.init(testDir.path);
      _safeRegisterAdapter(TaskAdapter());
      _safeRegisterAdapter(TaskStatusAdapter());
      _safeRegisterAdapter(QuestionRankAdapter());
      _safeRegisterAdapter(PlayerAdapter());
      _safeRegisterAdapter(JobAdapter());
      _safeRegisterAdapter(RepeatIntervalAdapter());
      _safeRegisterAdapter(SubTaskAdapter());
    });

    tearDownAll(() async {
      await Hive.close();
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
    });

    tearDown(() async {
      try {
        await Hive.deleteBoxFromDisk(PlayerRepository.boxName);
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk(TaskRepository.boxName);
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk('settingsBox');
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk('tutorialBox');
      } catch (_) {}
    });

    /// GameViewModel のロード完了を待つヘルパー
    Future<GameViewModel> createLoadedViewModel() async {
      final vm = GameViewModel();
      final start = DateTime.now();
      while (!vm.isLoaded) {
        if (DateTime.now().difference(start) > const Duration(seconds: 5)) {
          throw Exception('GameViewModel のロードがタイムアウトしました');
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
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

    // ━━━ 見積もり表示あり ━━━

    testWidgets(
        'activeTasks に targetTimeMinutes がある場合、'
        '「今日の戦い（見積もり）: XX分」が表示される', (tester) async {
      final vm = await        createLoadedViewModel();

      // 見積もり時間付きのタスクを追加して受注（active 状態にする）
      vm.addTask('テストクエスト', rank: QuestRank.B, targetTimeMinutes: 30);
      final taskId = vm.tasks.first.id;
      vm.acceptTask(taskId);

      await        pumpBattleScreen(tester, vm);

      // 見積もり時間のテキストが表示されていることを確認（完全一致）
      expect(find.text('今日の戦い（見積もり）: 30分'), findsOneWidget);
    });

    testWidgets('複数タスクの見積もり時間が合計表示される', (tester) async {
      final vm = await        createLoadedViewModel();

      // 2つのタスク（30分 + 45分 = 75分）
      vm.addTask('クエストA', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('クエストB', rank: QuestRank.A, targetTimeMinutes: 45);
      for (final t in List<Task>.from(vm.tasks)) {
        vm.acceptTask(t.id);
      }

      await        pumpBattleScreen(tester, vm);

      // 合計75分が表示されていることを確認
      expect(find.text('今日の戦い（見積もり）: 75分'), findsOneWidget);
    });

    // ━━━ 見積もり表示なし ━━━

    testWidgets(
        'activeTasks の targetTimeMinutes が null の場合、見積もり表示は出ない',
        (tester) async {
      final vm = await        createLoadedViewModel();

      // targetTimeMinutes なしのタスクを追加して受注
      vm.addTask('テストクエスト', rank: QuestRank.B);
      final taskId = vm.tasks.first.id;
      vm.acceptTask(taskId);

      await        pumpBattleScreen(tester, vm);

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
      final vm = await        createLoadedViewModel();

      // タスクがない状態 → dailyEstimatedMinutes = 0
      await        pumpBattleScreen(tester, vm);

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
