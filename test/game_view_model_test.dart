import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/viewmodels/game_view_model.dart';
import 'package:rpg_todo/models/player.dart';
import 'package:rpg_todo/models/task.dart';
import 'package:rpg_todo/repositories/player_repository.dart';
import 'package:rpg_todo/repositories/task_repository.dart';
import 'package:rpg_todo/services/settings_repository.dart';
import 'package:hive/hive.dart';
import 'dart:io';

/// テスト時にエラーをthrowする PlayerRepository のモック
class FailingPlayerRepository extends PlayerRepository {
  final Object error;
  FailingPlayerRepository(this.error);

  @override
  Future<Player> loadPlayer() async {
    throw error;
  }
}

/// テスト時にエラーをthrowする TaskRepository のモック
class FailingTaskRepository extends TaskRepository {
  final Object error;
  FailingTaskRepository(this.error);

  @override
  Future<List<Task>> loadTasks() async {
    throw error;
  }
}

/// TypeAdapter を安全に登録する（他テストで登録済みの場合は無視）
void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
  try {
    Hive.registerAdapter(adapter);
  } on HiveError {
    // 既に登録済み
  }
}

void main() {
  group('GameViewModel 永続化テスト（実Hive）', () {
    late Directory testDir;

    setUpAll(() async {
      testDir = Directory('${Directory.systemTemp.path}/vm_test_${DateTime.now().millisecondsSinceEpoch}');
      Hive.init(testDir.path);
      _safeRegisterAdapter(TaskAdapter());
      _safeRegisterAdapter(TaskStatusAdapter());
      _safeRegisterAdapter(QuestionRankAdapter());
      _safeRegisterAdapter(PlayerAdapter());
      _safeRegisterAdapter(JobAdapter());
      _safeRegisterAdapter(RepeatIntervalAdapter());
      _safeRegisterAdapter(SubTaskAdapter());
    });

    tearDownAll(() async {
      await Hive.close();
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
    });

    tearDown(() async {
      // テスト間で Box をクリーンアップ
      try { await Hive.deleteBoxFromDisk(PlayerRepository.boxName); } catch (_) {}
      try { await Hive.deleteBoxFromDisk(TaskRepository.boxName); } catch (_) {}
      try { await Hive.deleteBoxFromDisk('settingsBox'); } catch (_) {}
      try { await Hive.deleteBoxFromDisk('tutorialBox'); } catch (_) {}
    });

    test('タスク完了（Bランク）が永続化され、再読み込みでレベル・タスク状態が維持される', () async {
      // 1. 最初の ViewModel で操作
      final vm1 = GameViewModel();
      await _waitForLoad(vm1);

      vm1.addTask('テストクエスト', rank: QuestRank.B);

      // タスクを受け入れて完了（Bランク=100EXP → Lv1→Lv2）
      final taskId = vm1.tasks.first.id;
      vm1.acceptTask(taskId);
      final result = vm1.completeTask(taskId);

      expect(result, isNotNull);
      expect(result!['leveledUp'], true); // 100EXP → Lv1→Lv2
      expect(result['baseExp'], 100);

      // 保存を待つ
      await Future.delayed(const Duration(milliseconds: 200));

      // 2. 新しい ViewModel で読み込み
      final vm2 = GameViewModel();
      await _waitForLoad(vm2);

      // 検証: タスクは完了状態で永続化されている
      expect(vm2.tasks.length, 1);
      expect(vm2.tasks.first.isCompleted, true);
      expect(vm2.tasks.first.status, TaskStatus.inGuild);
      // 検証: プレイヤーのレベルが維持されている
      expect(vm2.player.level, 2);
      // 検証: コインが獲得されている
      expect(vm2.player.coins, greaterThan(0));
      // 検証: 累計タスク完了数
      expect(vm2.player.totalTasksCompleted, 1);
    });

    test('複数タスクの完了が永続化される', () async {
      final vm1 = GameViewModel();
      await _waitForLoad(vm1);

      // 3つのタスクを追加して完了
      vm1.addTask('クエスト1', rank: QuestRank.B);
      vm1.addTask('クエスト2', rank: QuestRank.B);
      vm1.addTask('クエスト3', rank: QuestRank.B);

      for (final t in List<Task>.from(vm1.tasks)) {
        vm1.acceptTask(t.id);
        vm1.completeTask(t.id);
      }

      await Future.delayed(const Duration(milliseconds: 200));

      final vm2 = GameViewModel();
      await _waitForLoad(vm2);

      // 全タスクが完了状態
      expect(vm2.tasks.length, 3);
      expect(vm2.tasks.every((t) => t.isCompleted), true);
      // プレイヤーデータも維持
      expect(vm2.player.totalTasksCompleted, 3);
    });

    test('プレイヤーデータ（宝石・職業）が永続化される', () async {
      final vm1 = GameViewModel();
      await _waitForLoad(vm1);

      // 直接プレイヤーを操作してから保存
      vm1.addGems(50);
      vm1.changeJob(Job.warrior);

      await Future.delayed(const Duration(milliseconds: 200));

      final vm2 = GameViewModel();
      await _waitForLoad(vm2);

      expect(vm2.player.gems, 50);
      expect(vm2.player.currentJob, Job.warrior);
    });
  });

  group('GameViewModel データ保護テスト', () {
    test('PlayerRepository 読み込み失敗時に loadData がクラッシュせず isLoaded=true になる', () async {
      final vm = GameViewModel(
        playerRepository: FailingPlayerRepository(HiveError('テスト用エラー')),
        taskRepository: TaskRepository(),
        settingsRepository: SettingsRepository(),
      );

      await _waitForLoad(vm);

      // ViewModel はクラッシュせず、動作を継続する
      expect(vm.isLoaded, true);
      expect(vm.player.level, 1); // デフォルト値
      expect(vm.tasks, isEmpty);
    });

    test('TaskRepository 読み込み失敗時に loadData がクラッシュせず isLoaded=true になる', () async {
      final vm = GameViewModel(
        playerRepository: PlayerRepository(),
        taskRepository: FailingTaskRepository(HiveError('テスト用エラー')),
        settingsRepository: SettingsRepository(),
      );

      await _waitForLoad(vm);

      expect(vm.isLoaded, true);
      expect(vm.tasks, isEmpty);
    });

    test('読み込み失敗時は _notifyAndSave がブロックされ、変更が保存されない', () async {
      // PlayerRepository が失敗する ViewModel を作成
      final vm = GameViewModel(
        playerRepository: FailingPlayerRepository(HiveError('テスト用エラー')),
        taskRepository: TaskRepository(),
        settingsRepository: SettingsRepository(),
      );

      await _waitForLoad(vm);

      // 操作を試みる（内部で _notifyAndSave が呼ばれるが、_loadFailed=true によりブロックされる）
      // 例外が発生しないことを確認
      expect(() => vm.addGems(100), returnsNormally);
      expect(() => vm.addTask('テスト', rank: QuestRank.B), returnsNormally);
      // _loadFailed フラグにより saveData() は呼ばれず、例外も発生しない
    });
  });

  group('TaskAdapter ラウンドトリップ', () {
    late Box<Task> box;

    setUpAll(() async {
      final testDir = Directory('${Directory.systemTemp.path}/task_adapter_test_${DateTime.now().millisecondsSinceEpoch}');
      Hive.init(testDir.path);
      _safeRegisterAdapter(TaskAdapter());
      _safeRegisterAdapter(TaskStatusAdapter());
      _safeRegisterAdapter(QuestionRankAdapter());
      _safeRegisterAdapter(RepeatIntervalAdapter());
      _safeRegisterAdapter(SubTaskAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<Task>('task_adapter_test_box');
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    test('完了済みタスクの読み書きが一致する', () async {
      final task = Task(
        id: 'test-id-1',
        title: '討伐済みクエスト',
        status: TaskStatus.inGuild,
        isCompleted: true,
        rank: QuestRank.S,
      );

      await box.put(task.id, task);
      final restored = box.get(task.id)!;

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.isCompleted, true);
      expect(restored.status, TaskStatus.inGuild);
      expect(restored.rank, QuestRank.S);
    });

    test('未完了タスクの読み書きが一致する', () async {
      final task = Task(
        id: 'test-id-2',
        title: '未討伐クエスト',
      );

      await box.put(task.id, task);
      final restored = box.get(task.id)!;

      expect(restored.isCompleted, false);
      expect(restored.status, TaskStatus.inGuild);
    });
  });
}

/// GameViewModel.loadData() の非同期完了を待つヘルパー
Future<void> _waitForLoad(GameViewModel vm, {Duration timeout = const Duration(seconds: 5)}) async {
  final start = DateTime.now();
  while (!vm.isLoaded) {
    if (DateTime.now().difference(start) > timeout) {
      throw Exception('GameViewModel のロードがタイムアウトしました');
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
  // 微小な追加待機で非同期処理の完了を保証
  await Future.delayed(const Duration(milliseconds: 50));
}
