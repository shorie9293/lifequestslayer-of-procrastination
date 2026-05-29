import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/bulk_create_task_dialog.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
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
  Future<void> setFontSizeScale(double v) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
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
  Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
}

/// テスト用 TaskViewModel モック — GameViewModel に委譲する
class _MockTaskViewModel extends TaskViewModel {
  final GameViewModel _gameVM;

  _MockTaskViewModel(this._gameVM, super.taskRepository, super.playerVM);

  @override
  void addTasks(List<String> titles, QuestRank rank) {
    _gameVM.addTasks(titles, rank);
  }

  @override
  Future<void> save() async {}
}

/// テスト用 SettingsViewModel モック
class _MockSettingsViewModel extends SettingsViewModel {
  _MockSettingsViewModel(super.settingsRepository);

  @override
  Future<void> completeTutorialStep(int step) async {}
}

class _DialogLauncher extends StatelessWidget {
  const _DialogLauncher();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const BulkCreateTaskDialog(),
          ),
          child: const Text('開く'),
        ),
      ),
    );
  }
}

void main() {
  group('BulkCreateTaskDialog', () {
    late GameViewModel vm;
    late _MockTaskViewModel taskVM;
    late _MockSettingsViewModel settingsVM;

    setUp(() async {
      vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      taskVM = _MockTaskViewModel(vm, _MockTaskRepo(), PlayerViewModel(_MockPlayerRepo()));
      settingsVM = _MockSettingsViewModel(_MockSettingsRepo());
      final start = DateTime.now();
      while (!vm.isLoaded) {
        if (DateTime.now().difference(start) > const Duration(seconds: 5)) {
          throw Exception('ViewModel load timeout');
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      await Future.delayed(const Duration(milliseconds: 50));
    });

    testWidgets('ダイアログが正しい要素で表示される', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameViewModel>.value(value: vm),
            ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const BulkCreateTaskDialog(),
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('開く'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(AppKeys.bulkCreateTaskDialog), findsOneWidget);
      expect(find.text('一括依頼作成'), findsOneWidget);
      expect(find.byKey(AppKeys.bulkCreateTaskInput), findsOneWidget);
      expect(find.byKey(AppKeys.bulkCreateTaskRank), findsOneWidget);
      expect(find.byKey(AppKeys.bulkCreateTaskSubmit), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('空テキストで一括登録ボタンを押すとエラー', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameViewModel>.value(value: vm),
            ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ],
          child: const MaterialApp(home: _DialogLauncher()),
        ),
      );

      await tester.tap(find.text('開く'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(AppKeys.bulkCreateTaskSubmit));
      await tester.pump();

      expect(find.text('依頼内容を入力してください'), findsOneWidget);
      expect(vm.tasks, isEmpty);
    });

    testWidgets('複数行の入力を一括登録できる', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameViewModel>.value(value: vm),
            ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ],
          child: const MaterialApp(home: _DialogLauncher()),
        ),
      );

      await tester.tap(find.text('開く'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final inputField = tester.widget<TextField>(
        find.byKey(AppKeys.bulkCreateTaskInput),
      );
      inputField.controller!.text = 'クエストA\nクエストB\nクエストC';
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.bulkCreateTaskSubmit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(vm.tasks.length, 3);
      expect(vm.tasks[0].title, 'クエストA');
      expect(vm.tasks[1].title, 'クエストB');
      expect(vm.tasks[2].title, 'クエストC');
      expect(vm.tasks.every((t) => t.rank == QuestRank.B), true);
    });

    testWidgets('空行は無視されて有効な行のみ登録される', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameViewModel>.value(value: vm),
            ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ],
          child: const MaterialApp(home: _DialogLauncher()),
        ),
      );

      await tester.tap(find.text('開く'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final inputField = tester.widget<TextField>(
        find.byKey(AppKeys.bulkCreateTaskInput),
      );
      inputField.controller!.text = 'タスク1\n\nタスク2\n   \nタスク3';
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.bulkCreateTaskSubmit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(vm.tasks.length, 3);
    });
  });
}
