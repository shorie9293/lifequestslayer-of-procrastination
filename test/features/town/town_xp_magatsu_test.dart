// 町XPの2つの禍津に対する試練（TDD RED→GREEN）
// 禍津1: ヘルプの町XP数値が実装（S:50/A:30/B:10）と不一致
// 禍津2: クエスト討伐時に町XPが戦果報告書に表示されない
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/battle_report_dialog.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

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
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<bool> getSfxEnabled() async => true;
  @override
  Future<double> getSfxVolume() async => 0.7;
  @override
  Future<void> setSfxVolume(double volume) async {}
  @override
  Future<void> setSfxEnabled(bool enabled) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => true;
  @override
  Future<void> setBattleSceneEnabled(bool enabled) async {}
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}
}

Future<void> _waitForLoad(GameViewModel vm) async {
  for (var i = 0; i < 50; i++) {
    await Future.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Hive.init('test/hive_testing_path');
  });

  tearDown(() async {
    await Hive.close();
  });

  group('禍津1: ヘルプの町XP数値', () {
    testWidgets('町画面ヘルプは実装と一致する町XP配分（S:50 / A:30 / B:10）を表示する',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HelpDialog(screen: HelpScreen.town)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('S:50 / A:30 / B:10'), findsOneWidget);
      // 旧数値（B:20 / C / D）は出現してはならない
      expect(find.textContaining('B:20'), findsNothing);
      expect(find.textContaining('C:10'), findsNothing);
      expect(find.textContaining('D:5'), findsNothing);
    });
  });

  group('禍津2: completeTask の戻り値に町XPを含める', () {
    test('completeTask() 戻り値は townXp キー（Bランク=10）を含む', () async {
      final townVM = TownViewModel();
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
        tv: townVM,
      );
      await _waitForLoad(vm);

      vm.addTask('クエストB', rank: QuestRank.B);
      vm.tasks.last.enemyXpMultiplier = 1.0;
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['townXp'], 10);
    });

    test('completeTask() 戻り値は townXp キー（Sランク=50）を含む', () async {
      final townVM = TownViewModel();
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
        tv: townVM,
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[vm.player.currentJob] = 10;
      vm.addTask('クエストS', rank: QuestRank.S);
      vm.tasks.last.enemyXpMultiplier = 1.0;
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['townXp'], 50);
    });
  });

  group('禍津2: 戦果報告書に町XPを表示', () {
    Future<void> pumpDialog(WidgetTester tester, {int? townXp}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => BattleReportDialog.show(
                context,
                coinsGained: 100,
                townXp: townXp,
              ),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Dialog'));
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('townXp がある場合は「町XP +N」行を表示する', (tester) async {
      await pumpDialog(tester, townXp: 30);
      expect(find.text('町XP'), findsOneWidget);
      expect(find.text('+30'), findsOneWidget);
    });

    testWidgets('townXp が null の場合は町XP行を非表示にする', (tester) async {
      await pumpDialog(tester);
      expect(find.text('町XP'), findsNothing);
    });

    testWidgets('townXp が 0 の場合は町XP行を非表示にする', (tester) async {
      await pumpDialog(tester, townXp: 0);
      expect(find.text('町XP'), findsNothing);
    });
  });
}
