import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/create_task_dialog.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// Hive非依存のインメモリ PlayerRepository モック
class _MockPlayerRepo implements IPlayerRepository {
  Player _player = Player();
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

/// Hive非依存のインメモリ TaskRepository モック
class _MockTaskRepo implements ITaskRepository {
  final List<Task> _tasks = [];
  @override
  Future<List<Task>> loadTasks() async => List.from(_tasks);
  @override
  Future<void> saveTasks(List<Task> tasks) async {
    _tasks.clear();
    _tasks.addAll(tasks);
  }
  @override
  Future<void> close() async {}
}

/// Hive非依存の SettingsRepository モック
class _MockSettingsRepo extends SettingsRepository {
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<bool> getGriffonEnabled() async => false;
  @override
  Future<void> setFontSizeScale(double v) async {}
  @override
  Future<void> setKnowledgeQuestEnabled(bool v) async {}
  @override
  Future<void> setTutorialStep(int v) async {}
  @override
  Future<void> setHasSeenConcept(bool v) async {}
  @override
  Future<void> setTutorialSkipped(bool v) async {}
  @override
  Future<void> setTutorialChoiceMade(bool v) async {}
  @override
  Future<void> setJobTutorialCompleted(bool v) async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<void> setGriffonEnabled(bool v) async {}
  @override
  Future<bool> getMorningNotificationEnabled() async => true;
  @override
  Future<void> setMorningNotificationEnabled(bool v) async {}
  @override
  Future<bool> getEveningNotificationEnabled() async => true;
  @override
  Future<void> setEveningNotificationEnabled(bool v) async {}
  @override
  Future<bool> getNoonNotificationEnabled() async => true;
  @override
  Future<void> setNoonNotificationEnabled(bool v) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override
  Future<void> deleteFatiguePopupDate() async {}
}

void main() {
  group('CreateTaskDialog — Bug M6: TextEditingController dispose leak', () {
    late GameViewModel gameVM;
    late TaskViewModel taskVM;
    late PlayerViewModel playerVM;

    setUp(() async {
      gameVM = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      playerVM = PlayerViewModel(_MockPlayerRepo());
      taskVM = TaskViewModel(
        _MockTaskRepo(),
        playerVM,
      );

      // GameViewModelの読み込みを待つ
      final start = DateTime.now();
      while (!gameVM.isLoaded) {
        if (DateTime.now().difference(start) > const Duration(seconds: 5)) {
          throw Exception('ViewModel load timeout');
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      await Future.delayed(const Duration(milliseconds: 50));
    });

    testWidgets('ダイアログを開いて閉じてもdisposeエラーが発生しない', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameViewModel>.value(value: gameVM),
            ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
            ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const CreateTaskDialog(),
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );

      // ダイアログを開く
      await tester.tap(find.text('開く'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(AppKeys.formTaskDialog), findsOneWidget);

      // キャンセルして閉じる
      await tester.tap(find.byKey(AppKeys.formTaskCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ダイアログが閉じられたことを確認（エラーなし）
      expect(find.byKey(AppKeys.formTaskDialog), findsNothing);
    });

    testWidgets('編集モードで開いて閉じてもdisposeエラーが発生しない', (tester) async {
      // 既存タスクを作成
      gameVM.addTask('テストタスク', rank: QuestRank.A);
      await tester.pump(const Duration(milliseconds: 100));
      final task = gameVM.tasks.first;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameViewModel>.value(value: gameVM),
            ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
            ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => CreateTaskDialog(task: task),
                ),
                child: const Text('編集'),
              ),
            ),
          ),
        ),
      );

      // ダイアログを開く
      await tester.tap(find.text('編集'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(AppKeys.formTaskDialog), findsOneWidget);

      // キャンセルして閉じる
      await tester.tap(find.byKey(AppKeys.formTaskCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ダイアログが閉じられたことを確認（エラーなし）
      expect(find.byKey(AppKeys.formTaskDialog), findsNothing);
    });
  });
}
