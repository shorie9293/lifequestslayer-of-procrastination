import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/widgets/debug_panel.dart';

// ━━━ モック（既存 test/game_view_model_test.dart と同じ方式）━━━

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override Future<Player?> loadPlayer() async => _player;
  @override Future<void> savePlayer(Player player) async => _player = player;
  @override Future<void> close() async {}
}

class _MockTaskRepo implements ITaskRepository {
  final List<Task> _tasks = [];
  @override Future<List<Task>> loadTasks() async => List.from(_tasks);
  @override Future<void> saveTasks(List<Task> tasks) async { _tasks.clear(); _tasks.addAll(tasks); }
  @override Future<void> close() async {}
}

class _MockSettingsRepo extends SettingsRepository {
  @override Future<int> getTutorialStep() async => 0;
  @override Future<bool> getHasSeenConcept() async => false;
  @override Future<double> getFontSizeScale() async => 0.85;
  @override Future<bool> getKnowledgeQuestEnabled() async => true;
  @override Future<bool> getTutorialSkipped() async => false;
  @override Future<bool> getTutorialChoiceMade() async => false;
  @override Future<bool> getJobTutorialCompleted() async => false;
  @override Future<bool> getDebugModeEnabled() async => false;
  @override Future<void> setFontSizeScale(double v) async {}
  @override Future<void> setKnowledgeQuestEnabled(bool v) async {}
  @override Future<void> setTutorialStep(int v) async {}
  @override Future<void> setHasSeenConcept(bool v) async {}
  @override Future<void> setTutorialSkipped(bool v) async {}
  @override Future<void> setTutorialChoiceMade(bool v) async {}
  @override Future<void> setJobTutorialCompleted(bool v) async {}
  @override Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override Future<void> deleteFatiguePopupDate() async {}
  @override Future<void> resetTutorial() async {}
  @override Future<DateTime?> getFatiguePopupDate() async => null;
  @override Future<void> setDebugModeEnabled(bool v) async {}
}

// ━━━ テスト ━━━

void main() {
  group('DebugPanel Widget', () {
    late SettingsViewModel vm;

    setUp(() async {
      vm = SettingsViewModel(_MockSettingsRepo());
      await vm.load();
      vm.tryEnableDebugMode('11111111');
    });

    Widget buildPanel() {
      final playerVM = PlayerViewModel(_MockPlayerRepo());
      final taskVM = TaskViewModel(_MockTaskRepo(), playerVM);
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerVM),
            ChangeNotifierProvider.value(value: taskVM),
          ],
          child: Scaffold(body: DebugPanel(settingsVM: vm)),
        ),
      );
    }

    testWidgets('デバッグパネルが表示される', (tester) async {
      await tester.pumpWidget(buildPanel());
      expect(find.text('デバッグパネル'), findsOneWidget);
    });

    testWidgets('コイン設定フィールドがある', (tester) async {
      await tester.pumpWidget(buildPanel());
      expect(find.text('💰 コイン'), findsOneWidget);
    });

    testWidgets('Gem設定フィールドがある', (tester) async {
      await tester.pumpWidget(buildPanel());
      expect(find.text('💎 Gem'), findsOneWidget);
    });

    testWidgets('EXP追加ボタンがある', (tester) async {
      await tester.pumpWidget(buildPanel());
      expect(find.text('+100'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('+1000'), findsOneWidget);
    });

    testWidgets('全タスク完了ボタンがある', (tester) async {
      await tester.pumpWidget(buildPanel());
      expect(find.text('全クエスト完了'), findsOneWidget);
    });

    testWidgets('テストタスク追加ボタンがある', (tester) async {
      await tester.pumpWidget(buildPanel());
      expect(find.text('テストクエスト追加'), findsOneWidget);
    });
  });

  group('GameViewModel debug methods', () {
    late GameViewModel vm;

    setUp(() async {
      vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      vm.tryEnableDebugMode('11111111');
    });

    test('debugSetCoins でコインを設定できる', () {
      vm.debugSetCoins(5000);
      expect(vm.player.coins, 5000);
    });

    test('debugSetCoins は負数を無視する', () {
      vm.debugSetCoins(-100);
      expect(vm.player.coins, 0);
    });

    test('debugSetGems でGemを設定できる', () {
      vm.debugSetGems(300);
      expect(vm.player.gems, 300);
    });

    test('debugAddExp でEXPが増える', () {
      final before = vm.player.currentExp;
      vm.debugAddExp(100);
      expect(vm.player.currentExp, greaterThan(before));
    });

    test('debugAddTestTasks でタスクが3件追加される', () {
      final before = vm.tasks.length;
      vm.debugAddTestTasks();
      expect(vm.tasks.length, before + 3);
    });

    test('debugCompleteAllActive でアクティブタスクが完了する', () {
      vm.debugAddTestTasks();
      for (final t in vm.tasks.toList()) {
        vm.acceptTask(t.id);
      }
      final activeBefore = vm.activeTasks.length;
      expect(activeBefore, greaterThan(0));

      vm.debugCompleteAllActive();
      expect(vm.activeTasks.length, 0);
    });

    test('デバッグモード無効時は debugSetCoins が無視される', () {
      final vm2 = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      vm2.debugSetCoins(9999);
      expect(vm2.player.coins, 0);
    });
  });
}
