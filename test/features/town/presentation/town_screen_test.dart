import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';

// ━━━ DI Mock リポジトリ ━━━

class _MockPlayerRepository implements IPlayerRepository {
  final Player _player;
  _MockPlayerRepository(this._player);

  @override
  Future<Player> loadPlayer() async => _player;
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

/// 指定された冒険者レベルのPlayerでViewModelを生成
Future<GameViewModel> _createViewModelWithLevel(int level) async {
  final player = Player(
    jobLevels: {Job.adventurer: level},
  );
  final vm = GameViewModel(
    pr: _MockPlayerRepository(player),
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
  await Future.delayed(const Duration(milliseconds: 50));
  return vm;
}

Future<void> pumpTownScreen(WidgetTester tester, GameViewModel vm) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<GameViewModel>.value(
      value: vm,
      child: const MaterialApp(
        home: TownScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('TownScreen 町発展表示', () {
    testWidgets('Lv.5 の冒険者は「荒野のキャンプ」と表示される', (tester) async {
      late GameViewModel vm;
      await tester.runAsync(() async {
        vm = await _createViewModelWithLevel(5);
      });
      await pumpTownScreen(tester, vm);

      expect(find.textContaining('荒野のキャンプ'), findsWidgets);
    });

    testWidgets('Lv.15 の冒険者は「小さな集落」と表示される', (tester) async {
      late GameViewModel vm;
      await tester.runAsync(() async {
        vm = await _createViewModelWithLevel(15);
      });
      await pumpTownScreen(tester, vm);

      expect(find.textContaining('小さな集落'), findsWidgets);
    });

    testWidgets('Lv.30 の冒険者は「活気ある町」と表示される', (tester) async {
      late GameViewModel vm;
      await tester.runAsync(() async {
        vm = await _createViewModelWithLevel(30);
      });
      await pumpTownScreen(tester, vm);

      expect(find.textContaining('活気ある町'), findsWidgets);
    });

    testWidgets('Lv.75 の冒険者は「王都」と表示される', (tester) async {
      late GameViewModel vm;
      await tester.runAsync(() async {
        vm = await _createViewModelWithLevel(75);
      });
      await pumpTownScreen(tester, vm);

      expect(find.textContaining('王都'), findsWidgets);
    });

    testWidgets('Lv.120 の冒険者は「天空の都」と表示される', (tester) async {
      late GameViewModel vm;
      await tester.runAsync(() async {
        vm = await _createViewModelWithLevel(120);
      });
      await pumpTownScreen(tester, vm);

      expect(find.textContaining('天空の都'), findsWidgets);
    });

    testWidgets('次の段階への必要レベルが表示される（最大段階以外）', (tester) async {
      late GameViewModel vm;
      await tester.runAsync(() async {
        vm = await _createViewModelWithLevel(5);
      });
      await pumpTownScreen(tester, vm);

      // 「次の発展まで Lv.11」のような表示がある
      expect(find.textContaining('Lv.11'), findsOneWidget);
    });

    testWidgets('天空の都では次の段階表示がない', (tester) async {
      late GameViewModel vm;
      await tester.runAsync(() async {
        vm = await _createViewModelWithLevel(150);
      });
      await pumpTownScreen(tester, vm);

      // 次の段階表示がないことを確認（「次の発展」のテキストがない）
      expect(find.textContaining('次の発展'), findsNothing);
    });
  });
}
