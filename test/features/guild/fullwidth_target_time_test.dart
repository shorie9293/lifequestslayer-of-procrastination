// 回帰試練: 数値入力欄に全角数字・全角カンマを入れても黙って未設定/0にしない。
//
// 改善提案#215。入力欄（利用者が直接タイプする箇所）は JapaneseNumber を通す。
// 対象: クエスト作成ダイアログ / 定型（テンプレート）ダイアログ / 計画の陣（プロジェクト）。
//
// 時刻依存の検証は置かない（TZ=UTC と JST の双方で緑にするため）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/data/task_template_repository.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/create_task_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/task_template_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/project/presentation/project_keys.dart';
import 'package:rpg_todo/features/project/presentation/project_list_screen.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
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

/// クエスト作成ダイアログを開き、タイトルと見積もり時間を入れて保存する。
Future<void> _createTaskWith(
  WidgetTester tester,
  GameViewModel gameVM,
  String targetTimeText,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final playerVM = PlayerViewModel(_MockPlayerRepo());
  final taskVM = TaskViewModel(_MockTaskRepo(), playerVM);

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

  await tester.tap(find.text('開く'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(AppKeys.formTaskTitle), '全角テスト');
  await tester.enterText(
      find.byKey(AppKeys.formTaskTargetTime), targetTimeText);
  await tester.tap(find.byKey(AppKeys.formTaskSubmit));
  await tester.pumpAndSettle();
}

GameViewModel _newGameVM() => GameViewModel(
      pr: _MockPlayerRepo(),
      tr: _MockTaskRepo(),
      sr: _MockSettingsRepo(),
    );

/// 定型ダイアログ内の「見積もり時間（分・任意）」TextField を探す。
Finder _templateTargetTimeField() {
  final matches = find
      .byType(TextField)
      .evaluate()
      .where((e) =>
          (e.widget as TextField).decoration?.labelText == '見積もり時間（分・任意）')
      .map((e) => find.byWidget(e.widget))
      .toList();
  expect(matches, hasLength(1), reason: '見積もり時間欄は1つだけ存在する');
  return matches.single;
}

void main() {
  group('CreateTaskDialog — 全角数値入力', () {
    testWidgets('全角３０を目標時間に入れると30分で保存される', (tester) async {
      final gameVM = _newGameVM();
      await _createTaskWith(tester, gameVM, '３０');

      final task = gameVM.tasks.single;
      expect(task.title, '全角テスト');
      expect(task.targetTimeMinutes, 30);
    });

    testWidgets('全角カンマ １，０００ は 1000 分として保存される', (tester) async {
      final gameVM = _newGameVM();
      await _createTaskWith(tester, gameVM, '１，０００');

      expect(gameVM.tasks.single.targetTimeMinutes, 1000);
    });

    testWidgets('単位付き「３０分」は数値と誤認せず未設定のまま保存する', (tester) async {
      final gameVM = _newGameVM();
      await _createTaskWith(tester, gameVM, '３０分');

      expect(gameVM.tasks.single.targetTimeMinutes, isNull);
    });
  });

  group('TaskTemplateScreen — 定型ダイアログの全角数値入力', () {
    testWidgets('全角３０を入れた定型が30分として保存される', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = InMemoryTaskTemplateRepository();
      await tester.pumpWidget(MaterialApp(
        home: TaskTemplateScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.taskTemplateCreateButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AppKeys.taskTemplateNameField), '全角');
      await tester.enterText(
          find.byKey(AppKeys.taskTemplateTitleField), '全角クエスト');
      await tester.enterText(_templateTargetTimeField(), '３０');
      await tester.tap(find.byKey(AppKeys.taskTemplateSaveButton));
      await tester.pumpAndSettle();

      final saved = await repo.load();
      expect(saved.single.targetTimeMinutes, 30);
    });

    testWidgets('全角カンマ １，０００ を入れた定型が1000分として保存される', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = InMemoryTaskTemplateRepository();
      await tester.pumpWidget(MaterialApp(
        home: TaskTemplateScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.taskTemplateCreateButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(AppKeys.taskTemplateNameField), '全角カンマ');
      await tester.enterText(find.byKey(AppKeys.taskTemplateTitleField), '長丁場');
      await tester.enterText(_templateTargetTimeField(), '１，０００');
      await tester.tap(find.byKey(AppKeys.taskTemplateSaveButton));
      await tester.pumpAndSettle();

      final saved = await repo.load();
      expect(saved.single.targetTimeMinutes, 1000);
    });
  });

  group('ProjectListScreen — 計画の陣ボーナス欄の全角数値入力', () {
    testWidgets('全角１００を入れると bonusExp 100 で登録される', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _MockPlayerRepo();
      final vm = PlayerViewModel(repo);
      final player = Player(
        currentJob: Job.mystic,
        jobLevels: {Job.mystic: 12},
      );
      await repo.savePlayer(player);
      vm.player = player;

      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerViewModel>.value(
          value: vm,
          child: const MaterialApp(home: ProjectListScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(ProjectAppKeys.projectCreateFab));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(ProjectAppKeys.projectNameField), '全角計画');
      await tester.enterText(
          find.byKey(ProjectAppKeys.projectBonusField), '１００');
      await tester.tap(find.byKey(ProjectAppKeys.projectSubmit));
      await tester.pumpAndSettle();

      expect(vm.player.projects.single.bonusExp, 100);
    });
  });
}
