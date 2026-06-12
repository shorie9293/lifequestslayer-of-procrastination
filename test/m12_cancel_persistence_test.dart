import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';

/// Hive非依存のインメモリ PlayerRepository モック
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

/// 簡易 SettingsRepository モック
class _TestSettingsRepo extends SettingsRepository {
  int _tutorialStep = 0;
  @override
  Future<int> getTutorialStep() async => _tutorialStep;
  @override
  Future<void> setTutorialStep(int v) async => _tutorialStep = v;
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
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
}

Future<void> _waitForLoad(GameViewModel vm) async {
  while (!vm.isLoaded) {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M12 禍津: 戦場から寄合所に戻したタスクが再起動で戦場に戻るバグ', () {
    test(
        '今日期限 + accept → cancel したタスクは、新VMで再読み込みしても inGuild のままであるべき',
        () async {
      // ── 準備: 今日期限のタスクを作成し、受注→取消 する ──
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _TestSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      // Lv10で全スロット解放（自動配備のキャパ制限を回避）
      vm1.player.jobLevels[vm1.player.currentJob] = 10;

      final today = DateTime.now();
      vm1.addTask('今日期限のクエスト', rank: QuestRank.B, deadline: today);
      final taskId = vm1.tasks.first.id;

      // 受注（戦場へ）
      vm1.acceptTask(taskId);
      expect(vm1.tasks.first.status, TaskStatus.active,
          reason: '受注後は active になる');

      // 取消（戦場から寄合所へ戻す）
      vm1.cancelTask(taskId);
      expect(vm1.tasks.first.status, TaskStatus.inGuild,
          reason: '取消後は inGuild に戻る');

      // 保存を待つ
      await Future.delayed(const Duration(milliseconds: 300));

      // ── 再起動シミュレーション: 新VMで読み込み ──
      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      // ★ これが現在のバグ: autoDeployTodaysTasks() が
      //    手動取消したタスクを再度戦場に配備してしまう
      final reloadedTask = vm2.tasks.first;
      expect(reloadedTask.status, TaskStatus.inGuild,
          reason: '手動で戦場から戻したタスクは、再起動後も寄合所(inGuild)に留まるべき');
    });

    test(
        '明日期限 + accept → cancel したタスクも、再起動後は inGuild のままであるべき',
        () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _TestSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      vm1.player.jobLevels[vm1.player.currentJob] = 10;

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      vm1.addTask('明日期限のクエスト', rank: QuestRank.B, deadline: tomorrow);
      final taskId = vm1.tasks.first.id;

      vm1.acceptTask(taskId);
      vm1.cancelTask(taskId);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      final reloadedTask = vm2.tasks.first;
      expect(reloadedTask.status, TaskStatus.inGuild,
          reason: '取消した明日期限タスクも再起動後は寄合所に留まるべき');
    });

    test(
        '期限なしタスクを cancel した後、再起動で inGuild が維持される（リグレッション防止）',
        () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _TestSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      vm1.player.jobLevels[vm1.player.currentJob] = 10;

      // 期限なしタスク
      vm1.addTask('期限なしクエスト', rank: QuestRank.B);
      final taskId = vm1.tasks.first.id;

      vm1.acceptTask(taskId);
      vm1.cancelTask(taskId);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      final reloadedTask = vm2.tasks.first;
      expect(reloadedTask.status, TaskStatus.inGuild,
          reason: '期限なしタスクは自動配備対象外だが、念のため確認');
    });

    test(
        '取消していない今日期限タスクは、これまで通り自動配備される（後方互換性）',
        () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _TestSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      vm1.player.jobLevels[vm1.player.currentJob] = 10;

      final today = DateTime.now();
      vm1.addTask('今日期限（未受注）', rank: QuestRank.B, deadline: today);

      // ★ 受注も取消もしていない（inGuild のまま）

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      final reloadedTask = vm2.tasks.first;
      expect(reloadedTask.status, TaskStatus.active,
          reason: '一度も受注していない今日期限タスクは自動配備されるべき（既存動作）');
    });
  });
}
