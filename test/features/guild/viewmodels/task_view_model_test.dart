import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/crossapp/data/rpg_enemy_defeat_exporter.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class _MockEnemyDefeatExporter implements IRpgEnemyDefeatExporter {
  final calls = <Map<String, dynamic>>[];

  @override
  Future<void> exportEnemyDefeat({
    required String taskTitle,
    required String questRank,
    required int baseExp,
    String? timestamp,
  }) async {
    calls.add({
      'taskTitle': taskTitle,
      'questRank': questRank,
      'baseExp': baseExp,
    });
  }
}

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

void main() {
  group('TaskViewModel', () {
    test('tasks is empty after construction and load', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      final taskVm = TaskViewModel(_MockTaskRepo(), playerVm);
      await taskVm.load();
      expect(taskVm.tasks, isEmpty);
    });

    test('tasks remains empty after reload', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      final taskVm = TaskViewModel(_MockTaskRepo(), playerVm);
      await taskVm.load();
      await taskVm.load();
      expect(taskVm.tasks, isEmpty);
    });
  });

  group('TaskViewModel - 繰り返しクエスト表示 (RoninRepeatTask)', () {
    late _MockPlayerRepo playerRepo;
    late PlayerViewModel playerVm;
    late _MockTaskRepo taskRepo;
    late TaskViewModel taskVm;

    setUp(() async {
      playerRepo = _MockPlayerRepo();
      playerVm = PlayerViewModel(playerRepo);
      await playerVm.load();
      taskRepo = _MockTaskRepo();
      taskVm = TaskViewModel(taskRepo, playerVm);
      await taskVm.load();
    });

    test('RoninRepeatTask有効時:今日完了済みの繰り返しクエストはactiveTasksに非表示', () {
      // Set up: Ronin Lv10 (mastered → roninRepeatTask available)
      playerVm.player.jobLevels[Job.adventurer] = 10;
      playerVm.player.currentJob = Job.adventurer;

      final today = DateTime.now();
      taskVm.addTask('毎日の修行',
          repeatInterval: RepeatInterval.daily);
      final task = taskVm.tasks.first;
      task.lastCompletedAt = today; // 今日完了済み
      task.status = TaskStatus.active;

      // 今日完了済みなので非表示
      expect(taskVm.activeTasks, isEmpty);
    });

    test('RoninRepeatTask有効時:昨日完了の繰り返しクエストはactiveTasksに表示', () {
      playerVm.player.jobLevels[Job.adventurer] = 10;
      playerVm.player.currentJob = Job.adventurer;

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      taskVm.addTask('毎日の修行',
          repeatInterval: RepeatInterval.daily);
      final task = taskVm.tasks.first;
      task.lastCompletedAt = yesterday; // 昨日完了
      task.status = TaskStatus.active;

      // 昨日完了なので今日は表示される
      expect(taskVm.activeTasks.length, 1);
    });

    test('RoninRepeatTask未開放時:今日完了済みでもactiveTasksに表示', () {
      // Lv1 → RoninRepeatTask 未開放
      playerVm.player.jobLevels[Job.adventurer] = 1;
      playerVm.player.currentJob = Job.adventurer;

      final today = DateTime.now();
      taskVm.addTask('毎日の修行',
          repeatInterval: RepeatInterval.daily);
      final task = taskVm.tasks.first;
      task.lastCompletedAt = today;
      task.status = TaskStatus.active;

      // スキル未開放なので常に表示
      expect(taskVm.activeTasks.length, 1);
    });

    test('repeatInterval=noneのクエストは常に表示', () {
      playerVm.player.jobLevels[Job.adventurer] = 10;

      final today = DateTime.now();
      taskVm.addTask('通常クエスト',
          repeatInterval: RepeatInterval.none);
      final task = taskVm.tasks.first;
      task.lastCompletedAt = today;
      task.status = TaskStatus.active;

      // repeatInterval=none は常に表示
      expect(taskVm.activeTasks.length, 1);
    });
  });

  group('TaskViewModel - kozuchi敵討伐エクスポート', () {
    late PlayerViewModel playerVm;
    late _MockTaskRepo taskRepo;
    late TaskViewModel taskVm;
    late _MockEnemyDefeatExporter exporter;

    setUp(() async {
      final playerRepo = _MockPlayerRepo();
      playerVm = PlayerViewModel(playerRepo);
      await playerVm.load();
      taskRepo = _MockTaskRepo();
      taskVm = TaskViewModel(taskRepo, playerVm);
      exporter = _MockEnemyDefeatExporter();
      taskVm.enemyDefeatExporter = exporter;
      await taskVm.load();
    });

    test('completeTask()成功時に敵討伐イベントをエクスポートする', () {
      playerVm.player.jobLevels[playerVm.player.currentJob] = 5;
      taskVm.addTask('スライム討伐', rank: QuestRank.B);
      taskVm.tasks.last.enemyXpMultiplier = 1.0; // テスト決定論化: 希少種抽選を無効化
      taskVm.acceptTask(taskVm.tasks[0].id);

      final result = taskVm.completeTask(taskVm.tasks[0].id);

      expect(result, isNotNull);
      expect(exporter.calls, hasLength(1));
      expect(exporter.calls.single['taskTitle'], 'スライム討伐');
      // QuestRank.name は既に大文字（'B'）。exporter 側でも大文字化される
      expect(exporter.calls.single['questRank'], 'B');
      // Bランク ベースEXP = 100
      expect(exporter.calls.single['baseExp'], 100);
    });

    test('完了失敗時はエクスポートしない', () {
      taskVm.enemyDefeatExporter = exporter;
      // 存在しないIDで完了 → null
      final result = taskVm.completeTask('no-such-task-id');
      expect(result, isNull);
      expect(exporter.calls, isEmpty);
    });
  });
}
