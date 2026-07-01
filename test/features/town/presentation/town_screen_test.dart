import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';

// ━━━ DI Mock リポジトリ ━━━

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  final Player _player;
  _MockPlayerRepository(this._player);

  @override
  Future<Player?> loadPlayer() async => _player;
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
  @override
  Future<bool> getSfxEnabled() async => true;
  @override
  Future<void> setSfxEnabled(bool enabled) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => true;
  @override
  Future<void> setBattleSceneEnabled(bool enabled) async {}
}

/// 指定された冒険者レベルのPlayerでViewModelを生成
Future<GameViewModel> _createViewModelWithLevel(int level, TownViewModel townVM) async {
  final player = Player(
    jobLevels: {Job.adventurer: level},
  );
  final vm = GameViewModel(
    pr: _MockPlayerRepository(player),
    tr: _MockTaskRepository(),
    sr: _MockSettingsRepository(),
    tv: townVM,
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

Future<void> pumpTownScreen(WidgetTester tester, GameViewModel vm, PlayerViewModel playerVM, TownViewModel townVM) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameViewModel>.value(value: vm),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<ShopViewModel>(create: (_) => ShopViewModel(playerVM)),
        ChangeNotifierProvider<TownViewModel>.value(value: townVM),
      ],
      child: const MaterialApp(
        home: TownScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TownScreen 町発展表示', () {
    Future<(PlayerViewModel, TownViewModel)> createViewModels(int townLevel) async {
      final playerVM = PlayerViewModel(_MockPlayerRepository(Player(jobLevels: {Job.adventurer: 5})));
      await playerVM.load();
      final townVM = TownViewModel();
      townVM.initialize();
      townVM.setTownLevelForTest(townLevel);
      return (playerVM, townVM);
    }

    testWidgets('町Lv.1 では「荒野のキャンプ」と表示される', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(1);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      expect(find.textContaining('荒野のキャンプ'), findsWidgets);
    });

    testWidgets('町Lv.11 では「小さな集落」と表示される', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(11);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      expect(find.textContaining('小さな集落'), findsWidgets);
    });

    testWidgets('町Lv.26 では「活気ある町」と表示される', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(26);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      expect(find.textContaining('活気ある町'), findsWidgets);
    });

    testWidgets('町Lv.51 では「王都」と表示される', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(51);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      expect(find.textContaining('王都'), findsWidgets);
    });

    testWidgets('町Lv.101 では「天空の都」と表示される', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(101);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      expect(find.textContaining('天空の都'), findsWidgets);
    });

    testWidgets('次の段階への必要レベルが表示される（最大段階以外）', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(5);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      // 「次の発展まで Lv.11」のような表示がある
      expect(find.textContaining('Lv.11'), findsOneWidget);
    });

    testWidgets('天空の都では次の段階表示がない', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(150);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      // 次の段階表示がないことを確認（「次の発展」のテキストがない）
      expect(find.textContaining('次の発展'), findsNothing);
    });
  });

  group('TownScreen 町XP説明表示', () {
    Future<(PlayerViewModel, TownViewModel)> createViewModels(int townLevel) async {
      final playerVM = PlayerViewModel(_MockPlayerRepository(Player(jobLevels: {Job.adventurer: 5})));
      await playerVM.load();
      final townVM = TownViewModel();
      townVM.initialize();
      townVM.setTownLevelForTest(townLevel);
      return (playerVM, townVM);
    }

    testWidgets('町XPの獲得方法が説明テキストで表示される', (tester) async {
      late GameViewModel vm;
      late PlayerViewModel playerVM;
      late TownViewModel townVM;
      await tester.runAsync(() async {
        final vms = await createViewModels(5);
        playerVM = vms.$1;
        townVM = vms.$2;
        vm = await _createViewModelWithLevel(5, townVM);
      });
      await pumpTownScreen(tester, vm, playerVM, townVM);

      // 町レベルバーの下に「クエスト討伐で町XPを獲得」の説明があることを確認
      expect(find.textContaining('クエスト討伐'), findsOneWidget);
      expect(find.textContaining('町XP'), findsOneWidget);
    });
  });
}
