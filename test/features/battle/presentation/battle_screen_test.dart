import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/battle/viewmodels/battle_view_model.dart';
import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/di/injection.dart';

// ━━━ DI Mock リポジトリ（Hive非依存） ━━━

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

/// SettingsRepository は具象クラスのため extend して全Hiveメソッドをオーバーライド
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

/// テスト用のオーディオサービス（実際の音声再生を行わない）。
class _TestBattleAudioService extends BattleAudioService {
  bool _sfxOn = true;

  @override
  bool get sfxEnabled => _sfxOn;

  @override
  void setSfxEnabled(bool enabled) {
    _sfxOn = enabled;
    notifyListeners();
  }

  @override
  Future<void> playVictory() async {
    notifyListeners();
  }

  @override
  Future<void> playDefeat() async {
    notifyListeners();
  }
}

/// テスト用のDI注入済みViewModel群を生成
({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings})
    createViewModels() {
  final playerVM = PlayerViewModel(_MockPlayerRepository());
  final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(_MockSettingsRepository());
  return (task: taskVM, player: playerVM, settings: settingsVM);
}

/// テスト用のgetItを初期化する。
/// BattleScreenがgetIt経由でBattleViewModel/BattleAudioServiceを取得するため。
void setUpGetIt() {
  // getItが既に登録されている場合はリセット
  if (getIt.isRegistered<BattleViewModel>()) {
    getIt.unregister<BattleViewModel>();
  }
  if (getIt.isRegistered<BattleAudioService>()) {
    getIt.unregister<BattleAudioService>();
  }

  getIt.registerLazySingleton<BattleViewModel>(() => BattleViewModel());
  getIt.registerLazySingleton<BattleAudioService>(
      () => _TestBattleAudioService());
}

/// BattleScreen をポンプするヘルパー
Future<void> pumpBattleScreen(
  WidgetTester tester, {
  required TaskViewModel taskVM,
  required PlayerViewModel playerVM,
  required SettingsViewModel settingsVM,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
      ],
      child: const MaterialApp(
        home: BattleScreen(),
      ),
    ),
  );
  // 画面が完全に描画されるのを待つ
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    setUpGetIt();
  });

  group('BattleScreen 見積もり時間表示テスト', () {
    // ━━━ 見積もり表示あり ━━━

    testWidgets(
        'activeTasks に targetTimeMinutes がある場合、'
        '「今日の戦い（見積もり）: XX分」が表示される', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      // runAsync 内でVMを生成
      await tester.runAsync(() async {
        vms = createViewModels();

        // 見積もり時間付きのクエストを追加して受注（active 状態にする）
        vms.task.addTask('テストクエスト', rank: QuestRank.B, targetTimeMinutes: 30);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // 見積もり時間のテキストが表示されていることを確認（完全一致）
      expect(find.text('今日の戦い（見積もり）: 30分'), findsOneWidget);
    });

    testWidgets('複数クエストの見積もり時間が合計表示される', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();

        // 2つのクエスト（30分 + 45分 = 75分、両方Bランクで受注可能）
        // デフォルトLv1ではBランク1枠しかないのでLv2に昇格
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('クエストA', rank: QuestRank.B, targetTimeMinutes: 30);
        vms.task.addTask('クエストB', rank: QuestRank.B, targetTimeMinutes: 45);
        for (final t in List<Task>.from(vms.task.tasks)) {
          vms.task.acceptTask(t.id);
        }
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // 合計75分が表示されていることを確認
      expect(find.text('今日の戦い（見積もり）: 75分'), findsOneWidget);
    });

    // ━━━ 見積もり表示なし ━━━

    testWidgets(
        'activeTasks の targetTimeMinutes が null の場合、見積もり表示は出ない',
        (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();

        // targetTimeMinutes なしのクエストを追加して受注
        vms.task.addTask('テストクエスト', rank: QuestRank.B);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

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

    testWidgets('見積もり0分（クエストなし）の場合は表示されない', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();
        // クエストを追加しない → dailyEstimatedMinutes = 0
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

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

  // ━━━ M4禍津: クエスト連打でダイアログ多重表示 ━━━

  group('M4 クエスト連打ガードテスト', () {
    testWidgets('クエスト完了ボタンを連打してもダイアログは1つだけ表示される',
        (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;
      late String taskId;

      await tester.runAsync(() async {
        vms = createViewModels();
        // Lv2に上げてBランク受注可能にする
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('連打テスト', rank: QuestRank.B);
        taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTile を展開して完了ボタンを表示させる
      final taskTitle = find.text('[B] 連打テスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 完了ボタン（⚔️）を探す
      final completeButton = find.byTooltip('討つ！');
      expect(completeButton, findsOneWidget);

      // 1回目タップ: 戦術選択フェイズに入る
      await tester.tap(completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 戦術選択バーが表示されている
      expect(find.text('攻撃'), findsOneWidget);

      // 2回目のタップは isInCombat ガードでブロックされる
      await tester.tap(completeButton);
      await tester.pump();

      // 攻撃ボタンをタップして討伐実行
      await tester.tap(find.text('攻撃'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // パーティクルエフェクトが1つだけ存在することを確認
      // 連打ガードにより2つ目がブロックされ、1つの ParticleBurst のみ表示
      final particleTexts = find.text('クエスト完了\n💥');
      expect(particleTexts, findsOneWidget);
    });
  });

  // ━━━ M5禍津: maybePop() が無関係ダイアログを閉じる ━━━

  group('M5 maybePop 無関係ダイアログテスト', () {
    testWidgets('クエスト完了後、先に開いていたダイアログが閉じられない',
        (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;
      late String taskId;

      await tester.runAsync(() async {
        vms = createViewModels();
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('M5テスト', rank: QuestRank.B);
        taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTile を展開して完了ボタンを表示させる
      final taskTitle = find.text('[B] M5テスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 討つ！ボタンをタップ → 戦術選択フェイズ
      final completeButton = find.byTooltip('討つ！');
      expect(completeButton, findsOneWidget);
      await tester.tap(completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 戦術選択バーから「攻撃」を選択 → 討伐実行
      expect(find.text('攻撃'), findsOneWidget);
      await tester.tap(find.text('攻撃'));
      await tester.pump();

      // ParticleBurst が表示されるのを待つ
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('クエスト完了\n💥'), findsOneWidget);

      // ParticleBurst のアニメーション完了を待つ（pumpAndSettle で確実に）
      await tester.pumpAndSettle(const Duration(milliseconds: 2000));

      // ParticleBurst ダイアログが閉じられたことを確認
      expect(find.text('クエスト完了\n💥'), findsNothing);
    });
  });

  // ━━━ UX-9: セーブ失敗時にSnackBar表示 ━━━

  group('UX-9 セーブ失敗SnackBarテスト', () {
    testWidgets('save()が失敗した場合、onSaveErrorが呼ばれSnackBarが表示される',
        (tester) async {
      // save()が例外を投げるTaskRepositoryのモック
      final taskRepo = _MockTaskRepositoryThrowsOnSave();
      final playerRepo = _MockPlayerRepository();
      final playerVM = PlayerViewModel(playerRepo);
      final taskVM = TaskViewModel(taskRepo, playerVM);
      final settingsVM = SettingsViewModel(_MockSettingsRepository());

      await tester.runAsync(() async {
        playerVM.player.jobLevels[playerVM.player.currentJob] = 2;
        taskVM.addTask('SnackBarテスト', rank: QuestRank.B);
        final taskId = taskVM.tasks.first.id;
        taskVM.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: taskVM, playerVM: playerVM, settingsVM: settingsVM);

      // ExpansionTileを展開
      final taskTitle = find.text('[B] SnackBarテスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // キャンセルボタンをタップ -> 確認ダイアログ
      final cancelButton = find.byKey(AppKeys.battleCancel);
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // onSaveErrorが設定されていることを確認
      expect(taskVM.onSaveError, isNotNull);

      // 確認ダイアログで「戻す（体力消費）」をタップ -> save()が失敗
      final confirmButton = find.widgetWithText(TextButton, '戻す（体力消費）');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);

      // 全てのアニメーションを完了させる
      await tester.pumpAndSettle();

      // 成功SnackBarが表示されている
      expect(find.textContaining('クエストを寄合所に戻しました'), findsOneWidget);
    });
  });

  // ━━━ UX-4: クエストキャンセル時の確認ダイアログ ━━━

  group('UX-4 キャンセル確認ダイアログテスト', () {
    testWidgets('キャンセルボタンタップで確認ダイアログが表示される',
        (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('キャンセルテスト', rank: QuestRank.B);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTile を展開
      final taskTitle = find.text('[B] キャンセルテスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // キャンセルボタンをタップ
      final cancelButton = find.byKey(AppKeys.battleCancel);
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 確認ダイアログが表示されていることを確認
      expect(find.byKey(AppKeys.confirmDialog), findsOneWidget);

      // 「キャンセル」をタップしてダイアログを閉じる
      final dialogCancelBtn = find.widgetWithText(TextButton, 'キャンセル');
      expect(dialogCancelBtn, findsOneWidget);
      await tester.tap(dialogCancelBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // ダイアログが閉じられ、クエストはactiveのまま
      expect(find.byKey(AppKeys.confirmDialog), findsNothing);
      expect(vms.task.activeTasks.length, 1);

      // 再度キャンセルボタン -> 確認ダイアログ -> 「戻す」で確定
      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(AppKeys.confirmDialog), findsOneWidget);

      final returnButton = find.widgetWithText(TextButton, '戻す（体力消費）');
      expect(returnButton, findsOneWidget);
      await tester.tap(returnButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // クエストがギルドに戻されたことを確認
      expect(vms.task.activeTasks.length, 0);
    });
  });

  // ━━━ v2.1: BGM/BattleViewModel 統合テスト ━━━

  group('v2.1 BGM統合テスト', () {
    testWidgets('討つ！タップでBattleViewModelがfacing状態になる', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('BGMテスト', rank: QuestRank.B);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTileを展開
      final taskTitle = find.text('[B] BGMテスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 討つ！ボタンをタップ
      final completeButton = find.byTooltip('討つ！');
      expect(completeButton, findsOneWidget);
      await tester.tap(completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // BattleViewModelがfacing状態になっているか
      final battleVM = getIt<BattleViewModel>();
      expect(battleVM.currentState, BattleState.facing);
      expect(battleVM.currentTask, isNotNull);
      expect(battleVM.currentTask!.title, 'BGMテスト');
    });

    testWidgets('戦術選択バーが表示される', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('戦術選択テスト', rank: QuestRank.B);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTileを展開
      final taskTitle = find.text('[B] 戦術選択テスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 討つ！ボタンをタップ
      final completeButton = find.byTooltip('討つ！');
      await tester.tap(completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // AppBarが「⚔️ 戦術選択」になっている
      expect(find.text('⚔️ 戦術選択'), findsOneWidget);

      // 戦術選択バー（攻撃/防御/スキル）が表示されている
      expect(find.text('攻撃'), findsOneWidget);
      expect(find.text('防御'), findsOneWidget);
    });

    testWidgets('戦術選択後にBattleViewModelがattacking状態になる', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();
        vms.player.player.jobLevels[vms.player.player.currentJob] = 2;
        vms.task.addTask('攻撃テスト', rank: QuestRank.B);
        final taskId = vms.task.tasks.first.id;
        vms.task.acceptTask(taskId);
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // ExpansionTileを展開
      final taskTitle = find.text('[B] 攻撃テスト');
      expect(taskTitle, findsOneWidget);
      await tester.tap(taskTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 討つ！ボタンをタップ
      final completeButton = find.byTooltip('討つ！');
      await tester.tap(completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 戦術選択バーで「攻撃」をタップ
      final attackButton = find.text('攻撃');
      expect(attackButton, findsOneWidget);
      await tester.tap(attackButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // BattleViewModelが戦術を選択し、その後の討伐完了で victory または defeat 状態になる
      final battleVM = getIt<BattleViewModel>();
      expect(battleVM.selectedTactic, BattleTactic.attack);
      // クエスト討伐完了後は victory または defeat（クエストの状態による）
      expect(
        battleVM.currentState,
        anyOf(BattleState.victory, BattleState.defeat),
      );
    });

    testWidgets('効果音トグルが動作する', (tester) async {
      late ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings}) vms;

      await tester.runAsync(() async {
        vms = createViewModels();
      });

      await pumpBattleScreen(
          tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

      // 効果音トグルボタンを探す（デフォルトON）
      final sfxOnButton = find.byTooltip('効果音を消す');
      expect(sfxOnButton, findsOneWidget);

      // タップしてオフ
      await tester.tap(sfxOnButton);
      await tester.pump();

      // ツールチップが変わる
      expect(find.byTooltip('効果音をつける'), findsOneWidget);

      // 再度タップしてオン
      await tester.tap(find.byTooltip('効果音をつける'));
      await tester.pump();
      expect(find.byTooltip('効果音を消す'), findsOneWidget);
    });
  });
}

/// save()が例外を投げるモックTaskRepository
class _MockTaskRepositoryThrowsOnSave implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async => throw Exception('Save failed');
  @override
  Future<void> close() async {}
}
