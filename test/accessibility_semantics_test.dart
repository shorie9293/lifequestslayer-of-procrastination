// UX-1 アクセシビリティ基盤 — 全操作可能要素への Semantics 付与の試練
//
// コード適応神書 原則③（Semantics体系）に基づき、操作可能要素（ボタン・
// 入力欄・タップ領域）がスクリーンリーダー／ADB uiautomator から特定できる
// ことを検証する。find.bySemanticsIdentifier は ADB の content-desc に、
// find.bySemanticsLabel は TalkBack 等の読み上げラベルに対応する。
//
// 制定: 令和八年水無月（UX-1 アクセシビリティ基盤）

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/crossapp/presentation/cross_app_reward_dialog.dart';
import 'package:rpg_todo/features/crossapp/presentation/tsundoku_identity_link_dialog.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/overview/presentation/screens/overview_screen.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';

// ━━━ DI Mock リポジトリ ━━━

class _MockPlayerRepository implements IPlayerRepository {
  final Player _player;
  _MockPlayerRepository(this._player);

  @override
  bool get loadFailedDueToCorruption => false;

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

void main() {
  late Directory tempDir;

  setUpAll(() async {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_semantics_');
    Hive.init(tempDir.path);
    // ReflectionGroveScreen の _load() が即座に完了するよう box を事前オープン
    try {
      await Hive.openBox<Reflection>('reflections');
    } catch (_) {}
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('CrossAppRewardDialog アクセシビリティ', () {
    testWidgets('「受け取る」ボタンに identifier とラベルが付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CrossAppRewardDialog(
              totalCoins: 10,
              totalExp: 20,
              newTitles: ['読書の賢者'],
            ),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('btn_accept_reward'), findsOneWidget);
      expect(find.bySemanticsLabel('報酬を受け取る'), findsOneWidget);
      handle.dispose();
    });
  });

  group('TsundokuIdentityLinkDialog アクセシビリティ', () {
    testWidgets('入力欄と操作ボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TsundokuIdentityLinkDialog()),
        ),
      );

      expect(
          find.bySemanticsIdentifier('txt_tsundoku_user_id'), findsOneWidget);
      expect(find.bySemanticsIdentifier('btn_cancel_link'), findsOneWidget);
      expect(find.bySemanticsIdentifier('btn_link'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('連携済みの場合は「連携解除」ボタンにも identifier が付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TsundokuIdentityLinkDialog(currentUserId: 'a1b2c3d4'),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('btn_unlink'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ReflectionGroveScreen アクセシビリティ', () {
    testWidgets('戻るボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: ReflectionGroveScreen(onBack: _noop),
        ),
      );
      // _load() の Hive box 読込 → setState を実時間で完了させる
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('btn_back'), findsOneWidget);
      expect(find.bySemanticsLabel('戻る'), findsOneWidget);
      handle.dispose();
    });
  });

  group('OverviewScreen アクセシビリティ', () {
    testWidgets('ヘルプボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      // mysticOverview（俯瞰の魔眼）を解放した陰陽師 Lv15 を用意
      final player = Player(currentJob: Job.mystic, jobLevels: {Job.mystic: 15});
      final playerVM = PlayerViewModel(_MockPlayerRepository(player));
      await tester.runAsync(() async {
        await playerVM.load();
      });
      final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
            ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
          ],
          child: const MaterialApp(home: OverviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('btn_help'), findsOneWidget);
      expect(find.bySemanticsLabel('神託補佐（ヘルプ）'), findsOneWidget);
      handle.dispose();
    });
  });

  group('TownScreen アクセシビリティ', () {
    testWidgets('ヘルプボタンと施設強化ボタンに identifier が付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      final playerVM =
          PlayerViewModel(_MockPlayerRepository(Player(jobLevels: {Job.adventurer: 5})));
      await tester.runAsync(() async {
        await playerVM.load();
      });
      final townVM = TownViewModel();
      townVM.initialize();
      townVM.setTownLevelForTest(1);

      final vm = GameViewModel(
        pr: _MockPlayerRepository(Player(jobLevels: {Job.adventurer: 5})),
        tr: _MockTaskRepository(),
        sr: _MockSettingsRepository(),
        tv: townVM,
      );
      await tester.runAsync(() async {
        final start = DateTime.now();
        while (!vm.isLoaded) {
          if (DateTime.now().difference(start) > const Duration(seconds: 5)) {
            throw Exception('GameViewModel のロードがタイムアウトしました');
          }
          await Future.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameViewModel>.value(value: vm),
            ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
            ChangeNotifierProvider<ShopViewModel>(
                create: (_) => ShopViewModel(playerVM)),
            ChangeNotifierProvider<TownViewModel>.value(value: townVM),
          ],
          child: const MaterialApp(home: TownScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsIdentifier('btn_help'), findsOneWidget);
      // 町Lv.1 では宿屋が解放済みかつ強化可能（Lv1<5）なので強化ボタンが出る
      expect(find.bySemanticsIdentifier('btn_upgrade_inn'), findsOneWidget);
      handle.dispose();
    });
  });
}

void _noop() {}
