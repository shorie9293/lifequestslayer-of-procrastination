import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/di/injection.dart';

import 'presentation/battle_screen_test.dart' as battle_screen_test;

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
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

class _MockSettingsRepository extends SettingsRepository {
  @override
  Future<double> getFontSizeScale() async => 1.0;
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
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}
}

class _TestBattleAudioService extends BattleAudioService {
  @override
  bool get sfxEnabled => true;
  @override
  void setSfxEnabled(bool enabled) {}
  @override
  Future<void> playVictory() async {}
  @override
  Future<void> playDefeat() async {}
}

void main() {
  setUp(() {
    battle_screen_test.setUpGetIt();
    // オーディオは無音モックに差し替える
    if (getIt.isRegistered<BattleAudioService>()) {
      getIt.unregister<BattleAudioService>();
    }
    getIt.registerLazySingleton<BattleAudioService>(
        () => _TestBattleAudioService());
  });

  testWidgets('討伐成功で戦績が1件だけ記録される', (tester) async {
    final repo = InMemoryBattleRecordRepository();
    final playerVM = PlayerViewModel(_MockPlayerRepository());
    final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);
    final settingsVM = SettingsViewModel(_MockSettingsRepository());

    await tester.runAsync(() async {
      playerVM.player.jobLevels[playerVM.player.currentJob] = 2;
      taskVM.addTask('戦績記録テスト', rank: QuestRank.B);
      taskVM.acceptTask(taskVM.tasks.first.id);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ChangeNotifierProvider<GameViewModel>.value(
            value: GameViewModel(
              playerVM: playerVM,
              taskVM: taskVM,
              settingsVM: settingsVM,
              autoLoad: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: BattleScreen(battleRecordRepository: repo),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // AppBar 導線ボタンが存在する
    expect(find.byKey(AppKeys.battleRecordEntry), findsOneWidget);

    // 討伐実行: ExpansionTile展開 → 討つ！ → 攻撃
    await tester.tap(find.text('[B] 戦績記録テスト'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('討つ！'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('攻撃'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 2000));

    // 戦績が1件だけ記録されている（二重記録なし）
    final records = await repo.load();
    expect(records.length, 1);
    expect(records.first.isVictory, true);
    expect(records.first.title, '戦績記録テスト');
  });

  testWidgets('討伐戦績導線ボタンで戦績画面が開く', (tester) async {
    final repo = InMemoryBattleRecordRepository();
    final playerVM = PlayerViewModel(_MockPlayerRepository());
    final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);
    final settingsVM = SettingsViewModel(_MockSettingsRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ChangeNotifierProvider<GameViewModel>.value(
            value: GameViewModel(
              playerVM: playerVM,
              taskVM: taskVM,
              settingsVM: settingsVM,
              autoLoad: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: BattleScreen(battleRecordRepository: repo),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.battleRecordEntry));
    await tester.pumpAndSettle();

    // 戦績画面（空状態）が表示されている
    expect(find.byKey(AppKeys.battleRecordScreen), findsOneWidget);
    expect(find.byKey(AppKeys.battleRecordEmpty), findsOneWidget);
  });

  testWidgets('サブタスク残存の討伐失敗で敗北が1件記録される', (tester) async {
    // 討伐失敗: 分割の理（mysticSubtask）装備でサブクエスト未完了のまま討つ
    // → declareDefeat 経路。completeTask はサブタスク未完了なら null を返す。
    final repo = InMemoryBattleRecordRepository();
    final playerVM = PlayerViewModel(_MockPlayerRepository());
    final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);
    final settingsVM = SettingsViewModel(_MockSettingsRepository());

    late String taskId;
    await tester.runAsync(() async {
      // 分割の理（mysticSubtask）を装備: サブクエスト未完了なら討伐失敗（completeTaskがnull）になる。
      // Player はイミュータブル化済みのため、copyWith（現在職の変更）＋VMのAPI（equipSkill）で
      // 状態を作らねば isSkillEquipped が真にならない。
      playerVM.player =
          playerVM.player.copyWith(currentJob: Job.mystic);
      playerVM.equipSkill(JobSkill.mysticSubtask, debugMode: true);
      expect(playerVM.player.equippedSkills.any((es) => es.skill == JobSkill.mysticSubtask),
          isTrue);
      expect(playerVM.player.isSkillEquipped(JobSkill.mysticSubtask), isTrue);

      taskVM.addTask('敗北記録テスト', rank: QuestRank.B);
      taskId = taskVM.tasks.first.id;
      taskVM.acceptTask(taskId);
      // 未完了サブクエストを1件追加（VMに追加APIがないため直接モデル操作）
      final target = taskVM.activeTasks.firstWhere((t) => t.id == taskId);
      target.subTasks.add(SubTask(title: '未完了サブ'));
      expect(target.subTasks.where((s) => !s.isCompleted).length, 1);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ChangeNotifierProvider<GameViewModel>.value(
            value: GameViewModel(
              playerVM: playerVM,
              taskVM: taskVM,
              settingsVM: settingsVM,
              autoLoad: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: BattleScreen(battleRecordRepository: repo),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('[B] 敗北記録テスト'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('討つ！'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('攻撃'));
    await tester.pump();
    await tester.pumpAndSettle();

    final records = await repo.load();
    expect(records.length, 1);
    expect(records.first.isVictory, false);
    expect(records.first.remainingSubTasks, 1);
  });
}

/// BattleRecord を復元して検証するための再エクスポート（未使用警告対策）。
// ignore: unused_element
typedef _BattleRecordRef = BattleRecord;
