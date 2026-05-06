import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
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
  group('GuildScreen 見積もり時間表示テスト', () {
    late Directory testDir;

    setUpAll(() async {
      testDir = Directory(
          '${Directory.systemTemp.path}/guild_screen_test_${DateTime.now().millisecondsSinceEpoch}');
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

    /// GuildScreen をポンプするヘルパー
    Future<void> pumpGuildScreen(WidgetTester tester, GameViewModel vm) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<GameViewModel>.value(
          value: vm,
          child: const MaterialApp(
            home: GuildScreen(),
          ),
        ),
      );
      // 画面が完全に描画されるのを待つ
      await tester.pump();
      await tester.pump();
    }

    // ━━━ 見積もり表示あり ━━━

    testWidgets(
        'ギルドタスクに targetTimeMinutes がある場合、'
        '「未着手の依頼（見積もり）: XX分」が表示される', (tester) async {
      final vm = await        createLoadedViewModel();

      // 見積もり時間付きのタスクを追加（受注しない → guildTasks に留まる）
      vm.addTask('討伐クエスト', rank: QuestRank.B, targetTimeMinutes: 45);

      await        pumpGuildScreen(tester, vm);

      // 見積もり時間のテキストが表示されていることを確認（完全一致）
      expect(find.text('未着手の依頼（見積もり）: 45分'), findsOneWidget);
    });

    testWidgets('複数ギルドタスクの見積もりが合計表示される', (tester) async {
      final vm = await        createLoadedViewModel();

      vm.addTask('クエストA', rank: QuestRank.B, targetTimeMinutes: 20);
      vm.addTask('クエストB', rank: QuestRank.A, targetTimeMinutes: 35);
      vm.addTask('クエストC', rank: QuestRank.S, targetTimeMinutes: 60);

      await        pumpGuildScreen(tester, vm);

      // 合計115分が表示されていることを確認
      expect(find.text('未着手の依頼（見積もり）: 115分'), findsOneWidget);
    });

    testWidgets(
        'ギルドタスクの一部だけ targetTimeMinutes がある場合、'
        'あるものだけ合計される', (tester) async {
      final vm = await        createLoadedViewModel();

      // 見積もりありのタスクと、なしのタスクを混在させる
      vm.addTask('見積もりあり', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('見積もりなし', rank: QuestRank.B);

      await        pumpGuildScreen(tester, vm);

      // 30分のみの合計が表示される
      expect(find.text('未着手の依頼（見積もり）: 30分'), findsOneWidget);
    });

    // ━━━ 見積もり表示なし ━━━

    testWidgets(
        'ギルドタスクの targetTimeMinutes が null の場合、見積もり表示は出ない',
        (tester) async {
      final vm = await        createLoadedViewModel();

      // targetTimeMinutes なしのタスクを追加
      vm.addTask('テストクエスト', rank: QuestRank.B);

      await        pumpGuildScreen(tester, vm);

      // 見積もり時間のテキストが表示されていないことを確認
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('未着手の依頼（見積もり）'),
        ),
        findsNothing,
      );
    });

    testWidgets('タスクがない場合は見積もり表示が出ない', (tester) async {
      final vm = await        createLoadedViewModel();

      // タスクなし
      await        pumpGuildScreen(tester, vm);

      // 見積もり表示は存在しない
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('未着手の依頼（見積もり）'),
        ),
        findsNothing,
      );

      // 空状態が表示されている（AppKeyで検証）
      expect(find.byKey(AppKeys.guildEmptyState), findsOneWidget);
    });
  });
}
