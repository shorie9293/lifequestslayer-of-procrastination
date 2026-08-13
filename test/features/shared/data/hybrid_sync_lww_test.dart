import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/data/hybrid_task_repository.dart';
import 'package:rpg_todo/features/shared/data/hybrid_player_repository.dart';

/// インメモリのフェイクリポジトリ（Hive/Supabaseの代役）
class FakeRepo implements ITaskRepository, IPlayerRepository {
  List<Task> taskStore = [];
  Player? playerStore;
  int loadTaskCalls = 0;
  int saveTaskCalls = 0;
  int loadPlayerCalls = 0;
  int savePlayerCalls = 0;

  @override
  Future<List<Task>> loadTasks() async {
    loadTaskCalls++;
    return List.of(taskStore);
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    saveTaskCalls++;
    taskStore = List.of(tasks);
  }

  @override
  Future<void> close() async {}

  @override
  Future<Player?> loadPlayer() async {
    loadPlayerCalls++;
    return playerStore;
  }

  @override
  Future<void> savePlayer(Player player) async {
    savePlayerCalls++;
    playerStore = player;
  }

  @override
  bool get loadFailedDueToCorruption => false;
}

Task _task(String id, {DateTime? updatedAt}) => Task(
      id: id,
      title: 'task-$id',
      updatedAt: updatedAt,
    );

void main() {
  group('HybridTaskRepository last-write-wins', () {
    test('ローカルが新しい場合、ローカルが採用されクラウドへpushされる', () async {
      final local = FakeRepo()
        ..taskStore = [_task('t1', updatedAt: DateTime(2026, 1, 2))];
      final cloud = FakeRepo()
        ..taskStore = [_task('t1', updatedAt: DateTime(2026, 1, 1))];
      final hybrid = HybridTaskRepository(hiveRepo: local, supabaseRepo: cloud);

      final result = await hybrid.loadTasks();

      // ローカルが新しい → ローカルのtitleが残る
      expect(result.single.id, 't1');
      // クラウドへpushされた（saveTasks が呼ばれた）
      expect(cloud.saveTaskCalls, greaterThan(0));
      // クラウドのストアがマージ結果で更新されている
      expect(cloud.taskStore.single.title, 'task-t1');
    });

    test('クラウドが新しい場合、クラウドが採用されローカルが上書きされる', () async {
      final local = FakeRepo()
        ..taskStore = [_task('t1', updatedAt: DateTime(2026, 1, 1))];
      final cloud = FakeRepo()
        ..taskStore = [
          Task(id: 't1', title: 'cloud-newer', updatedAt: DateTime(2026, 1, 3)),
        ];
      final hybrid = HybridTaskRepository(hiveRepo: local, supabaseRepo: cloud);

      final result = await hybrid.loadTasks();

      expect(result.single.title, 'cloud-newer');
      expect(local.taskStore.single.title, 'cloud-newer');
    });

    test('ローカルのみのタスクはクラウドへpushされる', () async {
      final local = FakeRepo()
        ..taskStore = [_task('local-only', updatedAt: DateTime(2026, 1, 2))];
      final cloud = FakeRepo()..taskStore = [];
      final hybrid = HybridTaskRepository(hiveRepo: local, supabaseRepo: cloud);

      final result = await hybrid.loadTasks();

      expect(result.single.id, 'local-only');
      expect(cloud.saveTaskCalls, greaterThan(0));
      expect(cloud.taskStore.single.id, 'local-only');
    });

    test('クラウドのみのタスクはローカルへ追加される', () async {
      final local = FakeRepo()..taskStore = [];
      final cloud = FakeRepo()
        ..taskStore = [_task('cloud-only', updatedAt: DateTime(2026, 1, 2))];
      final hybrid = HybridTaskRepository(hiveRepo: local, supabaseRepo: cloud);

      final result = await hybrid.loadTasks();

      expect(result.single.id, 'cloud-only');
      expect(local.taskStore.single.id, 'cloud-only');
    });

    test('saveTasks は updatedAt を付与する', () async {
      final local = FakeRepo();
      final cloud = FakeRepo();
      final hybrid = HybridTaskRepository(hiveRepo: local, supabaseRepo: cloud);

      await hybrid.saveTasks([_task('t1')]);

      expect(local.taskStore.single.updatedAt, isNotNull);
      // 非同期pushを回収
      await Future<void>.delayed(Duration.zero);
      expect(cloud.taskStore.single.updatedAt, isNotNull);
    });
  });

  group('HybridPlayerRepository last-write-wins', () {
    test('ローカルが新しい場合、ローカル進行が保持されクラウドへpushされる', () async {
      final local = FakeRepo();
      local.playerStore = Player(updatedAt: DateTime(2026, 1, 2));
      local.playerStore!.coins = 100;
      final cloud = FakeRepo();
      cloud.playerStore = Player(updatedAt: DateTime(2026, 1, 1));
      cloud.playerStore!.coins = 50;
      final hybrid = HybridPlayerRepository(hiveRepo: local, supabaseRepo: cloud);

      final result = await hybrid.loadPlayer();

      // オフラインで貯めたコイン100が保持される
      expect(result!.coins, 100);
      expect(cloud.savePlayerCalls, greaterThan(0));
      expect(cloud.playerStore!.coins, 100);
    });

    test('クラウドが新しい場合、クラウドが採用される', () async {
      final local = FakeRepo();
      local.playerStore = Player(updatedAt: DateTime(2026, 1, 1));
      local.playerStore!.coins = 10;
      final cloud = FakeRepo();
      cloud.playerStore = Player(updatedAt: DateTime(2026, 1, 3));
      cloud.playerStore!.coins = 999;
      final hybrid = HybridPlayerRepository(hiveRepo: local, supabaseRepo: cloud);

      final result = await hybrid.loadPlayer();

      expect(result!.coins, 999);
      expect(local.playerStore!.coins, 999);
    });

    test('ローカルのみ存在する場合、クラウドへpushされる', () async {
      final local = FakeRepo();
      local.playerStore = Player(updatedAt: DateTime(2026, 1, 2));
      local.playerStore!.coins = 77;
      final cloud = FakeRepo()..playerStore = null;
      final hybrid = HybridPlayerRepository(hiveRepo: local, supabaseRepo: cloud);

      final result = await hybrid.loadPlayer();

      expect(result!.coins, 77);
      expect(cloud.savePlayerCalls, greaterThan(0));
      expect(cloud.playerStore!.coins, 77);
    });
  });
}
